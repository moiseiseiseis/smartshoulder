import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// Calendario de adherencia del propio paciente (contexto/01 §4.5).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi historial')),
      body: h.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(historyProvider.future),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(d.streak > 0 ? '🔥 ${d.streak} ${d.streak == 1 ? 'día' : 'días'} seguidos' : 'Hoy es un buen día para empezar tu racha',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: _Calendar(days: d.calendar))),
            const SizedBox(height: 24),
            Text('Sesiones', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (d.sessions.isEmpty) const Text('Aún no tienes sesiones.', style: TextStyle(fontSize: 17)),
            for (final s in d.sessions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.status == DayStatus.complete ? Icons.check_circle : Icons.timelapse,
                  color: s.status == DayStatus.complete ? SsColors.verified : SsColors.reported,
                  size: 30,
                ),
                title: Text(DateFormat("EEEE d 'de' MMMM", 'es').format(s.startedAt), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                subtitle: Text('${s.repsDone} de ${s.repsPrescribed} repeticiones', style: const TextStyle(fontSize: 15)),
                trailing: SourceChip(verified: s.verified),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  final List<HistoryDay> days;
  const _Calendar({required this.days});

  static const _colors = {
    DayStatus.complete: SsColors.dayComplete,
    DayStatus.incomplete: SsColors.dayIncomplete,
    DayStatus.aborted: SsColors.dayAborted,
    DayStatus.none: SsColors.dayNone,
  };

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final pad = days.first.day.weekday - 1; // lunes = 0
    final cells = <HistoryDay?>[...List.filled(pad, null), ...days];
    return Column(children: [
      Row(children: [
        for (final d in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
          Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 14, color: SsColors.muted)))),
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
            c == null
                ? const SizedBox.shrink()
                : Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _colors[c.status], borderRadius: BorderRadius.circular(8)),
                    child: Text('${c.day.day}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.status == DayStatus.complete ? Colors.white : const Color(0xFF17202A))),
                  ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 6, children: [
        for (final (s, label) in [(DayStatus.complete, 'Completa'), (DayStatus.incomplete, 'Incompleta'), (DayStatus.none, 'Sin sesión')])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: _colors[s], borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 14)),
          ]),
      ]),
    ]);
  }
}
