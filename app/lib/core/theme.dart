// Sistema visual de Rumbo Rehab (brand/identidad-marca-rumbo-rehab.md).
// Fuente única: si cambia la marca, se cambia aquí.
import 'package:flutter/material.dart';

abstract class RumboColors {
  static const primary = Color(0xFF3F3A9E); // Índigo
  static const primaryInk = Color(0xFF2A2766);
  static const primarySoft = Color(0xFFE2E0F4); // Lavanda
  static const onPrimaryMuted = Color(0xFFD9D6F2);
  static const accent = Color(0xFFF2B33D); // Girasol: la meta, hoy, el progreso actual
  static const accentDeep = Color(0xFFB87C0C); // Girasol pequeño sobre fondo claro
  static const ink = Color(0xFF1E1B3A); // Tinta
  static const slate = Color(0xFF55516E); // Pizarra
  static const mist = Color(0xFF9A96AE); // Niebla: solo decorativo, nunca texto
  static const line = Color(0xFFE8E5F0);
  static const canvas = Color(0xFFFAF8F4); // Crema
  static const surface = Color(0xFFFFFFFF);
  // Semánticos: siempre con ícono + texto
  static const success = Color(0xFF0B7A62); // verificado / completa
  static const successSoft = Color(0xFFE3F3EE);
  static const warning = Color(0xFF915400); // reportado / incompleta
  static const warningSoft = Color(0xFFFBF0DC);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFBE7E5);
}

abstract class RumboSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0, xxxl = 48.0;
}

abstract class RumboRadius {
  static const sm = 8.0, md = 12.0, lg = 20.0, xl = 28.0;
}

/// Movimiento (§12): 200–300 ms ease-out; nada si el sistema pide reducir animaciones.
abstract class RumboMotion {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 600);
  static const curve = Curves.easeOut;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

const _font = 'Nunito';

/// Estilos de texto de la app del paciente (§4): cuerpo 18, nunca menos de 15.
abstract class RumboText {
  static const counter = TextStyle(fontFamily: _font, fontSize: 104, height: 1, fontWeight: FontWeight.w900, color: RumboColors.primary);
  static const kpi = TextStyle(fontFamily: _font, fontSize: 40, height: 1.1, fontWeight: FontWeight.w900, color: RumboColors.primary);
  static const screenTitle = TextStyle(fontFamily: _font, fontSize: 26, height: 1.2, fontWeight: FontWeight.w900, color: RumboColors.ink);
  static const sectionTitle = TextStyle(fontFamily: _font, fontSize: 20, height: 1.3, fontWeight: FontWeight.w800, color: RumboColors.ink);
  static const body = TextStyle(fontFamily: _font, fontSize: 18, height: 1.5, fontWeight: FontWeight.w600, color: RumboColors.ink);
  static const bodyRegular = TextStyle(fontFamily: _font, fontSize: 18, height: 1.5, fontWeight: FontWeight.w400, color: RumboColors.ink);
  static const label = TextStyle(fontFamily: _font, fontSize: 15, height: 1.3, fontWeight: FontWeight.w800, color: RumboColors.slate);
  static const help = TextStyle(fontFamily: _font, fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: RumboColors.slate);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: RumboColors.primary).copyWith(
    primary: RumboColors.primary,
    onPrimary: Colors.white,
    primaryContainer: RumboColors.primarySoft,
    onPrimaryContainer: RumboColors.primaryInk,
    secondary: RumboColors.accent,
    onSecondary: RumboColors.ink,
    surface: RumboColors.surface,
    onSurface: RumboColors.ink,
    onSurfaceVariant: RumboColors.slate,
    outline: RumboColors.mist,
    outlineVariant: RumboColors.line,
    error: RumboColors.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _font, scaffoldBackgroundColor: RumboColors.canvas);
  const pill = StadiumBorder();
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: RumboText.screenTitle,
      titleLarge: RumboText.sectionTitle,
      titleMedium: RumboText.sectionTitle.copyWith(fontSize: 18),
      bodyLarge: RumboText.bodyRegular,
      bodyMedium: RumboText.bodyRegular.copyWith(fontSize: 16),
      bodySmall: RumboText.help,
      labelLarge: const TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: pill,
        textStyle: const TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: pill,
        foregroundColor: RumboColors.primary,
        side: const BorderSide(color: RumboColors.primary, width: 2),
        textStyle: const TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: RumboColors.primary,
        textStyle: const TextStyle(fontFamily: _font, fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    cardTheme: CardTheme(
      color: RumboColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RumboRadius.lg), side: const BorderSide(color: RumboColors.line)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RumboColors.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: RumboColors.ink,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: _font, fontSize: 22, fontWeight: FontWeight.w900, color: RumboColors.ink),
    ),
    dividerTheme: const DividerThemeData(color: RumboColors.line, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: RumboColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RumboColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(RumboRadius.md), borderSide: const BorderSide(color: RumboColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RumboRadius.md), borderSide: const BorderSide(color: RumboColors.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RumboRadius.md), borderSide: const BorderSide(color: RumboColors.primary, width: 2)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RumboColors.primary : null),
    ),
  );
}
