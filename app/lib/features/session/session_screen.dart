import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/contract.dart';
import '../../core/device/device_client.dart';
import '../../core/feedback.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
import '../../ui/brand.dart';
import '../../ui/components.dart';
import '../../ui/exercise_video.dart';
import 'session_engine.dart';

const exerciseNames = {
  1: 'flexión anterior',
  2: 'abducción',
  3: 'rotación externa',
  4: 'rotación interna',
  5: 'extensión de tríceps',
  6: 'estabilización escapular',
};

/// Datos que la pantalla de resumen necesita para armar y subir la sesión.
class SessionOutcome {
  final SessionEngine engine;
  final MeData me;
  final bool verified;
  final List<DeviceEvent> events;
  final int? battery, fwVersion, modelVersion;
  const SessionOutcome(this.engine, this.me, this.verified, this.events, this.battery, this.fwVersion, this.modelVersion);
}

class SessionScreen extends ConsumerStatefulWidget {
  final MeData me;
  final bool verified;
  const SessionScreen({super.key, required this.me, required this.verified});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> with TickerProviderStateMixin {
  late final SessionEngine _engine = SessionEngine(widget.me.prescription!.exercises, verified: widget.verified);
  late final SessionFeedback _fb;
  final List<DeviceEvent> _events = [];
  StreamSubscription<DeviceEvent>? _sub;
  Timer? _timer;
  int _countdown = 3;
  String? _hint;
  DateTime? _mismatchSince;
  bool _setJustDone = false;

  // Pulso del contador en cada repetición (§12: 1.0 → 1.08 → 1.0 en 180 ms).
  late final AnimationController _pulse = AnimationController(vsync: this, duration: RumboMotion.fast);

  Voice get _voice => ref.read(voiceProvider);
  bool get _left => !widget.me.rightArm;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageProvider);
    _fb = SessionFeedback(voice: _voice, sounds: storage.sounds, voiceCounting: storage.voiceCounting)..init();
    WakelockPlus.enable().catchError((_) {});
    _voice.say('Coloque el teléfono donde pueda verlo. Empezamos en tres');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onSecond());
    if (widget.verified) {
      final device = ref.read(deviceProvider);
      _sub = device.events.listen(_onDeviceEvent);
      device.startSession(rightArm: widget.me.rightArm);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _pulse.dispose();
    WakelockPlus.disable().catchError((_) {});
    _fb.dispose();
    super.dispose();
  }

  void _onSecond() {
    if (_engine.phase == Phase.ready) {
      setState(() => _countdown--);
      if (_countdown > 0) {
        _voice.say(spokenNumber(_countdown));
      } else {
        _apply(_engine.start());
      }
      return;
    }
    if (_engine.phase == Phase.rest) {
      if (_engine.restLeft - 1 == 3) _voice.say('Siguiente serie en tres, dos, uno');
      _apply(_engine.tick());
      setState(() {});
    }
    if (_mismatchSince != null && DateTime.now().difference(_mismatchSince!).inSeconds >= 4 && _hint == null) {
      setState(() => _hint = '¿Está haciendo ${exerciseNames[_engine.current.exerciseId]}?');
    }
  }

  void _onDeviceEvent(DeviceEvent ev) {
    _events.add(ev);
    if (_engine.phase != Phase.active) return;
    final expected = _engine.current.exerciseId;
    if (ev.type == EventType.exerciseChanged) {
      if (ev.exerciseId != expected && ev.exerciseId != 0) {
        _mismatchSince ??= DateTime.now();
      } else {
        _clearHint();
      }
    }
    if (ev.type == EventType.rep) {
      if (ev.exerciseId == expected) _clearHint();
      _apply(_engine.onDeviceRep(ev.exerciseId));
    }
  }

  void _clearHint() {
    _mismatchSince = null;
    if (_hint != null) setState(() => _hint = null);
  }

  /// Traduce lo que pasó en el motor a voz, sonido, comandos al reloj y navegación.
  void _apply(List<EngineEvent> events) {
    if (events.isEmpty) return;
    final device = widget.verified ? ref.read(deviceProvider) : null;
    final ex = _engine.current;
    for (final e in events) {
      switch (e) {
        case EngineEvent.exerciseStarted:
          _voice.say('${ex.name}. ${ex.sets > 1 ? 'Serie uno de ${spokenNumber(ex.sets)}. ' : ''}${spokenNumber(ex.reps)} repeticiones.');
        case EngineEvent.setStarted:
          device?.setExpected(ex.exerciseId);
          if (_engine.setIndex > 0) _voice.say('Serie ${spokenNumber(_engine.setIndex + 1)}. Adelante.');
        case EngineEvent.repCounted:
          _fb.rep(_engine.repsInSet);
          if (!RumboMotion.reduced(context)) _pulse.forward(from: 0);
        case EngineEvent.setCompleted:
          _fb.setDone();
          _setJustDone = true;
          Future.delayed(const Duration(milliseconds: 1100), () => mounted ? setState(() => _setJustDone = false) : null);
        case EngineEvent.restStarted:
          device?.setExpected(0);
          _voice.say('Muy bien. Descanse ${_engine.restLeft} segundos.', interrupt: false);
        case EngineEvent.finished:
          device?.setExpected(0);
          device?.stopSession();
          if (!_engine.endedEarly) _fb.sessionDone();
          _voice.say(_engine.endedEarly ? 'Sesión terminada. Lo que hizo ya quedó guardado.' : 'Sesión completa. Su fisioterapeuta ya puede verla.');
          _goToSummary();
      }
    }
    setState(() {});
  }

  void _goToSummary() {
    final snap = ref.read(deviceProvider).snapshot;
    _timer?.cancel();
    context.pushReplacement('/summary',
        extra: SessionOutcome(_engine, widget.me, widget.verified, List.of(_events), snap.battery, snap.fwVersion, snap.modelVersion));
  }

  Future<void> _confirmEnd() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: RumboColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(RumboRadius.xl))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('¿Terminar la sesión?', style: RumboText.sectionTitle),
            const SizedBox(height: 8),
            Text('Lo que ya hizo se guarda y se envía a su fisioterapeuta.', style: RumboText.bodyRegular.copyWith(color: RumboColors.slate)),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir con la sesión')),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminar ahora')),
          ]),
        ),
      ),
    );
    if (ok == true) _apply(_engine.endEarly());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: RumboColors.canvas,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: RumboMotion.of(context, RumboMotion.normal),
            child: switch (_engine.phase) {
              Phase.ready => _ready(),
              Phase.active => KeyedSubtree(key: ValueKey('a${_engine.exIndex}-${_engine.setIndex}'), child: _active()),
              Phase.rest => KeyedSubtree(key: ValueKey('r${_engine.exIndex}-${_engine.setIndex}'), child: _rest()),
              Phase.finished => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- preparación

  Widget _ready() => Center(
        key: const ValueKey('ready'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const RumboIsotipo(size: 72),
            const SizedBox(height: 24),
            const Text('Coloque el teléfono donde pueda verlo', textAlign: TextAlign.center, style: RumboText.screenTitle),
            const SizedBox(height: 32),
            ProgressRing(
              progress: (3 - _countdown.clamp(0, 3)) / 3,
              size: 180,
              color: RumboColors.accent,
              child: Text('${_countdown.clamp(1, 3)}', style: RumboText.counter),
            ),
          ]),
        ),
      );

  // ---------------------------------------------------------------- encabezado

  Widget _header() {
    final ex = _engine.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NeutralChip('Ejercicio ${_engine.exIndex + 1} de ${_engine.plan.length}', icon: LucideIcons.activity),
          const Spacer(),
          IconButton(
            tooltip: 'Terminar la sesión',
            iconSize: 28,
            onPressed: _confirmEnd,
            icon: const Icon(LucideIcons.x, color: RumboColors.slate),
          ),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(ex.name, style: RumboText.screenTitle.copyWith(fontSize: 28)),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(children: [
            Text('Serie ${_engine.setIndex + 1} de ${ex.sets}', style: RumboText.label.copyWith(color: RumboColors.ink)),
            const SizedBox(width: 12),
            Expanded(child: SeriesBar(total: ex.sets, done: _engine.phase == Phase.rest ? _engine.setIndex + 1 : _engine.setIndex)),
          ]),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- serie en curso

  Widget _active() {
    final ex = _engine.current;
    final done = _engine.repsInSet;
    return Column(children: [
      _header(),
      const SizedBox(height: 12),
      Expanded(
        flex: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(child: ExerciseVideo(exerciseId: ex.exerciseId, mirror: _left, fallbackTitle: ex.name)),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RumboCard(
            width: double.infinity,
            radius: RumboRadius.xl,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: widget.verified ? _verifiedCounter(done, ex.reps) : _reportedTarget(ex.reps),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _statusLine()),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: widget.verified
            ? Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _apply(_engine.skipExercise()), child: const Text('Saltar ejercicio'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: () => _apply(_engine.finishSetManually()), child: const Text('Terminé la serie'))),
              ])
            : Column(children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                  onPressed: () => _apply(_engine.finishSetManually()),
                  icon: const Icon(LucideIcons.check, size: 26),
                  label: const Text('Terminé la serie', style: TextStyle(fontSize: 20)),
                ),
                TextButton(onPressed: () => _apply(_engine.skipExercise()), child: const Text('Saltar ejercicio')),
              ]),
      ),
    ]);
  }

  Widget _verifiedCounter(int done, int total) {
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxHeight - 34, c.maxWidth).clamp(120.0, 240.0);
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Semantics(
          liveRegion: true,
          label: '$done de $total repeticiones',
          child: ExcludeSemantics(
            child: ProgressRing(
              progress: done / total,
              size: size,
              stroke: size * 0.07,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Transform.scale(scale: 1 + 0.08 * math.sin(math.pi * _pulse.value), child: child),
                child: FittedBox(
                  child: Padding(
                    padding: EdgeInsets.all(size * 0.12),
                    child: Text('$done', style: RumboText.counter),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('de $total repeticiones', style: RumboText.body.copyWith(color: RumboColors.slate)),
      ]);
    });
  }

  Widget _reportedTarget(int reps) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Haga', style: RumboText.sectionTitle),
        FittedBox(child: Text('$reps', style: RumboText.counter)),
        Text('repeticiones y toque el botón al terminar', textAlign: TextAlign.center, style: RumboText.body.copyWith(color: RumboColors.slate)),
      ]);

  Widget _statusLine() {
    if (!widget.verified) {
      return const StatusChip(kind: StatusKind.reported, label: 'Sin reloj: usted marca sus series');
    }
    final snap = ref.watch(deviceSnapshotProvider).valueOrNull;
    if (snap != null && !snap.connected) {
      final name = widget.me.deviceName;
      return InlineNotice(
        kind: StatusKind.alert,
        text: 'El reloj se desconectó. Acérquelo al teléfono.',
        actionLabel: snap.conn == ConnState.disconnected && name != null ? 'Reconectar' : null,
        onAction: name == null ? null : () => ref.read(deviceProvider).connect(name),
      );
    }
    if (_hint != null) return InlineNotice(kind: StatusKind.reported, text: _hint!);
    return const StatusChip(kind: StatusKind.verified, label: 'El reloj está contando sus repeticiones');
  }

  // ---------------------------------------------------------------- descanso

  Widget _rest() {
    final next = _engine.next;
    final sameExercise = next?.exerciseId == _engine.current.exerciseId;
    return Column(children: [
      _header(),
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_setJustDone) ...[const _SetDoneBadge(), const SizedBox(height: 16)],
            const Text('Descanse', style: RumboText.screenTitle),
            const SizedBox(height: 4),
            Text('Respire con el círculo', style: RumboText.body.copyWith(color: RumboColors.slate)),
            const SizedBox(height: 24),
            _BreathingCircle(seconds: _engine.restLeft),
          ]),
        ),
      ),
      if (next != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RumboCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(width: 84, child: ExerciseVideo(exerciseId: next.exerciseId, mirror: _left, fallbackTitle: '')),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sigue', style: RumboText.label),
                  Text(sameExercise ? 'Serie ${_engine.setIndex + 2} de ${next.sets}' : next.name, style: RumboText.sectionTitle),
                  Text('${next.reps} repeticiones', style: RumboText.help),
                ]),
              ),
            ]),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: OutlinedButton(onPressed: () => _apply(_engine.skipRest()), child: const Text('Ya estoy listo')),
      ),
    ]);
  }
}

/// Círculo que se expande (inhalar) y se contrae (exhalar) cada 4 s, con la cuenta regresiva al centro.
class _BreathingCircle extends StatefulWidget {
  final int seconds;
  const _BreathingCircle({required this.seconds});

  @override
  State<_BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<_BreathingCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (RumboMotion.reduced(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Faltan ${widget.seconds} segundos de descanso',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_c.value);
            final inhale = _c.status == AnimationStatus.forward;
            return SizedBox.square(
              dimension: 240,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 150 + 90 * t,
                  height: 150 + 90 * t,
                  decoration: const BoxDecoration(color: RumboColors.primarySoft, shape: BoxShape.circle),
                ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(color: RumboColors.surface, shape: BoxShape.circle),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${widget.seconds}', style: RumboText.counter.copyWith(fontSize: 64)),
                    Text(RumboMotion.reduced(context) ? 'segundos' : (inhale ? 'Inhale' : 'Exhale'),
                        style: RumboText.label.copyWith(color: RumboColors.primary)),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Palomita animada al completar una serie.
class _SetDoneBadge extends StatelessWidget {
  const _SetDoneBadge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: RumboMotion.of(context, const Duration(milliseconds: 350)),
      curve: Curves.easeOutBack,
      builder: (_, v, __) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(
          scale: 0.6 + 0.4 * v,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: RumboColors.success,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [BoxShadow(color: Color(0x1F1E1B3A), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.circleCheck, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text('Serie completa', style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}
