import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/identity_repository.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import '../../widgets/help_panel.dart';
import 'identity_actions.dart';

/// "Identity Verification": why the selfie is needed, then the camera.
class IdentityVerificationView extends StatelessWidget {
  const IdentityVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityRepository>();

    Widget body;
    if (!identity.confirmed) {
      // For example after the app was closed: the form must be confirmed
      // again first.
      body = HelpPanel(
        icon: Icons.assignment_outlined,
        title: 'Please confirm your information first.',
        message: 'We need your confirmed information before the selfie.',
        actions: [
          HelpAction('Go to my information', Icons.arrow_forward,
              () => IdentityActions.otherMethods(context)),
        ],
      );
    } else if (identity.outOfAttempts) {
      body = HelpPanel(
        icon: Icons.support_agent_outlined,
        color: AppColors.danger,
        title: 'Verification could not be completed.',
        message: 'Please contact OSCA for assistance.',
        actions: [
          HelpAction('Contact OSCA', Icons.support_agent_outlined,
              () => IdentityActions.contactOsca(context)),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 64,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.face_retouching_natural,
                  size: 72, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'We need to verify that you are the person connected to this '
            'senior citizen record.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'You will take a selfie with your phone camera. The OSCA office '
            'system compares it with your record. The selfie is sent only to '
            'the OSCA office and is not saved on this phone.',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 20),
          const _Tip(Icons.wb_sunny_outlined, 'Find a place with good light.'),
          const _Tip(Icons.face_outlined,
              'Remove sunglasses, a hat or a face mask.'),
          const _Tip(Icons.people_outline,
              'You may ask someone to hold the phone, but only your face '
                  'should be in the picture.'),
          const SizedBox(height: 24),
          BigButton(
            label: 'Start verification',
            icon: Icons.photo_camera_front_outlined,
            onPressed: () => context.push(Routes.selfie),
          ),
          if (identity.failedAttempts > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Tries left: ${identity.attemptsLeft}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppTheme.appBar('Identity Verification'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        children: [body],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 18, color: AppColors.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
