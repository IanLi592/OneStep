import 'package:flutter/material.dart';

import 'palette.dart';

/// 跬步/Onestep 主题：墨青纸感。
///
/// 色板、字阶、圆角、硬阴影全部来自 [InkTokens]，这里只负责把它们装配进 Material 的
/// ThemeData，使 M3 原生控件（对话框、菜单、滑杆、输入框）也自动穿同一套皮。
class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final p = InkPalette(brightness);
    final scheme = _scheme(brightness, p);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.paper,
      canvasColor: p.paper,
      // 墨点涟漪：InkRipple 跟随 colorScheme.primary，天然就是墨青，
      // 不像 M3 的水波纹会晕出偏紫色调破坏纸感。
      splashFactory: InkRipple.splashFactory,
      textTheme: _textTheme(p),
      appBarTheme: AppBarTheme(
        backgroundColor: p.paper,
        foregroundColor: p.ink1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: InkTokens.s4,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: p.ink1,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkTokens.rCard),
          side: BorderSide(color: p.line, width: InkTokens.borderWidth),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: InkTokens.s5),
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.sunken,
          disabledForegroundColor: p.ink3,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(InkTokens.rButton)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: p.ink2,
          disabledForegroundColor: p.ink3,
          side: BorderSide(color: p.line, width: InkTokens.borderWidth),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(InkTokens.rButton)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.ink2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        hintStyle: TextStyle(color: p.ink3),
        labelStyle: TextStyle(color: p.ink2),
        contentPadding: const EdgeInsets.symmetric(horizontal: InkTokens.s4, vertical: InkTokens.s4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkTokens.rButton),
          borderSide: BorderSide(color: p.line, width: InkTokens.borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkTokens.rButton),
          borderSide: BorderSide(color: p.line, width: InkTokens.borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkTokens.rButton),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: InkTokens.borderWidth, space: InkTokens.borderWidth),
      dividerColor: p.line,
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.ink1,
        ),
        contentTextStyle: TextStyle(fontSize: 14.5, height: 1.5, color: p.ink2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkTokens.rCard),
          side: BorderSide(color: p.line, width: InkTokens.borderWidth),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(InkTokens.rSheet)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primaryPale,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.primary : p.ink3,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.primary : p.ink3,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.sunken,
        thumbColor: p.primary,
        overlayColor: p.primaryPale,
        trackHeight: 5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.sunken,
        circularTrackColor: p.sunken,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.ink2,
        titleTextStyle: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.ink1),
        subtitleTextStyle: TextStyle(fontSize: 13, color: p.ink2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink1,
        contentTextStyle: TextStyle(color: p.paper, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(InkTokens.rButton)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkTokens.rButton),
          side: BorderSide(color: p.line, width: InkTokens.borderWidth),
        ),
        textStyle: TextStyle(fontSize: 14.5, color: p.ink1),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.primaryPale : p.card,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.primary : p.ink2,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.line, width: InkTokens.borderWidth)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: p.primary, selectionColor: p.primaryPale),
    );
  }

  static ColorScheme _scheme(Brightness b, InkPalette p) {
    final base = ColorScheme.fromSeed(seedColor: p.primary, brightness: b);
    return base.copyWith(
      primary: p.primary,
      onPrimary: Colors.white,
      primaryContainer: p.primaryPale,
      onPrimaryContainer: p.ink1,
      secondary: p.primary,
      onSecondary: Colors.white,
      secondaryContainer: p.primaryPale,
      onSecondaryContainer: p.ink1,
      tertiary: p.pine,
      onTertiary: Colors.white,
      error: p.cinnabar,
      onError: Colors.white,
      errorContainer: p.cinnabar.withValues(alpha: 0.14),
      onErrorContainer: p.cinnabar,
      surface: p.paper,
      onSurface: p.ink1,
      surfaceContainerLowest: p.paper,
      surfaceContainerLow: p.card,
      surfaceContainer: p.card,
      surfaceContainerHigh: p.sunken,
      surfaceContainerHighest: p.sunken,
      onSurfaceVariant: p.ink2,
      outline: p.ink3,
      outlineVariant: p.line,
      shadow: p.isDark ? const Color(0xFF000000) : const Color(0xFFB9AE97),
      scrim: const Color(0xFF000000),
      inverseSurface: p.ink1,
      onInverseSurface: p.paper,
    );
  }

  static TextTheme _textTheme(InkPalette p) {
    return TextTheme(
      displaySmall: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: 0.5, color: p.ink1),
      headlineMedium: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, color: p.ink1),
      headlineSmall: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w700, height: 1.25, color: p.ink1),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink1),
      titleMedium: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.ink1),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink2),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: p.ink1),
      bodyMedium: TextStyle(fontSize: 14.5, height: 1.55, color: p.ink1),
      bodySmall: TextStyle(fontSize: 13, height: 1.5, color: p.ink2),
      labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink1),
      labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink2),
      labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: p.ink3),
    );
  }
}
