import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'AtkinsonHyperlegible';

  /// The normal green theme.
  static ThemeData light() => build();

  /// Builds the theme. The high contrast theme calls this with darker
  /// colors and thicker borders (see high_contrast_theme.dart).
  static ThemeData build({
    Color background = AppColors.background,
    Color text = AppColors.textPrimary,
    Color secondaryText = AppColors.textSecondary,
    Color border = AppColors.borderStrong,
    Color focus = AppColors.primaryBright,
    double borderWidth = 1.5,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.card,
    );

    OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        headlineMedium: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: text),
        bodyMedium: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: const TextStyle(color: Color(0xFF8A9A92), fontSize: 16),
        enabledBorder: outline(border, borderWidth),
        disabledBorder: outline(AppColors.border, borderWidth),
        focusedBorder: outline(focus, borderWidth + 1.5),
        errorBorder: outline(AppColors.danger, borderWidth + 0.5),
        focusedErrorBorder: outline(AppColors.danger, borderWidth + 1.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : secondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 30,
            color: selected ? AppColors.primary : secondaryText,
          );
        }),
      ),
    );
  }

  /// Green top bar used by every sub page (Calculator, FAQ, and so on).
  static AppBar appBar(
    String title, {
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: Text(title),
      actions: actions,
      bottom: bottom,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 60,
      titleSpacing: 4,
      titleTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
    );
  }
}
