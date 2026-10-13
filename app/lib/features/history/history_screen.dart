import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';

/// Historial del paciente con el mismo lenguaje de colores que ve su fisio (contexto/01 §4.5).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi historial')),
      body: h.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: LucideIcons.wifiOff,
          title: 'No pudimos cargar su historial',
          body: 'Revise que tenga internet e intente de nuevo.',
          actionLabel: 'Intentar de nuevo',
          onAction: () => ref.invalidate(historyProvider),
        ),
        data: (d) => d.sessions.isEmpty
            ? const EmptyState(
                icon: LucideIcons.calendarDays,
                title: 'Aquí verá su camino',
                body: 'Cuando haga su primera sesión, aparecerá en este calendario.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(historyProvider.future),
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
                  if (d.week != null) _Summary(week: d.week!, total: d.sessions.length),
                  const SizedBox(height: 16),
                  RumboCard(child: _Calendar(days: d.calendar)),
                  const SizedBox(height: 24),
                  const Text('Sesiones', style: RumboText.sectionTitle),
                  const SizedBox(height: 8),
                  for (final s in d.sessions) _SessionTile(s),
                ]),
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final WeekInfo week;
  final int total;
  const _Summary({required this.week, required this.total});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _Kpi(value: '${week.done} de ${week.goal}', label: 'esta semana')),
        const SizedBox(width: 12),
        Expanded(child: _Kpi(value: '${week.weeksCompleted}', label: week.weeksCompleted == 1 ? 'semana cumplida' : 'semanas cumplidas')),
        const SizedBox(width: 12),
        Expanded(child: _Kpi(value: '$total', label: 'sesiones recientes')),
      ]);
}

class _Kpi extends StatelessWidget {
  final String value;
  final String label;
  const _Kpi({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => RumboCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(children: [
          FittedBox(child: Text(value, style: RumboText.kpi.copyWith(fontSize: 28))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: RumboText.help.copyWith(fontSize: 15)),
        ]),
      );
}

class _Calendar extends StatelessWidget {
  final List<HistoryDay> days;
  const _Calendar({required this.days});

  static const _colors = {
    DayStatus.complete: RumboColors.success,
    DayStatus.incomplete: RumboColors.warningSoft,
    DayStatus.aborted: RumboColors.warningSoft,
    DayStatus.none: RumboColors.line,
  };

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final pad = days.first.day.weekday - 1; // lunes = 0
    final cells = <HistoryDay?>[...List.filled(pad, null), ...days];
    final today = DateTime.now();
    return Column(children: [
      Row(children: [
        for (final d in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
          Expanded(child: Center(child: Text(d, style: RumboText.label))),
      ]),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          for (final c in cells)
            if (c == null)
              const SizedBox.shrink()
            else
              Semantics(
                label: '${DateFormat("d 'de' MMMM", 'es').format(c.day)}: ${switch (c.status) {
                  DayStatus.complete => 'sesión completa',
                  DayStatus.incomplete || DayStatus.aborted => 'sesión incompleta',
                  DayStatus.none => 'sin sesión',
                }}',
                child: ExcludeSemantics(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _colors[c.status],
                      borderRadius: BorderRadius.circular(10),
                      border: DateUtils.isSameDay(c.day, today) ? Border.all(color: RumboColors.primary, width: 2.5) : null,
                    ),
                    child: Text('${c.day.day}',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.status == DayStatus.complete ? Colors.white : RumboColors.ink,
                        )),
                  ),
                ),
              ),
        ],
      ),
      const SizedBox(height: 14),
      const Wrap(spacing: 16, runSpacing: 6, children: [
        _Legend(RumboColors.success, 'Completa'),
        _Legend(RumboColors.warningSoft, 'Incompleta'),
        _Legend(RumboColors.line, 'Sin sesión'),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: RumboText.help),
      ]);
}

class _SessionTile extends StatelessWidget {
  final HistorySession s;
  const _SessionTile(this.s);

  @override
  Widget build(BuildContext context) {
    final complete = s.status == DayStatus.complete;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RumboCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(complete ? LucideIcons.circleCheck : LucideIcons.circleDashed, color: complete ? RumboColors.success : RumboColors.accentDeep, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(s.startedAt)), style: RumboText.body.copyWith(fontWeight: FontWeight.w800)),
              Text('${s.repsDone} de ${s.repsPrescribed} repeticiones', style: RumboText.help),
              const SizedBox(height: 6),
              StatusChip(kind: s.verified ? StatusKind.verified : StatusKind.reported),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
