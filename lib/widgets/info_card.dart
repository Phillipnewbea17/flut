import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// White rounded card with a soft green shadow, floating on the mint page.
/// Used for the login card, the announcement cards, menus and lists.
class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool outlined; // true = flatter card for tiles and list rows

  const InfoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(outlined ? 22 : 26);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: outlined
            ? const [
                BoxShadow(
                  color: Color(0x140C6E3D),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : AppColors.cardShadow,
      ),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: outlined
              ? const BorderSide(color: Color(0xFFEDF5F0), width: 1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
