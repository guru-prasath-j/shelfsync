import 'package:flutter/material.dart';

/// Grocery palette: leaf green for actions, tomato red only for savings.
class AppColors {
  const AppColors._();
  static const leaf = Color(0xFF1F6F43);
  static const tomato = Color(0xFFC8402A);
  static const mint = Color(0xFFE6F2EA);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.leaf,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
  );
}
