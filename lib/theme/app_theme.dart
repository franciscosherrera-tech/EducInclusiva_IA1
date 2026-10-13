import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Temas de la app en un solo lugar. El color principal lo elige cada usuario.
class AppTheme {
  static const Color _darkSurface = Color(0xFF1E232A);
  static const Color _darkBackground = Color(0xFF14171D);
  static const Color _darkCard = Color(0xFF222831);

  /// En fondos oscuros, los colores muy oscuros (como el azul marino) casi no se
  /// ven: se aclaran lo justo para que se lean sin cambiar su tono.
  static Color forDarkSurface(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness >= 0.4) return color;
    return hsl.withLightness(0.5).toColor();
  }

  static ThemeData light(Color primary) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        brightness: Brightness.light,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: const CardThemeData(color: Colors.white, elevation: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark(Color primary, {bool highContrast = false}) {
    final accent = highContrast ? primary : forDarkSurface(primary);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        brightness: Brightness.dark,
        surface: highContrast ? Colors.black : _darkSurface,
      ),
      scaffoldBackgroundColor: highContrast ? Colors.black : _darkBackground,
      cardTheme: CardThemeData(
        color: highContrast ? Colors.grey.shade900 : _darkCard,
        elevation: 2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: highContrast ? Colors.black : _darkSurface,
        foregroundColor: highContrast ? Colors.yellowAccent : Colors.white,
        elevation: 0,
      ),
    );
  }
}
