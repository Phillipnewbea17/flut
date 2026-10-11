import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/identity_verification.dart';
import '../../repositories/identity_repository.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/help_panel.dart';
import 'identity_actions.dart';

/// The backend's answer to the selfie. Only "verified", "pending review"
/// let the user go on.
class VerificationResultView extends StatefulWidget {
  const VerificationResultView({super.key});

  @override
  State<VerificationResultView> createState() => _VerificationResultViewState();
}

class _VerificationResultViewState extends State<VerificationResultView> {
  bool _busy = false;

  Future<void> _continue(VerificationResult result) async {
    if (_busy) return;
    setState(() => _busy = true);
    final identity = context.read<IdentityRepository>();
    final user = context.read<UserProvider>();
    final session = context.read<SessionProvider>();
    final profile = result.profile ?? identity.profile;
    if (profile != null) await user.applyLinkedProfile(profile);
    // The router moves on to the emergency contact or Home by itself.
    await session.completeIdentity();
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityRepository>();
    final result = identity.lastResult;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppTheme.appBar('Identity Verification'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          children: [
            if (result == null)
              HelpPanel(
                title: 'Please start again.',
                message: 'We could not find your verification result.',
                actions: [
                  HelpAction('Start again', Icons.refresh,
                      () => IdentityActions.otherMethods(context)),
                ],
              )
            else
              _panelFor(context, result, identity),
          ],
        ),
      ),
    );
  }

  Widget _panelFor(
    BuildContext context,
    VerificationResult result,
    IdentityRepository identity,
  ) {
    void contact() => IdentityActions.contactOsca(context);
    void checkInfo() => context.go(Routes.reviewInfo);
    final serverNote = result.message;

    switch (result.status) {
      case VerificationStatus.verified:
        return HelpPanel(
          icon: Icons.verified,
          color: AppColors.success,
          title: 'Account Verified',
          message: 'Your account has been successfully linked to your senior '
              'citizen record.',
          actions: [
            HelpAction(_busy ? 'Please wait...' : 'Continue to Home',
                Icons.arrow_forward, () => _continue(result)),
          ],
        );
      case VerificationStatus.pendingReview:
        return HelpPanel(
          icon: Icons.hourglass_top,
          color: AppColors.info,
          title: 'Waiting for the OSCA office',
          message: serverNote ??
              'Your information matches our records. The OSCA office will '
                  'now check your selfie and link your account.',
          tips: const [
            'Your account is NOT linked yet. Medical, Burial, Help, ID and '
                'pension services open once the OSCA office links it.',
          ],
          actions: [
            HelpAction(_busy ? 'Please wait...' : 'Continue',
                Icons.arrow_forward, () => _continue(result)),
          ],
        );
      case VerificationStatus.faceMismatch:
        return HelpPanel(
          icon: Icons.face_retouching_off,
          title: "We couldn't verify your identity from the selfie.",
          message: 'Please try the selfie again in a place with good light, '
              'looking straight at the camera.',
          tips: [
            'Tries left: ${identity.attemptsLeft}',
          ],
          actions: [
            HelpAction('Try again', Icons.refresh,
                () => context.pushReplacement(Routes.selfie)),
            HelpAction('Contact OSCA', Icons.support_agent_outlined, contact),
          ],
        );
      case VerificationStatus.tooManyAttempts:
        return HelpPanel(
          icon: Icons.support_agent_outlined,
          color: AppColors.danger,
          title: 'Verification could not be completed.',
          message: 'Please contact OSCA for assistance.',
          actions: [
            HelpAction('Contact OSCA', Icons.support_agent_outlined, contact),
          ],
        );
      case VerificationStatus.infoMismatch:
        return HelpPanel(
          icon: Icons.rule,
          title: 'Some information does not match our records.',
          message: 'Please review your information, especially your name, '
              'date of birth and Senior Citizen ID number.',
          actions: [
            HelpAction('Check my information', Icons.edit_note, checkInfo),
            HelpAction('Contact OSCA', Icons.support_agent_outlined, contact),
          ],
        );
      case VerificationStatus.notFound:
        return HelpPanel(
          icon: Icons.person_search_outlined,
          title: 'We could not find a matching senior citizen record.',
          message: 'Please check your information. If you are not registered '
              'yet, the OSCA office can help you register.',
          actions: [
            HelpAction('Try Again', Icons.edit_note, checkInfo),
            HelpAction('Contact OSCA', Icons.support_agent_outlined, contact),
          ],
        );
      case VerificationStatus.alreadyLinked:
        return HelpPanel(
          icon: Icons.link_off,
          color: AppColors.danger,
          title: 'This senior citizen record is already linked to an account.',
          message: 'Please contact OSCA if you believe this is an error.',
          actions: [
            HelpAction('Contact OSCA', Icons.support_agent_outlined, contact),
            HelpAction('Use another method', Icons.swap_horiz,
                () => IdentityActions.otherMethods(context)),
          ],
        );
      case VerificationStatus.unavailable:
        return HelpPanel(
          icon: Icons.cloud_off_outlined,
          title: 'We could not verify your identity right now.',
          message: serverNote ?? 'Please contact the OSCA office for help.',
          actions: [
            HelpAction('Contact OSCA', Icons.support_agent_outlined, contact),
            HelpAction('Back to my information', Icons.arrow_back, checkInfo),
          ],
        );
    }
  }
}
