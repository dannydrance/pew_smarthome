import 'package:flutter/material.dart';

/// Brand colours taken from the website (navy, blue and yellow).
class Brand {
  Brand._();

  static const Color navy = Color(0xFF062F4F);
  static const Color navy2 = Color(0xFF083F67);
  static const Color blue = Color(0xFF1976D2);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color background = Color(0xFFF2F7FB);
  static const Color text = Color(0xFF113A5D);
  static const Color muted = Color(0xFF5B7489);
  static const Color line = Color(0xFFDCE7F0);
  static const Color good = Color(0xFF1E9E5A);
  static const Color warning = Color(0xFFE59A00);
  static const Color danger = Color(0xFFD64545);
  static const Color card = Colors.white;

  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navy2, Color(0xFF0D5288)],
  );
}

/// Colour with transparency, without APIs that changed between Flutter versions.
Color fade(Color color, double opacity) => color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.blue,
    primary: Brand.blue,
    secondary: Brand.yellow,
    surface: Colors.white,
    error: Brand.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: Brand.background,
    textTheme: base.textTheme.apply(bodyColor: Brand.text, displayColor: Brand.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.background,
      foregroundColor: Brand.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Brand.text, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.text,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Brand.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: fade(Brand.yellow, 0.35),
      elevation: 3,
      height: 68,
    ),
    dividerColor: Brand.line,
  );
}

/// Shared look for text fields (kept out of ThemeData for compatibility across Flutter versions).
InputDecoration fieldDecoration(String label, {String? hint, IconData? icon, String? helper, Widget? suffix, String? error}) {
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    errorText: error,
    errorMaxLines: 4,
    prefixIcon: icon == null ? null : Icon(icon, color: Brand.muted),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(Brand.line),
    enabledBorder: border(Brand.line),
    focusedBorder: border(Brand.blue, 1.6),
    errorBorder: border(Brand.danger),
    focusedErrorBorder: border(Brand.danger, 1.6),
  );
}
