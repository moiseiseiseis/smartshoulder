import 'package:flutter/material.dart';

/// Mismos colores que el dashboard (web/src/app/globals.css).
class SsColors {
  static const primary = Color(0xFF0D5C70);
  static const primarySoft = Color(0xFFE3EFF2);
  static const verified = Color(0xFF0B7A62);
  static const verifiedSoft = Color(0xFFDFF3EC);
  static const reported = Color(0xFF915400);
  static const reportedSoft = Color(0xFFFCEFD9);
  static const danger = Color(0xFFB42318);
  static const bg = Color(0xFFF5F6F8);
  static const muted = Color(0xFF5D6874);
  static const dayComplete = Color(0xFF1F9D72);
  static const dayIncomplete = Color(0xFFF2C46D);
  static const dayAborted = Color(0xFFE2766C);
  static const dayNone = Color(0xFFE6E9EE);
}

/// Pensado para adultos mayores y una sola mano: texto base de 18, botones de 56 dp o más (contexto/01 §8).
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: SsColors.primary, primary: SsColors.primary, surface: Colors.white);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: SsColors.bg);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF17202A)),
      titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF17202A)),
      titleMedium: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Color(0xFF17202A)),
      bodyLarge: const TextStyle(fontSize: 18, height: 1.4, color: Color(0xFF17202A)),
      bodyMedium: const TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF17202A)),
      bodySmall: const TextStyle(fontSize: 14, color: SsColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE2E5EA))),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: SsColors.bg, surfaceTintColor: Colors.transparent, centerTitle: false),
  );
}

/// Insignia de origen del apego: ícono + texto, nunca solo color.
class SourceChip extends StatelessWidget {
  final bool verified;
  const SourceChip({super.key, required this.verified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: verified ? SsColors.verifiedSoft : SsColors.reportedSoft, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(verified ? Icons.watch_outlined : Icons.back_hand_outlined, size: 16, color: verified ? SsColors.verified : SsColors.reported),
        const SizedBox(width: 4),
        Text(verified ? 'Con reloj' : 'Sin reloj',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: verified ? SsColors.verified : SsColors.reported)),
      ]),
    );
  }
}
