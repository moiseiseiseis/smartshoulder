// Componentes base de Rumbo Rehab (identidad-marca §6, §11).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';

// ---------------------------------------------------------------- chips

enum StatusKind { verified, reported, alert }

/// Estado semántico: siempre ícono + color + texto (§3.2).
class StatusChip extends StatelessWidget {
  final StatusKind kind;
  final String? label;
  const StatusChip({super.key, required this.kind, this.label});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon, text) = switch (kind) {
      StatusKind.verified => (RumboColors.success, RumboColors.successSoft, LucideIcons.circleCheck, 'Verificado por el reloj'),
      StatusKind.reported => (RumboColors.warning, RumboColors.warningSoft, LucideIcons.pencil, 'Marcado a mano'),
      StatusKind.alert => (RumboColors.danger, RumboColors.dangerSoft, LucideIcons.triangleAlert, 'Atención'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Flexible(child: Text(label ?? text, style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: fg))),
      ]),
    );
  }
}

class NeutralChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const NeutralChip(this.label, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: RumboColors.line, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: RumboColors.slate), const SizedBox(width: 6)],
          Text(label, style: RumboText.label),
        ]),
      );
}

// ---------------------------------------------------------------- tarjeta

class RumboCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final double? width;
  const RumboCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = RumboRadius.lg, this.color, this.width});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? RumboColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: RumboColors.line),
        ),
        child: child,
      );
}

// ---------------------------------------------------------------- barra de series (§11)

/// Segmentos: hechas en Índigo, actual en Girasol, pendientes en Línea.
class SeriesBar extends StatelessWidget {
  final int total;
  final int done;
  final bool showCurrent;
  const SeriesBar({super.key, required this.total, required this.done, this.showCurrent = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Serie ${math.min(done + 1, total)} de $total',
      child: ExcludeSemantics(
        child: Row(children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: RumboMotion.of(context, RumboMotion.normal),
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: i < done
                      ? RumboColors.primary
                      : (i == done && showCurrent ? RumboColors.accent : RumboColors.line),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- anillo de progreso

class ProgressRing extends StatelessWidget {
  final double progress; // 0–1
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.stroke = 12,
    this.color = RumboColors.primary,
    this.track = RumboColors.line,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0, 1)),
      duration: RumboMotion.of(context, RumboMotion.normal),
      curve: RumboMotion.curve,
      builder: (_, p, __) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(p, stroke, color, track),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double p, stroke;
  final Color color, track;
  _RingPainter(this.p, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * math.pi, false, base..color = track);
    if (p > 0) canvas.drawArc(r, -math.pi / 2, 2 * math.pi * p, false, base..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.p != p || oldDelegate.color != color;
}

// ---------------------------------------------------------------- sendero semanal (§6)

enum DayMark { verified, reported, incomplete, pending }

class WeekDay {
  final String letter;
  final DayMark mark;
  final bool isToday;
  final String spoken; // para TalkBack
  const WeekDay(this.letter, this.mark, this.isToday, this.spoken);
}

/// "Su rumbo esta semana": 7 días unidos por un sendero punteado.
class WeekPath extends StatelessWidget {
  final List<WeekDay> days;
  const WeekPath({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const circle = 40.0;
      return SizedBox(
        height: circle + 28,
        child: Stack(children: [
          // El sendero: círculos explícitos (igual que el isotipo), no una línea con guiones.
          Positioned(
            left: circle / 2,
            right: circle / 2,
            top: circle / 2 - 2,
            child: CustomPaint(size: const Size.fromHeight(4), painter: _DotsPainter()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final d in days) _Day(d, circle)],
          ),
        ]),
      );
    });
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = RumboColors.mist;
    for (double x = 0; x <= size.width; x += 9) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Day extends StatelessWidget {
  final WeekDay d;
  final double size;
  const _Day(this.d, this.size);

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon, iconColor) = switch (d.mark) {
      DayMark.verified => (RumboColors.success, RumboColors.success, LucideIcons.check, Colors.white),
      DayMark.reported => (RumboColors.warning, RumboColors.warning, LucideIcons.pencil, Colors.white),
      DayMark.incomplete => (RumboColors.surface, RumboColors.mist, null, null),
      DayMark.pending => (d.isToday ? RumboColors.accent : RumboColors.surface, d.isToday ? RumboColors.accent : RumboColors.line, null, null),
    };
    return Semantics(
      label: d.spoken,
      child: ExcludeSemantics(
        child: Column(children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 2),
              boxShadow: d.isToday ? [BoxShadow(color: RumboColors.accent.withValues(alpha: 0.45), spreadRadius: 4)] : null,
            ),
            child: icon != null
                ? Icon(icon, size: 20, color: iconColor)
                : d.mark == DayMark.incomplete
                    ? const Center(child: SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: RumboColors.mist, shape: BoxShape.circle))))
                    : null,
          ),
          const SizedBox(height: 6),
          Text(d.letter, style: RumboText.label.copyWith(color: d.isToday ? RumboColors.ink : RumboColors.slate, fontWeight: d.isToday ? FontWeight.w900 : FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- estados vacíos y de error

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.color = RumboColors.primary,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: RumboText.sectionTitle),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: RumboText.bodyRegular.copyWith(color: RumboColors.slate)),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

/// Aviso en línea (sin internet, batería baja…).
class InlineNotice extends StatelessWidget {
  final StatusKind kind;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const InlineNotice({super.key, required this.kind, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (kind) {
      StatusKind.verified => (RumboColors.success, RumboColors.successSoft, LucideIcons.circleCheck),
      StatusKind.reported => (RumboColors.warning, RumboColors.warningSoft, LucideIcons.pencil),
      StatusKind.alert => (RumboColors.danger, RumboColors.dangerSoft, LucideIcons.triangleAlert),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(RumboRadius.md)),
      child: Row(children: [
        Icon(icon, color: fg, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: RumboText.body.copyWith(fontSize: 16, color: fg))),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!, style: TextStyle(color: fg))),
      ]),
    );
  }
}
