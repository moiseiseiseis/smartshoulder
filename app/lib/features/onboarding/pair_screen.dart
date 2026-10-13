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
              const _Step(2, 'La flecha del reloj apunta hacia los dedos.', icon: LucideIcons.arrowRight),
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
            label: 'Ilustración: reloj en la muñeca con la flecha hacia los dedos',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(RumboRadius.lg),
              child: AspectRatio(aspectRatio: 16 / 9, child: CustomPaint(painter: _WristPainter())),
            ),
          );
        },
      );
}

class _WristPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = RumboColors.primarySoft);
    final skin = Paint()..color = const Color(0xFFE9C7A8);
    // Antebrazo (izquierda) y mano (derecha).
    canvas.drawRRect(RRect.fromLTRBR(-20, h * 0.36, w * 0.66, h * 0.64, Radius.circular(h * 0.14)), skin);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.6, h * 0.30, w * 0.86, h * 0.70, Radius.circular(h * 0.16)), skin);
    for (var i = 0; i < 4; i++) {
      final y = h * (0.33 + i * 0.09);
      canvas.drawRRect(RRect.fromLTRBR(w * 0.8, y, w * 0.95, y + h * 0.07, Radius.circular(h * 0.035)), skin);
    }
    // Correa y reloj (sin pantalla: es la carcasa de Rumbo).
    final strap = Paint()..color = RumboColors.primaryInk;
    canvas.drawRRect(RRect.fromLTRBR(w * 0.4, h * 0.3, w * 0.48, h * 0.7, const Radius.circular(6)), strap);
    final body = RRect.fromLTRBR(w * 0.35, h * 0.34, w * 0.53, h * 0.66, const Radius.circular(14));
    canvas.drawRRect(body, Paint()..color = RumboColors.primary);
    // Flecha ▲ hacia los dedos (a la derecha).
    final cx = w * 0.44, cy = h * 0.5, a = h * 0.07;
    final arrow = Path()
      ..moveTo(cx + a, cy)
      ..lineTo(cx - a * 0.6, cy - a)
      ..lineTo(cx - a * 0.6, cy + a)
      ..close();
    canvas.drawPath(arrow, Paint()..color = RumboColors.accent);
    // Indicación punteada hacia los dedos.
    final dot = Paint()..color = RumboColors.accentDeep;
    for (var x = w * 0.56; x < w * 0.78; x += 12) {
      canvas.drawCircle(Offset(x, h * 0.18), 2.4, dot);
    }
    final tip = Path()
      ..moveTo(w * 0.8, h * 0.18)
      ..lineTo(w * 0.77, h * 0.14)
      ..lineTo(w * 0.77, h * 0.22)
      ..close();
    canvas.drawPath(tip, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
