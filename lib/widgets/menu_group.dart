import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'info_card.dart';
import 'onboarding_scaffold.dart';

/// One row of a [MenuGroup]: big icon, label, optional second line.
class MenuItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });
}

/// A titled card of tappable rows (Account, Benefits, ID services).
class MenuGroup extends StatelessWidget {
  final String? title;
  final List<MenuItem> items;

  const MenuGroup({super.key, this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: OnboardingScaffold.fieldLabel.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          InfoCard(
            outlined: true,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1, indent: 70, color: AppColors.primaryLight),
                  _MenuRow(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final MenuItem item;

  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
