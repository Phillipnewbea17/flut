import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The mint rounded square with a green icon (Personal information rows,
/// Change address fields).
class IconTile extends StatelessWidget {
  final IconData icon;

  const IconTile(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.primary, size: 24),
    );
  }
}
