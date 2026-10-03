import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BigButtonStyle { filled, tonal }

/// Large, high-contrast button used on every onboarding screen.
/// - [filled]: dark green (SEND OTP, SAVE & ENTER APP HOME)
/// - [tonal]:  light green with green outline (CHOOSE FROM PHONE CONTACTS)
/// Passing `onPressed: null` shows the greyed-out disabled look.
class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool trailingIcon; // true = arrow on the right side
  final VoidCallback? onPressed;
  final BigButtonStyle style;
  final Color? color;

  const BigButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon = false,
    this.style = BigButtonStyle.filled,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isFilled = style == BigButtonStyle.filled;

    final Color bg = !enabled
        ? AppColors.primaryMuted
        : isFilled
            ? (color ?? AppColors.primary)
            : AppColors.primaryLight;
    final Color fg = !enabled
        ? AppColors.textSecondary
        : isFilled
            ? AppColors.textOnPrimary
            : AppColors.primary;

    final iconWidget =
        icon == null ? null : Icon(icon, color: fg, size: 28);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: (!isFilled && enabled)
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconWidget != null && !trailingIcon) ...[
                    iconWidget,
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fg,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (iconWidget != null && trailingIcon) ...[
                    const SizedBox(width: 12),
                    iconWidget,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
