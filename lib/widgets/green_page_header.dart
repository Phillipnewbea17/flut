import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../theme/app_colors.dart';

/// The green page header with rounded bottom corners (Personal information,
/// Change address): a back button, the centered title, then [child].
class GreenPageHeader extends StatelessWidget {
  final String title;
  final Widget? child;

  /// Where back goes when there is nothing to pop.
  final String fallbackRoute;

  const GreenPageHeader({
    super.key,
    required this.title,
    this.child,
    this.fallbackRoute = Routes.account,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 28),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _BackButton(
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(fallbackRoute),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                // Same width as the back button so the title stays centered.
                const SizedBox(width: 52),
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 16),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The rounded, see-through square back button.
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.chevron_left, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
