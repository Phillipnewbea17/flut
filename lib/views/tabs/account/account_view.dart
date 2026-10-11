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
import '../../../widgets/menu_group.dart';
import '../../../widgets/profile_avatar.dart';

/// Account tab: who I am, settings, help, log out.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  Future<void> _logout(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?', style: TextStyle(fontSize: 22)),
        content: const Text(
          'Your information and photos will be removed from this phone. '
          'You can log in again with your phone number.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Log out',
              style: TextStyle(
                fontSize: 15,
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
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 20),
                child: Semantics(
                  header: true,
                  child: Text(
                    context.tr('accountTitle'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InfoCard(
                  child: Row(
                    children: [
                      // The app-profile photo, or the user's initials.
                      ProfileAvatar(profile: profile, radius: 30),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              profile?.displayPhone ?? '',
                              style: const TextStyle(
                                fontSize: 14,
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
                                    fontSize: 13,
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
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuGroup(
                  title: context.tr('accountMyInfo'),
                  items: [
                    _item(context, Icons.badge_outlined, 'accountPersonal',
                        Routes.personalInfo),
                    _item(context, Icons.contact_phone_outlined,
                        'accountEmergency', Routes.emergencyContact),
                  ],
                ),
                MenuGroup(
                  title: context.tr('accountSettings'),
                  items: [
                    _item(context, Icons.text_fields, 'accountAccessibility',
                        Routes.accessibility),
                    _item(context, Icons.lock_outline, 'accountChangeMpin',
                        Routes.changeMpin),
                  ],
                ),
                MenuGroup(
                  title: context.tr('accountHelp'),
                  items: [
                    _item(
                        context, Icons.help_outline, 'accountFaq', Routes.faq),
                    _item(context, Icons.privacy_tip_outlined, 'accountPrivacy',
                        Routes.privacy),
                    _item(context, Icons.support_agent_outlined,
                        'accountContact', Routes.contact),
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
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

MenuItem _item(
    BuildContext context, IconData icon, String labelKey, String route) {
  return MenuItem(
    icon: icon,
    label: context.tr(labelKey),
    onTap: () => context.push(route),
  );
}
