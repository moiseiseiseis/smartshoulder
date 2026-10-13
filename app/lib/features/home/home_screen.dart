import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/device/device_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/brand.dart';
import '../../ui/components.dart';
import '../../ui/exercise_video.dart';

/// "Su rumbo": la semana como un camino, la sesión de hoy y un solo botón grande.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Al abrir: subir lo pendiente y reconectar el reloj si tiene uno asignado.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final left = await ref.read(queueProvider).flush();
      if (left == 0) ref.invalidate(historyProvider);
      try {
        final me = await ref.read(meProvider.future);
        final device = ref.read(deviceProvider);
        if (me.deviceName != null && device.snapshot.conn == ConnState.disconnected) device.connect(me.deviceName!);
      } catch (_) {
        // Sin conexión: la pantalla ya lo explica.
      }
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(meProvider);
    ref.invalidate(historyProvider);
    await ref.read(meProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const RumboLogo(fontSize: 24),
        actions: [
          IconButton(tooltip: 'Mi historial', iconSize: 26, onPressed: () => context.push('/history'), icon: const Icon(LucideIcons.calendarDays)),
          IconButton(tooltip: 'Ajustes', iconSize: 26, onPressed: () => context.push('/settings'), icon: const Icon(LucideIcons.settings)),
          const SizedBox(width: 4),
        ],
      ),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: LucideIcons.wifiOff,
          title: 'No pudimos conectarnos',
          body: 'Revise que tenga internet e intente de nuevo. Sus sesiones guardadas no se pierden.',
          actionLabel: 'Intentar de nuevo',
          onAction: _refresh,
        ),
        data: (m) => RefreshIndicator(onRefresh: _refresh, child: _HomeBody(me: m)),
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
}

class _HomeBody extends ConsumerWidget {
  final MeData me;
  const _HomeBody({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rx = me.prescription;
    final history = ref.watch(historyProvider).valueOrNull;
    final snap = ref.watch(deviceSnapshotProvider).valueOrNull ?? const DeviceSnapshot();
    final hasDevice = me.deviceName != null;
    final verified = hasDevice && snap.connected;
    final pending = ref.watch(queueProvider).pendingCount;
    final doneToday = history?.doneToday ?? false;
    final away = _daysAway(history);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text('${_greeting()}, ${me.firstName}', style: RumboText.screenTitle),
        const SizedBox(height: 2),
        Text('${me.physioName} · ${me.clinicName}', style: RumboText.help),
        const SizedBox(height: 20),
        if (away != null) ...[
          InlineNotice(kind: StatusKind.reported, text: away),
          const SizedBox(height: 16),
        ],
        if (history?.week != null) ...[_WeekCard(week: history!.week!), const SizedBox(height: 16)],
        if (rx == null)
          const RumboCard(
            child: Column(children: [
              Icon(LucideIcons.clipboardList, size: 36, color: RumboColors.primary),
              SizedBox(height: 12),
              Text('Su fisioterapeuta aún no le asigna ejercicios', textAlign: TextAlign.center, style: RumboText.sectionTitle),
              SizedBox(height: 4),
              Text('Cuando lo haga, aparecerán aquí.', textAlign: TextAlign.center, style: RumboText.help),
            ]),
          )
        else
          _TodayCard(rx: rx, rightArm: me.rightArm, doneToday: doneToday),
        const SizedBox(height: 16),
        _DeviceTile(me: me, snap: snap),
        const SizedBox(height: 24),
        if (rx != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(68)),
            onPressed: () => context.push('/session', extra: (me, verified)),
            icon: const Icon(LucideIcons.play, size: 26),
            label: Text(doneToday ? 'Hacer otra sesión' : 'Comenzar sesión', style: const TextStyle(fontSize: 21)),
          ),
        if (hasDevice && !snap.connected && rx != null) ...[
          const SizedBox(height: 8),
          const Text('Si empieza sin el reloj, marcará sus series a mano.', textAlign: TextAlign.center, style: RumboText.help),
        ],
        if (pending > 0) ...[
          const SizedBox(height: 16),
          InlineNotice(
            kind: StatusKind.reported,
            text: pending == 1 ? 'Una sesión está guardada en el teléfono y se enviará cuando haya internet.' : '$pending sesiones están guardadas en el teléfono y se enviarán cuando haya internet.',
          ),
        ],
      ],
    );
  }

  /// "No vemos sesiones desde el martes. Cuando pueda, retomamos." (identidad §13). Nunca culpa.
  String? _daysAway(HistoryData? h) {
    if (h == null || h.sessions.isEmpty) return null;
    final last = h.sessions.map((s) => s.startedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final days = DateTime.now().difference(DateTime(last.year, last.month, last.day)).inDays;
    if (days < 3) return null;
    final when = days < 7 ? 'el ${DateFormat('EEEE', 'es').format(last)}' : 'el ${DateFormat("d 'de' MMMM", 'es').format(last)}';
    return 'No vemos sesiones desde $when. Cuando pueda, retomamos.';
  }
}

class _WeekCard extends StatelessWidget {
  final WeekInfo week;
  const _WeekCard({required this.week});

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _names = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = 0; i < week.days.length; i++)
        () {
          final d = week.days[i];
          final mark = switch (d.status) {
            DayStatus.complete => d.verified == true ? DayMark.verified : DayMark.reported,
            DayStatus.incomplete || DayStatus.aborted => DayMark.incomplete,
            DayStatus.none => DayMark.pending,
          };
          final spoken = switch (mark) {
            DayMark.verified => 'sesión completa, verificada por el reloj',
            DayMark.reported => 'sesión completa, marcada a mano',
            DayMark.incomplete => 'sesión incompleta',
            DayMark.pending => d.isToday ? 'hoy, pendiente' : 'sin sesión',
          };
          return WeekDay(_letters[i], mark, d.isToday, '${_names[i]}: $spoken');
        }(),
    ];
    final title = week.reached ? 'Meta de la semana cumplida' : 'Su rumbo esta semana';
    final body = week.reached
        ? 'Hizo ${week.done} de ${week.goal} sesiones. Su constancia se nota.'
        : week.remaining == 1
            ? 'Le falta 1 sesión para su meta de la semana.'
            : 'Le faltan ${week.remaining} sesiones para su meta de la semana.';
    return RumboCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Semantics(
            label: '${week.done} de ${week.goal} sesiones esta semana',
            child: ExcludeSemantics(
              child: ProgressRing(
                progress: week.goal == 0 ? 0 : week.done / week.goal,
                size: 76,
                stroke: 9,
                color: week.reached ? RumboColors.success : RumboColors.primary,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${week.done}', style: RumboText.kpi.copyWith(fontSize: 28, color: week.reached ? RumboColors.success : RumboColors.primary)),
                  Text('de ${week.goal}', style: RumboText.label.copyWith(fontSize: 13)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: RumboText.sectionTitle),
              const SizedBox(height: 2),
              Text(body, style: RumboText.help.copyWith(color: RumboColors.ink, fontSize: 16)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        WeekPath(days: days),
        if (week.weeksCompleted > 0) ...[
          const SizedBox(height: 12),
          NeutralChip(week.weeksCompleted == 1 ? '1 semana cumplida' : '${week.weeksCompleted} semanas cumplidas', icon: LucideIcons.flag),
        ],
      ]),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Prescription rx;
  final bool rightArm;
  final bool doneToday;
  const _TodayCard({required this.rx, required this.rightArm, required this.doneToday});

  @override
  Widget build(BuildContext context) {
    final n = rx.exercises.length;
    final minutes = ((rx.totalReps * 4 + rx.exercises.fold(0, (a, e) => a + e.restSec * e.sets)) / 60).round();
    return RumboCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(doneToday ? 'Hoy ya completó su sesión' : 'Su sesión de hoy', style: RumboText.sectionTitle)),
          if (doneToday) const Icon(LucideIcons.circleCheck, color: RumboColors.success, size: 26),
        ]),
        const SizedBox(height: 2),
        Text(
          doneToday
              ? 'Si quiere, puede repetirla.'
              : 'Hoy le tocan ${n == 1 ? '1 ejercicio' : '$n ejercicios'}, ${minutes <= 1 ? 'un par de minutos' : 'unos $minutes minutos'}. ¿Empezamos?',
          style: RumboText.help.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),
        for (final e in rx.exercises)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 56, child: ExerciseVideo(exerciseId: e.exerciseId, mirror: !rightArm, fallbackTitle: '')),
              const SizedBox(width: 14),
              Expanded(child: Text(e.name, style: RumboText.body)),
              Text('${e.sets} × ${e.reps}', style: RumboText.body.copyWith(fontWeight: FontWeight.w900, color: RumboColors.primary)),
            ]),
          ),
        if (rx.notes != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: RumboColors.primarySoft, borderRadius: BorderRadius.circular(RumboRadius.md)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(LucideIcons.messageCircle, size: 20, color: RumboColors.primaryInk),
              const SizedBox(width: 10),
              Expanded(child: Text('Nota de su fisioterapeuta: ${rx.notes}', style: RumboText.body.copyWith(fontSize: 16, color: RumboColors.primaryInk))),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  final MeData me;
  final DeviceSnapshot snap;
  const _DeviceTile({required this.me, required this.snap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = me.deviceName;
    if (name == null) {
      return const RumboCard(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(LucideIcons.pencil, color: RumboColors.warning, size: 26),
          SizedBox(width: 14),
          Expanded(child: Text('Sin reloj: marcará sus series a mano al terminar cada una.', style: RumboText.body)),
        ]),
      );
    }
    final busy = snap.conn == ConnState.searching || snap.conn == ConnState.connecting;
    final lowBattery = snap.connected && snap.battery != null && snap.battery! < 20;
    final (title, subtitle) = snap.connected
        ? (lowBattery ? 'El reloj tiene poca batería' : 'Reloj conectado', lowBattery ? 'Póngalo a cargar antes de su sesión.' : '$name${snap.battery != null ? ' · batería ${snap.battery}%' : ''}')
        : busy
            ? ('Buscando su reloj…', 'Acérquelo al teléfono.')
            : ('Reloj desconectado', snap.error ?? '$name · acérquelo al teléfono.');
    return RumboCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(children: [
        Icon(lowBattery ? LucideIcons.batteryLow : LucideIcons.watch,
            size: 28, color: lowBattery ? RumboColors.danger : (snap.connected ? RumboColors.success : RumboColors.slate)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: RumboText.body.copyWith(fontWeight: FontWeight.w800)),
            Text(subtitle, style: RumboText.help),
          ]),
        ),
        if (busy)
          const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)))
        else if (!snap.connected)
          TextButton(onPressed: () => ref.read(deviceProvider).connect(name), child: const Text('Conectar')),
      ]),
    );
  }
}
