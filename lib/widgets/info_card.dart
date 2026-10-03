import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// White rounded card with soft shadow. Used for the login card, the
/// application-status card and the announcement cards.
class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool outlined; // true = thin green outline (Quick action tiles)

  const InfoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: outlined ? 0 : 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: outlined
            ? const BorderSide(color: AppColors.primaryLight, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
