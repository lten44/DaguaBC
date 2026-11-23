// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'tokens.dart';

const appFontFamily = 'SourceHanSansSC';

ThemeData appTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? darkAppColors : lightAppColors;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.orange,
    brightness: brightness,
    surface: colors.surface,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme.copyWith(
      primary: colors.orange,
      onPrimary: Colors.white,
      secondary: colors.orange,
      onSecondary: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    ),
    scaffoldBackgroundColor: colors.background,
    fontFamily: appFontFamily,
    extensions: [colors],
  );
  return base.copyWith(
    textTheme: _buildTextTheme(colors),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .64),
      shadowColor: Colors.black.withValues(alpha: .28),
      elevation: 18,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsRadius.md),
        side: BorderSide(color: colors.borderStrong),
      ),
      titleTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      contentTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 13,
        height: 1.5,
        color: colors.textSecondary,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      iconColor: colors.orange,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.textSecondary,
        overlayColor: colors.orange.withValues(alpha: 0.10),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.orangeFill,
        foregroundColor: colors.onOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsRadius.sm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsRadius.sm),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsRadius.lg),
        side: BorderSide(color: colors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CsRadius.md),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CsRadius.md),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CsRadius.md),
        borderSide: BorderSide(color: colors.orange, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CsRadius.md),
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.orange,
      selectionColor: colors.orange.withValues(alpha: 0.25),
      selectionHandleColor: colors.orange,
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface3,
      labelStyle: TextStyle(
        color: colors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsRadius.full),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.orange.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

TextTheme _buildTextTheme(AppColors colors) => TextTheme(
  displayLarge: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: -0.6,
    color: colors.textPrimary,
  ),
  displayMedium: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.35,
    color: colors.textPrimary,
  ),
  displaySmall: TextStyle(fontFamily: appFontFamily, color: colors.textPrimary),
  headlineLarge: TextStyle(fontFamily: appFontFamily, color: colors.textPrimary),
  headlineMedium: TextStyle(fontFamily: appFontFamily, color: colors.textPrimary),
  headlineSmall: TextStyle(fontFamily: appFontFamily, color: colors.textPrimary),
  titleLarge: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.15,
    color: colors.textPrimary,
  ),
  titleMedium: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: colors.textPrimary,
  ),
  titleSmall: TextStyle(fontFamily: appFontFamily, color: colors.textPrimary),
  bodyLarge: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: colors.textPrimary,
  ),
  bodyMedium: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: colors.textPrimary,
  ),
  bodySmall: TextStyle(fontFamily: appFontFamily, color: colors.textPrimary),
  labelLarge: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: colors.textPrimary,
  ),
  labelMedium: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: colors.textPrimary,
  ),
  labelSmall: TextStyle(
    fontFamily: appFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: colors.textPrimary,
  ),
);

TextStyle numericTextStyle(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
