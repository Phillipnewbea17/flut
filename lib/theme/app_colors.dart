import 'package:flutter/material.dart';

/// Brand colors taken from the SeniorCompanion screenshots.
class AppColors {
  AppColors._();

  // Greens
  static const Color primary = Color(0xFF006838); // header + main buttons
  static const Color primaryDark = Color(0xFF00522C);
  static const Color primaryBright = Color(0xFF00923F); // "Verify" button
  static const Color primaryLight = Color(0xFFDDEFE3); // icon tiles, chips
  static const Color primaryMuted = Color(0xFFD3E0DA); // disabled button

  // Surfaces
  static const Color background = Color(0xFFEEF6F1); // page bg (light mint)
  static const Color card = Colors.white;
  static const Color inputFill = Color(0xFFE6F0FB); // phone field highlight
  static const Color border = Color(0xFF9FB3A9);
  static const Color borderStrong = Color(0xFF3F5A4E);

  // Text
  static const Color textPrimary = Color(0xFF10211A);
  static const Color textSecondary = Color(0xFF4A5E55);
  static const Color textOnPrimary = Colors.white;

  // Status
  static const Color success = Color(0xFF00923F);
  static const Color warning = Color(0xFFF2A900);
  static const Color danger = Color(0xFFD03B3B);
}
