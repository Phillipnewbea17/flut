import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Big bold heading for a part of a page ("Quick actions").
class SectionTitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const SectionTitle(this.text, {super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Page top for a bottom-navigation tab: big dark title on the mint page,
/// and one line under it.
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const TabHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The soft mint page behind every bottom-navigation tab: mint at the top,
/// fading to the light page color.
class MintBackground extends StatelessWidget {
  final Widget child;

  const MintBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.45],
          colors: [AppColors.backgroundTop, AppColors.background],
        ),
      ),
      child: child,
    );
  }
}

/// A bordered card with an icon and a short message (tips, warnings).
class NoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? title;
  final Color color;

  const NoticeCard({
    super.key,
    required this.icon,
    required this.text,
    this.title,
    this.color = AppColors.primary,
  });

  /// "This service is not connected to the OSCA office yet."
  const NoticeCard.notConnected({super.key, required this.text})
      : icon = Icons.cloud_off_outlined,
        title = 'Not connected to the OSCA office yet',
        color = AppColors.warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
