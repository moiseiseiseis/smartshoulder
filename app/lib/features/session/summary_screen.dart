import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/brand.dart';
import '../../ui/components.dart';
import 'session_screen.dart';

/// Resumen y envío. El dolor y el esfuerzo los reporta el paciente; no los mide el reloj.
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
    final complete = !e.endedEarly && e.totalDone >= e.totalPrescribed * 0.9;
    final sentDone = _sent == _Sent.sent || _sent == _Sent.queued;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(child: complete ? const AnimatedIsotipo(size: 112, delay: Duration(milliseconds: 200)) : const RumboIsotipo(size: 96)),
              const SizedBox(height: 16),
              Text(complete ? 'Sesión completa' : 'Buen trabajo', textAlign: TextAlign.center, style: RumboText.screenTitle.copyWith(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                complete
                    ? 'Hizo todas sus repeticiones de hoy.'
                    : 'Hizo ${e.totalDone} de ${e.totalPrescribed} repeticiones. Cada sesión cuenta.',
                textAlign: TextAlign.center,
                style: RumboText.bodyRegular.copyWith(color: RumboColors.slate),
              ),
              const SizedBox(height: 12),
              Center(child: StatusChip(kind: widget.outcome.verified ? StatusKind.verified : StatusKind.reported)),
              const SizedBox(height: 20),
              RumboCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(children: [
                  for (var i = 0; i < e.plan.length; i++) _ResultRow(name: e.plan[i].name, done: e.results[i].repsDone, total: e.plan[i].sets * e.plan[i].reps),
                ]),
              ),
              const SizedBox(height: 28),
              const Text('¿Cuánto dolor sintió?', style: RumboText.sectionTitle),
              const SizedBox(height: 4),
              const Text('Toque un número. 0 es sin dolor y 10 el peor dolor.', style: RumboText.help),
              const SizedBox(height: 12),
              PainScale(value: _pain, enabled: !sentDone, onChanged: (v) => setState(() => _pain = v)),
              const SizedBox(height: 24),
              const Text('¿Qué tan pesado se sintió?', style: RumboText.sectionTitle),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (label, v) in [('Fácil', 3), ('Moderado', 6), ('Muy pesado', 9)])
                  ChoiceChip(
                    label: Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w800)),
                    selected: _effort == v,
                    onSelected: sentDone ? null : (_) => setState(() => _effort = v),
                    showCheckmark: false,
                    selectedColor: RumboColors.primarySoft,
                    side: BorderSide(color: _effort == v ? RumboColors.primary : RumboColors.line, width: 2),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
              ]),
              const SizedBox(height: 32),
              if (!sentDone)
                FilledButton.icon(
                  onPressed: _sent == _Sent.sending ? null : _send,
                  icon: _sent == _Sent.sending
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Icon(LucideIcons.send),
                  label: const Text('Enviar a mi fisioterapeuta'),
                )
              else ...[
                InlineNotice(
                  kind: StatusKind.verified,
                  text: _sent == _Sent.sent
                      ? 'Enviado. Su fisioterapeuta ya puede verla.'
                      : 'Guardado en el teléfono. Se enviará cuando tenga internet.',
                ),
                const SizedBox(height: 16),
                const _WeekAfterSend(),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.go('/'), child: const Text('Listo')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String name;
  final int done, total;
  const _ResultRow({required this.name, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final ok = done >= total * 0.9;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(ok ? LucideIcons.circleCheck : LucideIcons.circle, color: ok ? RumboColors.success : RumboColors.mist, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: RumboText.body)),
        Text('$done de $total', style: RumboText.body.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Después de enviar: cómo va la meta de la semana (sin presión).
class _WeekAfterSend extends ConsumerWidget {
  const _WeekAfterSend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(historyProvider).valueOrNull?.week;
    if (week == null) return const SizedBox.shrink();
    final text = week.reached
        ? 'Cumplió su meta de la semana: ${week.done} de ${week.goal} sesiones.'
        : 'Lleva ${week.done} de ${week.goal} sesiones esta semana.';
    return RumboCard(
      child: Row(children: [
        ProgressRing(
          progress: week.goal == 0 ? 0 : week.done / week.goal,
          size: 56,
          stroke: 7,
          color: week.reached ? RumboColors.success : RumboColors.primary,
          child: Icon(week.reached ? LucideIcons.flag : LucideIcons.calendarDays, size: 22, color: week.reached ? RumboColors.success : RumboColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: RumboText.body)),
      ]),
    );
  }
}

/// Escala de dolor propia (doc 09 §3.2): 0–10 en dos filas de botones de 56 dp, gradiente de color
/// y caritas originales en 0, 5 y 10. No usa la escala Wong-Baker (tiene derechos de autor).
class PainScale extends StatelessWidget {
  final int? value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  const PainScale({super.key, required this.value, required this.onChanged, this.enabled = true});

  static Color colorFor(int i) => Color.lerp(RumboColors.success, RumboColors.danger, i / 10)!;

  @override
  Widget build(BuildContext context) {
    Widget button(int i) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Semantics(
              button: true,
              selected: value == i,
              label: 'Dolor $i${i == 0 ? ', sin dolor' : i == 10 ? ', el peor dolor' : ''}',
              child: ExcludeSemantics(
                child: Material(
                  color: value == i ? colorFor(i) : RumboColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RumboRadius.md),
                    side: BorderSide(color: value == i ? colorFor(i) : RumboColors.line, width: 2),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(RumboRadius.md),
                    onTap: enabled ? () => onChanged(i) : null,
                    child: SizedBox(
                      height: 56,
                      child: Center(
                        child: Text('$i',
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w900, color: value == i ? Colors.white : RumboColors.ink)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Column(children: [
      Row(children: [for (var i = 0; i <= 5; i++) button(i)]),
      Row(children: [for (var i = 6; i <= 10; i++) button(i), const Expanded(child: SizedBox())]),
      const SizedBox(height: 8),
      const ExcludeSemantics(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _FaceLabel(mood: 1, label: 'Sin dolor'),
          _FaceLabel(mood: 0, label: 'Moderado'),
          _FaceLabel(mood: -1, label: 'El peor dolor'),
        ]),
      ),
    ]);
  }
}

class _FaceLabel extends StatelessWidget {
  final double mood; // 1 sonrisa, 0 neutral, -1 molestia
  final String label;
  const _FaceLabel({required this.mood, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = PainScale.colorFor(((1 - mood) * 5).round());
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CustomPaint(size: const Size.square(26), painter: _FacePainter(mood, color)),
      const SizedBox(width: 6),
      Text(label, style: RumboText.help.copyWith(fontSize: 15)),
    ]);
  }
}

class _FacePainter extends CustomPainter {
  final double mood;
  final Color color;
  _FacePainter(this.mood, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(w / 2, w / 2), w / 2 - stroke.strokeWidth / 2, stroke);
    final eye = Paint()..color = color;
    canvas.drawCircle(Offset(w * 0.36, w * 0.4), w * 0.06, eye);
    canvas.drawCircle(Offset(w * 0.64, w * 0.4), w * 0.06, eye);
    final y = w * 0.66;
    final mouth = Path()
      ..moveTo(w * 0.32, y)
      ..quadraticBezierTo(w * 0.5, y + mood * w * 0.18, w * 0.68, y);
    canvas.drawPath(mouth, stroke);
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => oldDelegate.mood != mood;
}
