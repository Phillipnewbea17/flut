import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/emergency_contact_form.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Change the person the SOS button calls.
class EmergencyContactView extends StatelessWidget {
  const EmergencyContactView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>();

    return Scaffold(
      appBar: AppTheme.appBar('Emergency contact'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who should we call in an emergency?',
                  style: OnboardingScaffold.cardTitle,
                ),
                const SizedBox(height: 10),
                const Text(
                  'The SOS button on your Home screen will contact this person.',
                  style: OnboardingScaffold.cardBody,
                ),
                const SizedBox(height: 24),
                EmergencyContactForm(
                  initial: user.emergencyContact,
                  ownPhone: user.profile?.phone,
                  submitLabel: 'Save changes',
                  onSubmit: (contact) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final router = GoRouter.of(context);
                    await user.saveEmergencyContact(contact);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Emergency contact saved.',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                    if (router.canPop()) router.pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
