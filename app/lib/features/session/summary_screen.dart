import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import 'session_screen.dart';

/// Resumen y envío. El dolor y el esfuerzo son datos que reporta el paciente, no los mide el reloj.
class SummaryScreen extends ConsumerStatefulWidget {
  final SessionOutcome outcome;
  const SummaryScreen({super.key, required this.outcome});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

enum _Sent { no, sending, sent, queued }

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  int? _pain;
  int? _effort;
  _Sent _sent = _Sent.no;
  late final String _clientId = const Uuid().v4();

  Map<String, dynamic> _payload() {
    final o = widget.outcome;
    final e = o.engine;
    return {
      'clientSessionId': _clientId,
      'prescriptionId': o.me.prescription!.id,
      'source': o.verified ? 'VERIFIED' : 'REPORTED',
      if (o.verified) 'deviceBleName': o.me.deviceName,
      if (o.verified && o.fwVersion != null) 'fwVersion': o.fwVersion,
      if (o.verified && o.modelVersion != null) 'modelVersion': o.modelVersion,
      if (o.verified && o.battery != null) 'deviceBattery': o.battery,
      'startedAt': (e.startedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'endedAt': (e.endedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'endedEarly': e.endedEarly,
      if (_pain != null) 'painScore': _pain,
      if (_effort != null) 'effortScore': _effort,
      'results': e.results.map((r) => r.toJson()).toList(),
      if (o.verified) 'events': o.events.map((ev) => ev.toJson()).toList(),
    };
  }

  Future<void> _send() async {
    setState(() => _sent = _Sent.sending);
    final queue = ref.read(queueProvider);
    await queue.enqueue(_payload()); // primero se guarda en el teléfono
    final left = await queue.flush();
    ref.invalidate(historyProvider);
    if (mounted) setState(() => _sent = left == 0 ? _Sent.sent : _Sent.queued);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.outcome.engine;
    final t = Theme.of(context).textTheme;
    final complete = !e.endedEarly && e.totalDone >= e.totalPrescribed * 0.9;
    final sentDone = _sent == _Sent.sent || _sent == _Sent.queued;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(complete ? Icons.emoji_events_outlined : Icons.thumb_up_alt_outlined, size: 64, color: complete ? SsColors.verified : SsColors.primary),
              const SizedBox(height: 12),
              Text(complete ? '¡Completaste tu sesión!' : '¡Buen trabajo!', style: t.headlineMedium),
              const SizedBox(height: 6),
              Text(
                complete ? 'Hiciste todas tus repeticiones de hoy.' : 'Hiciste ${e.totalDone} de ${e.totalPrescribed} repeticiones. Cada sesión cuenta.',
                style: t.bodyLarge,
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: SourceChip(verified: widget.outcome.verified)),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    for (var i = 0; i < e.plan.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Icon(
                            e.results[i].repsDone >= e.plan[i].sets * e.plan[i].reps * 0.9 ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: e.results[i].repsDone >= e.plan[i].sets * e.plan[i].reps * 0.9 ? SsColors.verified : SsColors.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.plan[i].name, style: t.bodyLarge)),
                          Text('${e.results[i].repsDone} / ${e.plan[i].sets * e.plan[i].reps}', style: t.titleMedium),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              Text('¿Cuánto dolor sentiste?', style: t.titleLarge),
              const SizedBox(height: 4),
              Text('0 = nada · 10 = el peor dolor', style: t.bodySmall),
              const SizedBox(height: 12),
              _scale(_pain, (v) => setState(() => _pain = v), danger: true, enabled: !sentDone),
              const SizedBox(height: 24),
              Text('¿Qué tan pesado se sintió?', style: t.titleLarge),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final (label, v) in [('Fácil', 3), ('Moderado', 6), ('Muy pesado', 9)])
                  ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 18)),
                    selected: _effort == v,
                    onSelected: sentDone ? null : (_) => setState(() => _effort = v),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
              ]),
              const SizedBox(height: 32),
              if (!sentDone)
                FilledButton(
                  onPressed: _sent == _Sent.sending ? null : _send,
                  child: _sent == _Sent.sending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Text('Enviar a mi fisioterapeuta'),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: SsColors.verifiedSoft, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(_sent == _Sent.sent ? Icons.cloud_done_outlined : Icons.cloud_queue, color: SsColors.verified),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _sent == _Sent.sent ? 'Enviado a tu fisioterapeuta.' : 'Guardado. Se enviará a tu fisioterapeuta cuando tengas conexión.',
                        style: const TextStyle(fontSize: 17, color: SsColors.verified, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.go('/'), child: const Text('Listo')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Escala 0–10 en dos filas de botones grandes (un toque, fácil con una mano).
  Widget _scale(int? value, ValueChanged<int> onChanged, {bool danger = false, bool enabled = true}) {
    Widget button(int i) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Semantics(
              button: true,
              selected: value == i,
              label: 'Dolor $i',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: enabled ? () => onChanged(i) : null,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == i ? (danger ? Color.lerp(SsColors.verified, SsColors.danger, i / 10) : SsColors.primary) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E5EA)),
                  ),
                  child: ExcludeSemantics(
                    child: Text('$i', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: value == i ? Colors.white : null)),
                  ),
                ),
              ),
            ),
          ),
        );
    return Column(children: [
      Row(children: [for (var i = 0; i <= 5; i++) button(i)]),
      Row(children: [for (var i = 6; i <= 10; i++) button(i), const Expanded(child: SizedBox())]),
    ]);
  }
}
