import 'package:flutter/material.dart';

/// Grocery palette: leaf green for actions, tomato red only for savings.
class AppColors {
  const AppColors._();
  static const leaf = Color(0xFF1F6F43);
  static const leafDark = Color(0xFF16522F);
  static const tomato = Color(0xFFC8402A);
  static const mint = Color(0xFFE6F2EA);
  static const sun = Color(0xFFFFF4D6);
  static const ink = Color(0xFF1B1F1A);
  static const canvas = Color(0xFFF6F7F5);
}

/// Colours that must change between light and dark mode. Solid fills with
/// white text on top (buttons, cart bar, badges) keep using [AppColors];
/// green/red *text and icons* and the soft tinted backgrounds come from here
/// so they stay readable on a dark background.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.warnSoft,
    required this.warnBorder,
    required this.warnIcon,
    required this.onWarnSoft,
  });

  /// Green for text, icons and outlines on the page background.
  final Color accent;

  /// Soft green background behind icons and "you're saving" notes.
  final Color accentSoft;

  /// Red for errors, "out of stock" and savings text.
  final Color danger;

  /// Yellow note background (store notice, pending sync) and its details.
  final Color warnSoft;
  final Color warnBorder;
  final Color warnIcon;
  final Color onWarnSoft;

  static const light = AppPalette(
    accent: AppColors.leaf,
    accentSoft: AppColors.mint,
    danger: AppColors.tomato,
    warnSoft: AppColors.sun,
    warnBorder: Color(0xFFF3E2B0),
    warnIcon: Color(0xFF9A6B00),
    onWarnSoft: AppColors.ink,
  );

  static const dark = AppPalette(
    accent: Color(0xFF7DD8A3),
    accentSoft: Color(0xFF1D3426),
    danger: Color(0xFFFF8A75),
    warnSoft: Color(0xFF332A17),
    warnBorder: Color(0xFF524321),
    warnIcon: Color(0xFFFFCF6B),
    onWarnSoft: Color(0xFFF5E9CC),
  );

  @override
  AppPalette copyWith({
    Color? accent,
    Color? accentSoft,
    Color? danger,
    Color? warnSoft,
    Color? warnBorder,
    Color? warnIcon,
    Color? onWarnSoft,
  }) =>
      AppPalette(
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        danger: danger ?? this.danger,
        warnSoft: warnSoft ?? this.warnSoft,
        warnBorder: warnBorder ?? this.warnBorder,
        warnIcon: warnIcon ?? this.warnIcon,
        onWarnSoft: onWarnSoft ?? this.onWarnSoft,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      warnBorder: Color.lerp(warnBorder, other.warnBorder, t)!,
      warnIcon: Color.lerp(warnIcon, other.warnIcon, t)!,
      onWarnSoft: Color.lerp(onWarnSoft, other.onWarnSoft, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

/// Spacing and radius scale used across screens, so everything lines up.
class Gap {
  const Gap._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

class Radii {
  const Radii._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
}

/// Phone-first layout: on tablets and desktop browsers the content is
/// centred at this width instead of stretching edge to edge.
const kMaxContentWidth = 560.0;

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.leaf,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? null : AppColors.leaf,
    surface: isDark ? null : Colors.white,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleMedium:
        base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall:
        base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge:
        base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.sm),
  );

  return base.copyWith(
    textTheme: text,
    extensions: [isDark ? AppPalette.dark : AppPalette.light],
    scaffoldBackgroundColor: isDark ? scheme.surface : AppColors.canvas,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: isDark ? scheme.surface : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(64, 44),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(64, 44),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? scheme.surfaceContainerHigh : AppColors.canvas,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide.none,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
    ),
  );
}
