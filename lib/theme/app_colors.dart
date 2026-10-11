import 'package:flutter/material.dart';

/// Brand colors for the "Soft Mint Cards" design.
class AppColors {
  AppColors._();

  // Greens
  static const Color primary = Color(0xFF0C6E3D); // main buttons, icons
  static const Color primaryDark = Color(0xFF0E3B25); // tab bar, strong text
  static const Color primaryBright = Color(0xFF14995A); // gradient end
  static const Color primaryLight = Color(0xFFE6F4EC); // icon tiles, chips
  static const Color primaryMuted = Color(0xFFD3E0DA); // disabled button

  /// Green gradient of the hero card and the digital ID.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryBright],
  );

  // Surfaces
  static const Color background = Color(0xFFF6FAF7); // page bg
  static const Color backgroundTop = Color(0xFFE6F4EC); // mint at the top
  static const Color card = Colors.white;
  static const Color inputFill = Color(0xFFE6F0FB); // phone field highlight
  static const Color border = Color(0xFF9FB3A9);
  static const Color borderStrong = Color(0xFF3F5A4E);

  /// Soft green shadow under white cards.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1F0C6E3D),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // Text
  static const Color textPrimary = Color(0xFF10211A);
  static const Color textSecondary = Color(0xFF4A6356);
  static const Color textOnPrimary = Colors.white;

  // Status
  static const Color success = Color(0xFF0C8A4B);
  static const Color warning = Color(0xFFF2A900);
  static const Color danger = Color(0xFFD93A3F);
  static const Color info = Color(0xFF1F5FA8); // "being checked"
}
