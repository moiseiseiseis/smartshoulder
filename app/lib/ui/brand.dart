// Isotipo y logotipo de Rumbo Rehab dibujados en código (geometría de identidad-marca §8.1, viewBox 48×48).
// Dibujarlo así permite animar a la figura "subiendo los brazos" al completar una sesión (§12).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

enum IsotipoVariant { color, negative, small }

class IsotipoPainter extends CustomPainter {
  /// 0 → solo el sendero; 1 → figura completa. El arco se dibuja desde abajo hacia los dos brazos.
  final double arms;
  final IsotipoVariant variant;

  IsotipoPainter({this.arms = 1, this.variant = IsotipoVariant.color});

  static const _dots = [Offset(8, 42), Offset(12.3, 35.2), Offset(20.3, 32.3), Offset(27.3, 27.8)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 48;
    canvas.save();
    canvas.translate((size.width - 48 * s) / 2, (size.height - 48 * s) / 2);
    canvas.scale(s);

    final dotColor = variant == IsotipoVariant.negative ? Colors.white : RumboColors.primary;
    final figure = variant == IsotipoVariant.small ? RumboColors.accentDeep : RumboColors.accent;
    final dot = Paint()..color = dotColor;
    for (final d in _dots) {
      canvas.drawCircle(d, 2.5, dot);
    }

    if (arms > 0) {
      final arc = Path()
        ..moveTo(27.5, 10)
        ..quadraticBezierTo(36, 28, 44.5, 10);
      final metric = arc.computeMetrics().first;
      final half = metric.length / 2;
      final reach = half * arms.clamp(0, 1);
      final stroke = Paint()
        ..color = figure
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(metric.extractPath(half - reach, half + reach), stroke);
      // La cabeza aparece al final, cuando los brazos ya subieron.
      final head = ((arms - 0.7) / 0.3).clamp(0.0, 1.0);
      if (head > 0) canvas.drawCircle(const Offset(36, 9), 4.5 * head, Paint()..color = figure);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(IsotipoPainter oldDelegate) => oldDelegate.arms != arms || oldDelegate.variant != variant;
}

class RumboIsotipo extends StatelessWidget {
  final double size;
  final IsotipoVariant variant;
  final double arms;
  const RumboIsotipo({super.key, this.size = 48, this.variant = IsotipoVariant.color, this.arms = 1});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(size: Size.square(size), painter: IsotipoPainter(arms: arms, variant: variant)),
      );
}

/// Isotipo cuya figura sube los brazos al aparecer (celebración de sesión completa).
class AnimatedIsotipo extends StatefulWidget {
  final double size;
  final Duration delay;
  const AnimatedIsotipo({super.key, this.size = 96, this.delay = Duration.zero});

  @override
  State<AnimatedIsotipo> createState() => _AnimatedIsotipoState();
}

class _AnimatedIsotipoState extends State<AnimatedIsotipo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: RumboMotion.slow);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (RumboMotion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      Future.delayed(widget.delay, () => mounted ? _c.forward() : null);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => RumboIsotipo(size: widget.size, arms: Curves.easeOutCubic.transform(_c.value)),
      );
}

/// Logotipo: isotipo + "rumbo" (Nunito 900) + "REHAB" espaciado (§2.2).
class RumboLogo extends StatelessWidget {
  final double fontSize; // tamaño de "rumbo"
  final bool vertical;
  final bool negative;
  const RumboLogo({super.key, this.fontSize = 40, this.vertical = false, this.negative = false});

  @override
  Widget build(BuildContext context) {
    final name = Text('rumbo',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 0.9,
          letterSpacing: -0.02 * fontSize,
          color: negative ? Colors.white : RumboColors.primary,
        ));
    final tag = Text('REHAB',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          fontSize: fontSize * 0.26,
          letterSpacing: 0.42 * fontSize * 0.26,
          color: negative ? RumboColors.onPrimaryMuted : RumboColors.slate,
        ));
    final iso = RumboIsotipo(size: fontSize * 1.45, variant: negative ? IsotipoVariant.negative : IsotipoVariant.color);
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [name, SizedBox(height: fontSize * 0.1), tag],
    );
    return Semantics(
      label: 'Rumbo Rehab',
      child: ExcludeSemantics(
        child: vertical
            ? Column(mainAxisSize: MainAxisSize.min, children: [iso, SizedBox(height: fontSize * 0.25), text])
            : Row(mainAxisSize: MainAxisSize.min, children: [iso, SizedBox(width: fontSize * 0.25), text]),
      ),
    );
  }
}
