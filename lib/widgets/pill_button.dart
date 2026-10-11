import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A rounded pill with a label and a small pencil: white on the green
/// header ("Change Photo"), mint on white with [tonal] ("Change Address").
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool tonal;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tonal ? AppColors.primaryLight : Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
