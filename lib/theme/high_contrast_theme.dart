import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// Used when "High contrast" is on in Account > Text size and language.
/// White page, black text and thick black borders. main.dart also turns on
/// bold text for every Text widget while this theme is active.
class HighContrastTheme {
  HighContrastTheme._();

  static ThemeData light() {
    return AppTheme.build(
      background: Colors.white,
      text: Colors.black,
      secondaryText: const Color(0xFF1A1A1A),
      border: Colors.black,
      focus: AppColors.primaryDark,
      borderWidth: 2.5,
    );
  }
}
