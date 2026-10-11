import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../repositories/identity_repository.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/method_card.dart';
import '../../widgets/onboarding_scaffold.dart';

/// "Personal Information" - Step 3 of 4. The user picks how to give their
/// information: scan the Senior Citizen ID, take a photo of it, or type it.
class PersonalInfoSetupView extends StatefulWidget {
  const PersonalInfoSetupView({super.key});

  @override
  State<PersonalInfoSetupView> createState() => _PersonalInfoSetupViewState();
}

class _PersonalInfoSetupViewState extends State<PersonalInfoSetupView> {
  @override
  void initState() {
    super.initState();
    // Choosing a method starts the form again (after "Use another method").
    final phone = context.read<UserProvider>().profile?.phone ?? '';
    final identity = context.read<IdentityRepository>();
    WidgetsBinding.instance.addPostFrameCallback((_) => identity.begin(phone));
  }

  Future<void> _manual() async {
    final identity = context.read<IdentityRepository>();
    await identity.begin(context.read<UserProvider>().profile?.phone ?? '');
    identity.useManualEntry();
    if (mounted) context.push(Routes.manualInfo);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?', style: TextStyle(fontSize: 24)),
        content: const Text(
          'You can log in again later with your phone number and finish '
          'setting up.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SessionProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.read<SessionProvider>().flow;

    return OnboardingScaffold(
      title: 'Verify Your Senior Citizen Account',
      subtitle:
          flow?.stepLabel(OnboardingStage.identitySetup) ?? 'One last step',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'To use SCMS services, we need to match your account with your '
            'senior citizen record.',
            style: OnboardingScaffold.cardTitle,
          ),
          const SizedBox(height: 10),
          const Text(
            'We will ask for your Senior Citizen (OSCA) ID number, full name '
            'and date of birth. Your mobile number is already verified. You '
            'can scan your ID to fill these in, or type them yourself.',
            style: OnboardingScaffold.cardBody,
          ),
          const SizedBox(height: 24),
          MethodCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan Senior Citizen ID',
            description:
                'Scan the QR code or supported information on your ID.',
            buttonLabel: 'Scan ID',
            recommended: true,
            onPressed: () => context.push(Routes.scanId),
          ),
          const SizedBox(height: 16),
          MethodCard(
            icon: Icons.photo_camera_outlined,
            title: 'Take Photo of ID',
            description: "Take a clear photo of your ID and we'll use the "
                'information to fill out the form.',
            buttonLabel: 'Take Photo',
            onPressed: () => context.push(Routes.captureId),
          ),
          const SizedBox(height: 16),
          MethodCard(
            icon: Icons.edit_note,
            title: 'Enter Manually',
            description: 'Enter your information yourself.',
            buttonLabel: 'Enter Manually',
            onPressed: _manual,
          ),
          const SizedBox(height: 20),
          const Text(
            'Why we ask: your account will be connected to your record at the '
            'OSCA office, so you can use your senior citizen services in the '
            'app.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _logout,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Not now? Log out',
                  style: OnboardingScaffold.linkText),
            ),
          ),
        ],
      ),
    );
  }
}

