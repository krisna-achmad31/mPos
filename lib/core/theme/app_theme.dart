import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Tema aplikasi yang mengikuti `design_ui.pen`.
///
/// Semua warna, radius, dan ukuran huruf diambil dari [AppPalette] /
/// [AppRadius] supaya satu sumber kebenaran dengan file desain.
///
/// Catatan font: desain memakai **Inter**. Keluarga font ditulis di sini
/// (`fontFamily`), jadi begitu aset `Inter` ditambahkan ke `pubspec.yaml`
/// (assets/fonts) aplikasi otomatis memakainya. Selama aset belum ada,
/// Flutter jatuh ke [fontFamilyFallback] sehingga tampilan tetap wajar.
abstract final class AppTheme {
  static const fontFamily = 'Inter';
  static const fontFamilyFallback = <String>['Roboto', 'Segoe UI', 'Arial', 'Helvetica'];

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = _scheme(brightness);
    final tokens = isLight ? AppTokens.light : AppTokens.dark;

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);

    return base.copyWith(
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.canvas,
      dividerColor: tokens.line,
      splashFactory: InkSparkle.splashFactory,
      extensions: [tokens],
      textTheme: _textTheme(base.textTheme, tokens),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _style(16, FontWeight.w600, tokens.ink),
        shape: Border(bottom: BorderSide(color: tokens.line)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        isDense: true,
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: _style(12, FontWeight.w500, tokens.muted),
        hintStyle: _style(13, FontWeight.w400, tokens.muted),
        helperStyle: _style(11, FontWeight.w400, tokens.muted),
        errorStyle: _style(11, FontWeight.w500, tokens.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          textStyle: _style(13, FontWeight.w600, scheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          foregroundColor: tokens.ink,
          side: BorderSide(color: tokens.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          textStyle: _style(13, FontWeight.w600, tokens.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          textStyle: _style(13, FontWeight.w600, scheme.primary),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: tokens.muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.canvas,
        side: BorderSide(color: tokens.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.badge)),
        labelStyle: _style(11, FontWeight.w600, tokens.muted),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
        titleTextStyle: _style(16, FontWeight.w600, tokens.ink),
        contentTextStyle: _style(13, FontWeight.w400, tokens.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.ink,
        contentTextStyle: _style(13, FontWeight.w500, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: tokens.muted,
        labelStyle: _style(13, FontWeight.w600, scheme.primary),
        unselectedLabelStyle: _style(13, FontWeight.w500, tokens.muted),
        dividerColor: tokens.line,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: tokens.primaryTint,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _style(11, FontWeight.w600, scheme.primary)
              : _style(11, FontWeight.w500, tokens.muted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? scheme.primary : tokens.muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: tokens.primaryTint,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        selectedLabelTextStyle: _style(11, FontWeight.w600, scheme.primary),
        unselectedLabelTextStyle: _style(11, FontWeight.w500, tokens.muted),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.primaryTint,
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.muted,
        textColor: tokens.ink,
        titleTextStyle: _style(13.5, FontWeight.w500, tokens.ink),
        subtitleTextStyle: _style(11.5, FontWeight.w400, tokens.muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearMinHeight: 3),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: tokens.ink, borderRadius: BorderRadius.circular(AppRadius.badge)),
        textStyle: _style(11.5, FontWeight.w500, Colors.white),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        textStyle: _style(13, FontWeight.w400, tokens.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.tile)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : tokens.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : tokens.line,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(BorderSide(color: tokens.line)),
          textStyle: WidgetStatePropertyAll(_style(12, FontWeight.w600, tokens.ink)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? tokens.primaryTint : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.primary : tokens.muted,
          ),
        ),
      ),
    );
  }

  /// ColorScheme eksplisit: nilai primer/garis/latar harus sama dengan desain,
  /// jadi tidak boleh hasil turunan `fromSeed`.
  static ColorScheme _scheme(Brightness brightness) {
    final tokens = brightness == Brightness.light ? AppTokens.light : AppTokens.dark;
    final isLight = brightness == Brightness.light;

    return ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: brightness,
    ).copyWith(
      primary: isLight ? AppPalette.primary : const Color(0xFF7FA6FF),
      onPrimary: isLight ? Colors.white : const Color(0xFF0B1730),
      primaryContainer: tokens.primaryTint,
      onPrimaryContainer: isLight ? AppPalette.primary : const Color(0xFFD6E2FF),
      secondary: tokens.muted,
      onSecondary: Colors.white,
      secondaryContainer: tokens.primaryTint,
      onSecondaryContainer: isLight ? AppPalette.primary : const Color(0xFFD6E2FF),
      tertiary: tokens.success,
      onTertiary: Colors.white,
      tertiaryContainer: tokens.successTint,
      onTertiaryContainer: tokens.success,
      error: tokens.danger,
      onError: Colors.white,
      errorContainer: tokens.dangerTint,
      onErrorContainer: tokens.danger,
      surface: isLight ? AppPalette.surface : const Color(0xFF161C29),
      onSurface: tokens.ink,
      onSurfaceVariant: tokens.muted,
      surfaceContainerLowest: isLight ? Colors.white : const Color(0xFF111725),
      surfaceContainerLow: tokens.canvas,
      surfaceContainer: tokens.canvas,
      surfaceContainerHigh: tokens.canvas,
      surfaceContainerHighest: tokens.canvas,
      outline: tokens.muted,
      outlineVariant: tokens.line,
      surfaceTint: tokens.primaryTint,
      shadow: const Color(0x1A17243B),
      scrim: const Color(0x8017243B),
    );
  }

  static TextStyle _style(double size, FontWeight weight, Color color) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.35,
  );

  static TextTheme _textTheme(TextTheme base, AppTokens tokens) {
    TextStyle s(double size, FontWeight weight) => TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: size,
      fontWeight: weight,
      color: tokens.ink,
      height: 1.35,
    );

    return base.copyWith(
      displaySmall: s(34, FontWeight.w700),
      headlineLarge: s(30, FontWeight.w700),
      headlineMedium: s(26, FontWeight.w700),
      headlineSmall: s(22, FontWeight.w700),
      titleLarge: s(18, FontWeight.w600),
      titleMedium: s(15, FontWeight.w600),
      titleSmall: s(13.5, FontWeight.w600),
      bodyLarge: s(14, FontWeight.w400),
      bodyMedium: s(13, FontWeight.w400),
      bodySmall: s(11.5, FontWeight.w400).copyWith(color: tokens.muted),
      labelLarge: s(13, FontWeight.w600),
      labelMedium: s(12, FontWeight.w500).copyWith(color: tokens.muted),
      labelSmall: s(11, FontWeight.w500).copyWith(color: tokens.muted),
    ).apply(bodyColor: tokens.ink, displayColor: tokens.ink);
  }
}
