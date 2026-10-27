import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/device/device_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../../ui/exercise_video.dart';

/// Emparejamiento del reloj asignado. Pensado para hacerse en consulta, con el fisio al lado (contexto/07 §5.2).
class PairScreen extends ConsumerWidget {
  const PairScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final snap = ref.watch(deviceSnapshotProvider).valueOrNull ?? const DeviceSnapshot();
    final name = me?.deviceName;
    final busy = snap.conn == ConnState.searching || snap.conn == ConnState.connecting;
    final arm = me?.rightArm == false ? 'izquierdo' : 'derecho';

    return Scaffold(
      appBar: AppBar(title: const Text('Su reloj')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          Text(snap.connected ? 'Su reloj está conectado' : 'Conecte su reloj', style: RumboText.screenTitle),
          const SizedBox(height: 6),
          Text(
            snap.connected
                ? 'Ahora póngaselo como se muestra.'
                : 'Su clínica le prestó el reloj $name. Acérquelo al teléfono y toque "Conectar".',
            style: RumboText.bodyRegular.copyWith(color: RumboColors.slate),
          ),
          const SizedBox(height: 20),
          const _Placement(),
          const SizedBox(height: 16),
          RumboCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Step(1, 'En la muñeca del brazo $arm, el que está en rehabilitación.'),
              const _Step(2, 'La flecha del reloj apunta hacia su pulgar.', icon: LucideIcons.arrowUp),
              const _Step(3, 'Un poco arriba del hueso de la muñeca, ajustado sin apretar.'),
            ]),
          ),
          const SizedBox(height: 16),
          if (name != null)
            Center(child: NeutralChip('Reloj $name', icon: LucideIcons.watch)),
          if (snap.error != null) ...[const SizedBox(height: 12), InlineNotice(kind: StatusKind.alert, text: snap.error!)],
          const SizedBox(height: 24),
          if (snap.connected) ...[
            OutlinedButton.icon(
              onPressed: () => ref.read(deviceProvider).identify(),
              icon: const Icon(LucideIcons.lightbulb),
              label: const Text('Hacer parpadear su luz'),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: () => context.go('/'), child: const Text('Listo, continuar')),
          ] else
            FilledButton.icon(
              onPressed: busy || name == null ? null : () => ref.read(deviceProvider).connect(name),
              icon: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Icon(LucideIcons.bluetooth),
              label: Text(busy ? (snap.conn == ConnState.searching ? 'Buscando su reloj…' : 'Conectando…') : 'Conectar'),
            ),
          const SizedBox(height: 4),
          TextButton(onPressed: () => context.go('/'), child: const Text('Hacerlo después')),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  final IconData? icon;
  const _Step(this.n, this.text, {this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: RumboColors.accent, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 16, color: RumboColors.ink)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: RumboText.body)),
          if (icon != null) Padding(padding: const EdgeInsets.only(left: 8, top: 2), child: Icon(icon, color: RumboColors.accentDeep, size: 24)),
        ]),
      );
}

/// Video de colocación (clip 7) si ya existe; si no, una ilustración del reloj en la muñeca.
class _Placement extends StatelessWidget {
  const _Placement();

  @override
  Widget build(BuildContext context) => FutureBuilder<Set<String>>(
        future: availableVideos(),
        builder: (context, s) {
          if (s.data?.contains(exerciseVideoFiles[7]) ?? false) {
            return const ExerciseVideo(exerciseId: 7, mirror: false, fallbackTitle: 'Cómo ponerse el reloj');
          }
          return Semantics(
            label: 'Ilustración: reloj en la muñeca con la flecha hacia el pulgar',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(RumboRadius.lg),
              child: AspectRatio(aspectRatio: 16 / 9, child: CustomPaint(painter: _WristPainter())),
            ),
          );
        },
      );
}

/// Vista desde arriba de la muñeca derecha, palma hacia abajo, dedos a la derecha: el pulgar queda arriba.
/// La flecha del reloj (y el conector USB-C) apuntan hacia el pulgar (regla de colocación, contexto/11).
class _WristPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = RumboColors.primarySoft);
    final skin = Paint()..color = const Color(0xFFE9C7A8);
    // Antebrazo (izquierda) y mano (derecha).
    canvas.drawRRect(RRect.fromLTRBR(-20, h * 0.42, w * 0.66, h * 0.70, Radius.circular(h * 0.14)), skin);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.6, h * 0.38, w * 0.84, h * 0.76, Radius.circular(h * 0.16)), skin);
    for (var i = 0; i < 4; i++) {
      final y = h * (0.42 + i * 0.085);
      canvas.drawRRect(RRect.fromLTRBR(w * 0.79, y, w * 0.95, y + h * 0.065, Radius.circular(h * 0.033)), skin);
    }
    // Pulgar (arriba de la mano).
    final thumb = Path()
      ..moveTo(w * 0.64, h * 0.44)
      ..quadraticBezierTo(w * 0.70, h * 0.16, w * 0.78, h * 0.20)
      ..quadraticBezierTo(w * 0.80, h * 0.30, w * 0.72, h * 0.44)
      ..close();
    canvas.drawPath(thumb, skin);
    // Correa y reloj.
    canvas.drawRRect(RRect.fromLTRBR(w * 0.4, h * 0.36, w * 0.48, h * 0.76, const Radius.circular(6)), Paint()..color = RumboColors.primaryInk);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.35, h * 0.40, w * 0.53, h * 0.72, const Radius.circular(14)), Paint()..color = RumboColors.primary);
    // Flecha ▲ hacia el pulgar (arriba).
    final cx = w * 0.44, cy = h * 0.56, a = h * 0.08;
    final arrow = Path()
      ..moveTo(cx, cy - a)
      ..lineTo(cx - a * 0.9, cy + a * 0.6)
      ..lineTo(cx + a * 0.9, cy + a * 0.6)
      ..close();
    canvas.drawPath(arrow, Paint()..color = RumboColors.accent);
    // Indicación punteada del reloj hacia el pulgar.
    final dot = Paint()..color = RumboColors.accentDeep;
    final from = Offset(w * 0.47, h * 0.33), to = Offset(w * 0.66, h * 0.16);
    for (var t = 0.0; t <= 1.0; t += 0.12) {
      canvas.drawCircle(Offset.lerp(from, to, t)!, 2.4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
