import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../widgets/emergency_contact_form.dart';
import '../../widgets/onboarding_scaffold.dart';

/// "Emergency contact" - Step 4 of 4. Saving finishes setup and opens Home.
class EmergencySetupView extends StatelessWidget {
  const EmergencySetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>();
    final session = context.read<SessionProvider>();

    return OnboardingScaffold(
      title: 'Emergency contact',
      subtitle: OnboardingStage.emergencySetup.stepLabel!,
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
            submitLabel: 'Save & enter app home',
            submitIcon: Icons.save_outlined,
            onSubmit: (contact) async {
              await user.saveEmergencyContact(contact);
              await session.completeOnboarding();
            },
          ),
        ],
      ),
    );
  }
}
