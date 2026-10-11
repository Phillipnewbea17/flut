import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// "Assistance" (Home quick action): choose Medical or Burial. Each card
/// opens that kind's existing screen.
class AssistanceView extends StatelessWidget {
  const AssistanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Assistance'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: const [
          _AssistanceChoice(
            icon: Icons.medical_services_outlined,
            title: 'Medical assistance',
            hint: 'Medicine, check-ups, tests or hospital help',
            route: Routes.medical,
          ),
          SizedBox(height: 16),
          _AssistanceChoice(
            icon: Icons.local_florist_outlined,
            title: 'Burial assistance',
            hint: 'Help for the family when a senior passes away',
            route: Routes.burial,
          ),
        ],
      ),
    );
  }
}

/// A large card: icon, title, one-line hint and chevron.
class _AssistanceChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final String route;

  const _AssistanceChoice({
    required this.icon,
    required this.title,
    required this.hint,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $hint',
      excludeSemantics: true,
      child: InfoCard(
        outlined: true,
        padding: const EdgeInsets.all(18),
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(route);
        },
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 30),
          ],
        ),
      ),
    );
  }
}
