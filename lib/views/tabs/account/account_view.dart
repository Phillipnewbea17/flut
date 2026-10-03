import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../app_state/session_provider.dart';
import '../../../app_state/user_provider.dart';
import '../../../models/user_profile.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Account tab: who I am, settings, help, log out.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  Future<void> _logout(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?', style: TextStyle(fontSize: 26)),
        content: const Text(
          'Your information and photos will be removed from this phone. '
          'You can log in again with your phone number.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Log out',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final profile = user.profile;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          GreenHeaderStack(
            overlap: 70,
            header: Padding(
              padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 24),
              child: Semantics(
                header: true,
                child: Text(
                  context.tr('accountTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            card: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InfoCard(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.person_outline,
                          color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (profile?.fullName.isNotEmpty ?? false)
                                ? profile!.fullName
                                : 'Your name',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            profile?.displayPhone ?? '',
                            style: const TextStyle(
                              fontSize: 17,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (profile != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                profile.role.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Group(
                  title: context.tr('accountMyInfo'),
                  items: [
                    _Item(Icons.badge_outlined, context.tr('accountPersonal'),
                        Routes.personalInfo),
                    _Item(Icons.home_outlined, context.tr('accountAddress'),
                        Routes.address),
                    _Item(Icons.contact_phone_outlined,
                        context.tr('accountEmergency'), Routes.emergencyContact),
                  ],
                ),
                _Group(
                  title: context.tr('accountSettings'),
                  items: [
                    _Item(Icons.text_fields, context.tr('accountAccessibility'),
                        Routes.accessibility),
                    _Item(Icons.lock_outline, context.tr('accountChangeMpin'),
                        Routes.changeMpin),
                  ],
                ),
                _Group(
                  title: context.tr('accountHelp'),
                  items: [
                    _Item(Icons.help_outline, context.tr('accountFaq'), Routes.faq),
                    _Item(Icons.privacy_tip_outlined,
                        context.tr('accountPrivacy'), Routes.privacy),
                    _Item(Icons.support_agent_outlined,
                        context.tr('accountContact'), Routes.contact),
                  ],
                ),
                const SizedBox(height: 8),
                BigButton(
                  label: context.tr('accountLogout'),
                  icon: Icons.logout,
                  color: AppColors.danger,
                  onPressed: () => _logout(context),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SeniorCompanion 1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String route;

  const _Item(this.icon, this.label, this.route);
}

class _Group extends StatelessWidget {
  final String title;
  final List<_Item> items;

  const _Group({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: OnboardingScaffold.fieldLabel.copyWith(
                color: AppColors.textSecondary,
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
                    const Divider(height: 1, indent: 76, color: AppColors.primaryLight),
                  _Row(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final _Item item;

  const _Row({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(item.route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 19,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
