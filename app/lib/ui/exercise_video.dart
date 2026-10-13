import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../core/theme.dart';
import 'brand.dart';

/// Archivos de los clips (contexto/10 §6): se grabaron con el brazo derecho.
const exerciseVideoFiles = {
  1: 'assets/videos/1-flexion.mp4',
  2: 'assets/videos/2-abduccion.mp4',
  3: 'assets/videos/3-rotacion-externa.mp4',
  4: 'assets/videos/4-rotacion-interna.mp4',
  5: 'assets/videos/5-triceps.mp4',
  6: 'assets/videos/6-remo.mp4',
  7: 'assets/videos/7-colocacion.mp4',
};

Future<Set<String>>? _available;

/// Qué videos vienen en la app (los que aún no se graban muestran la tarjeta de respaldo).
Future<Set<String>> availableVideos() => _available ??= AssetManifest.loadFromAssetBundle(rootBundle)
    .then((m) => m.listAssets().where((a) => a.endsWith('.mp4')).toSet())
    .catchError((_) => <String>{});

/// Clip del ejercicio en bucle, sin audio. Para el hombro izquierdo se muestra en espejo.
class ExerciseVideo extends StatefulWidget {
  final int exerciseId;
  final bool mirror;
  final String fallbackTitle;
  const ExerciseVideo({super.key, required this.exerciseId, required this.mirror, required this.fallbackTitle});

  @override
  State<ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<ExerciseVideo> {
  VideoPlayerController? _c;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ExerciseVideo old) {
    super.didUpdateWidget(old);
    if (old.exerciseId != widget.exerciseId) {
      _c?.dispose();
      _c = null;
      _missing = false;
      _load();
    }
  }

  Future<void> _load() async {
    final file = exerciseVideoFiles[widget.exerciseId];
    final available = await availableVideos();
    if (file == null || !available.contains(file)) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final c = VideoPlayerController.asset(file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) return c.dispose();
      setState(() => _c = c);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _missing = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final Widget child;
    if (c != null && c.value.isInitialized) {
      child = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: Transform.flip(flipX: widget.mirror, child: VideoPlayer(c)),
        ),
      );
    } else if (_missing) {
      child = _Fallback(title: widget.fallbackTitle);
    } else {
      child = const ColoredBox(color: RumboColors.primarySoft);
    }
    return Semantics(
      label: 'Video del ejercicio ${widget.fallbackTitle}',
      child: ClipRRect(borderRadius: BorderRadius.circular(RumboRadius.lg), child: AspectRatio(aspectRatio: 1, child: child)),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String title;
  const _Fallback({required this.title});

  @override
  Widget build(BuildContext context) => Container(
        color: RumboColors.primarySoft,
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(LucideIcons.activity, size: 40, color: RumboColors.primary),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: RumboText.sectionTitle.copyWith(color: RumboColors.primaryInk)),
          const SizedBox(height: 12),
          const Opacity(opacity: 0.5, child: RumboIsotipo(size: 32)),
        ]),
      );
}
