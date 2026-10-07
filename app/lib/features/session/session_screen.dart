import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/contract.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
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

class _SessionScreenState extends ConsumerState<SessionScreen> {
  late final SessionEngine _engine = SessionEngine(widget.me.prescription!.exercises, verified: widget.verified);
  final List<DeviceEvent> _events = [];
  StreamSubscription<DeviceEvent>? _sub;
  Timer? _timer;
  int _countdown = 3; // cuenta regresiva antes de empezar
  String? _hint; // aviso suave si el reloj detecta otro ejercicio
  DateTime? _mismatchSince;
  bool _pulse = false;

  Voice get _voice => ref.read(voiceProvider);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {}); // la pantalla no se apaga durante la sesión
    _voice.say('Coloca el teléfono donde puedas verlo. Empezamos en tres');
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
    WakelockPlus.disable().catchError((_) {});
    _voice.stop();
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
      final left = _engine.restLeft - 1;
      if (left == 3) _voice.say('Siguiente serie en tres, dos, uno');
      _apply(_engine.tick());
      setState(() {});
    }
    // Aviso de ejercicio distinto solo si dura más de 4 s.
    if (_mismatchSince != null && DateTime.now().difference(_mismatchSince!).inSeconds >= 4 && _hint == null) {
      setState(() => _hint = '¿Estás haciendo ${exerciseNames[_engine.current.exerciseId]}?');
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

  /// Traduce lo que pasó en el motor a voz, comandos al reloj y navegación.
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
          _voice.say(spokenNumber(_engine.repsInSet));
          _pulse = !_pulse;
        case EngineEvent.setCompleted:
          break;
        case EngineEvent.restStarted:
          device?.setExpected(0);
          _voice.say('Muy bien. Descansa ${_engine.restLeft} segundos.', interrupt: false);
        case EngineEvent.finished:
          device?.setExpected(0);
          device?.stopSession();
          _voice.say(_engine.endedEarly ? 'Sesión terminada.' : '¡Sesión terminada! Buen trabajo.');
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Terminar la sesión?'),
        content: const Text('Lo que ya hiciste se guarda y se envía a tu fisioterapeuta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 48)), onPressed: () => Navigator.pop(c, true), child: const Text('Terminar')),
        ],
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
        backgroundColor: Colors.white,
        body: SafeArea(
          child: switch (_engine.phase) {
            Phase.ready => _ready(),
            Phase.active => _active(),
            Phase.rest => _rest(),
            Phase.finished => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _ready() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.phone_android, size: 72, color: SsColors.primary),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('Coloca el teléfono donde puedas verlo', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 24),
          Text('${_countdown.clamp(1, 3)}', style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w800, color: SsColors.primary)),
        ]),
      );

  Widget _header() {
    final ex = _engine.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(children: [
        Expanded(child: Text(ex.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
        Text('Serie ${_engine.setIndex + 1} / ${ex.sets}', style: const TextStyle(fontSize: 20, color: SsColors.muted, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _active() {
    final ex = _engine.current;
    final done = _engine.repsInSet;
    return Column(children: [
      _header(),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Text('Ejercicio ${_engine.exIndex + 1} de ${_engine.plan.length}', style: const TextStyle(fontSize: 16, color: SsColors.muted)),
      ),
      Expanded(
        child: Center(
          child: widget.verified
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedScale(
                    scale: _pulse ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Text('$done',
                        style: const TextStyle(fontSize: 160, height: 1, fontWeight: FontWeight.w800, color: SsColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  Text('de ${ex.reps}', style: const TextStyle(fontSize: 32, color: SsColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  _repDots(done, ex.reps),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${ex.reps}', style: const TextStyle(fontSize: 140, height: 1, fontWeight: FontWeight.w800, color: SsColors.reported)),
                  const Text('repeticiones', style: TextStyle(fontSize: 28, color: SsColors.muted, fontWeight: FontWeight.w600)),
                ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(ex.instructions, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, height: 1.4)),
      ),
      const SizedBox(height: 16),
      _statusLine(),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(children: [
          if (!widget.verified)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: SsColors.reported, minimumSize: const Size.fromHeight(76)),
              onPressed: () => _apply(_engine.finishSetManually()),
              child: const Text('Terminé la serie', style: TextStyle(fontSize: 24)),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _apply(_engine.skipExercise()), child: const Text('Saltar ejercicio'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(onPressed: _confirmEnd, child: const Text('Terminar'))),
          ]),
          if (widget.verified)
            TextButton(onPressed: () => _apply(_engine.finishSetManually()), child: const Text('Terminé esta serie')),
        ]),
      ),
    ]);
  }

  Widget _repDots(int done, int total) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(shape: BoxShape.circle, color: i < done ? SsColors.verified : SsColors.dayNone),
            ),
        ],
      );

  Widget _statusLine() {
    if (!widget.verified) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('Haz las repeticiones y toca el botón al terminar la serie.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: SsColors.muted)),
      );
    }
    final hint = _hint;
    final ok = hint == null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: ok ? SsColors.verifiedSoft : SsColors.reportedSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(ok ? Icons.watch_outlined : Icons.help_outline, color: ok ? SsColors.verified : SsColors.reported),
        const SizedBox(width: 10),
        Expanded(
          child: Text(ok ? 'El reloj está contando tus repeticiones' : hint,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ok ? SsColors.verified : SsColors.reported)),
        ),
      ]),
    );
  }

  Widget _rest() {
    final next = _engine.next;
    final sameExercise = next?.exerciseId == _engine.current.exerciseId;
    return Column(children: [
      _header(),
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Descansa', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: SsColors.verified)),
            const SizedBox(height: 8),
            Text('${_engine.restLeft}', style: const TextStyle(fontSize: 140, height: 1.1, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
            const Text('segundos', style: TextStyle(fontSize: 24, color: SsColors.muted)),
            const SizedBox(height: 32),
            if (next != null)
              Text(
                sameExercise ? 'Sigue: serie ${_engine.setIndex + 2} de ${next.sets}' : 'Sigue: ${next.name}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: OutlinedButton(onPressed: () => _apply(_engine.skipRest()), child: const Text('Ya estoy listo')),
      ),
    ]);
  }
}
