import 'package:flutter/material.dart';

/// ألوان الهوية: أسود فاخر + ذهبي "العراب"
class AppColors {
  static const gold = Color(0xFFD9B25F);
  static const goldDeep = Color(0xFFB08A3A);
  static const goldSoft = Color(0xFFF3E2B8);

  static const ink = Color(0xFF0D1015);
  static const inkSurface = Color(0xFF151A21);
  static const inkCard = Color(0xFF1B222B);
  static const inkLine = Color(0xFF2A323D);

  static const paper = Color(0xFFF6F3EC);
  static const paperCard = Color(0xFFFFFFFF);
  static const paperLine = Color(0xFFE6E0D3);

  static const success = Color(0xFF2FBF71);
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFF5A524);
  static const info = Color(0xFF3E8BFF);
  static const purple = Color(0xFF8B5CF6);
  static const teal = Color(0xFF14B8A6);

  static const asiacell = Color(0xFFE5202E);
  static const zain = Color(0xFF7B2D8E);
}

class AppTheme {
  static const fontFamily = 'Tajawal';

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final scheme = ColorScheme(
      brightness: b,
      primary: isDark ? AppColors.gold : AppColors.goldDeep,
      onPrimary: AppColors.ink,
      primaryContainer: isDark ? const Color(0xFF3A3020) : AppColors.goldSoft,
      onPrimaryContainer: isDark ? AppColors.goldSoft : const Color(0xFF3A2C0E),
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.inkSurface : AppColors.paper,
      onSurface: isDark ? const Color(0xFFECE7DC) : const Color(0xFF1C1B18),
      surfaceContainerLowest: isDark ? AppColors.ink : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF181E26) : const Color(0xFFFBF9F4),
      surfaceContainer: isDark ? AppColors.inkCard : AppColors.paperCard,
      surfaceContainerHigh: isDark ? const Color(0xFF222A35) : const Color(0xFFF1ECE1),
      surfaceContainerHighest: isDark ? const Color(0xFF29323E) : const Color(0xFFEAE3D5),
      onSurfaceVariant: isDark ? const Color(0xFF9AA3AF) : const Color(0xFF6B665C),
      outline: isDark ? AppColors.inkLine : AppColors.paperLine,
      outlineVariant: isDark ? const Color(0xFF232B35) : const Color(0xFFEFEAE0),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: isDark ? AppColors.ink : AppColors.paper,
      splashFactory: InkSparkle.splashFactory,
    );

    final radius = BorderRadius.circular(16);
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outline.withValues(alpha: .6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh.withValues(alpha: isDark ? .6 : 1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: .5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .7)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(fontFamily: fontFamily, color: scheme.onSurface, fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A323D) : const Color(0xFF1C1B18),
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: .5), space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.inkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: .18),
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
              color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
        indicator: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
