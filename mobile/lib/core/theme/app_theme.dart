import 'package:flutter/material.dart';
import 'package:taskinspect/core/theme/status_colors.dart';

/// Material 3 themes for TaskInspect. Colors are generated from one brand
/// seed color, so light and dark mode stay consistent and accessible.
abstract final class AppTheme {
  /// The brand color every other color is derived from.
  static const Color seed = Color(0xFF1565C0);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      extensions: [
        if (brightness == Brightness.light) StatusColors.light else StatusColors.dark,
      ],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}
