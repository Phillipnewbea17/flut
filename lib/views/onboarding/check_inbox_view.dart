import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state/auth/login_flow.dart';
import '../../app_state/auth/registration_flow.dart';
import '../../app_state/session_provider.dart';
import '../../demo/demo_mode.dart';
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';

/// "Check your inbox": shown after signing up, and when logging in to an
/// account whose address was never confirmed.
///
/// Confirming happens in the senior's email app, not here: they tap the
/// link, a page served by the backend confirms it, and then they come back
/// and log in. So this screen only offers "Resend email" and a way to
/// Login — it never claims the address is confirmed.
class CheckInboxView extends StatefulWidget {
  const CheckInboxView({super.key});

  @override
  State<CheckInboxView> createState() => _CheckInboxViewState();
}

class _CheckInboxViewState extends State<CheckInboxView> {
  String? _error;
  String? _sent;
  bool _busy = false;

  /// Which flow brought us here: signing up, or a login that was refused.
  bool get _fromRegister =>
      context.read<SessionProvider>().flow == AuthFlow.register;

  String get _email {
    final email = _fromRegister
        ? context.read<RegistrationFlow>().email
        : context.read<LoginFlow>().unverifiedEmail;
    return email.isEmpty ? 'your email address' : email;
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _sent = null;
    });
    try {
      final already = _fromRegister
          ? await context.read<RegistrationFlow>().resendVerification()
          : await context.read<LoginFlow>().resendVerification();
      if (!mounted) return;
      setState(() => _sent = already
          ? 'That address is already confirmed. You can log in now.'
          : 'We are sending the email again. It should arrive within a '
              'minute.');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = const AuthException(AuthError.unknown).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goToLogin() async {
    if (_fromRegister) {
      await context.read<RegistrationFlow>().goToLogin();
    } else {
      await context.read<LoginFlow>().backToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;

    return OnboardingScaffold(
      title: 'Check Your Inbox',
      subtitle: 'One last step',
      onBack: _busy ? null : _goToLogin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Icon(Icons.mark_email_unread_outlined,
                size: 76, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              style: OnboardingScaffold.cardBody,
              children: [
                // The backend queues the email, so it is on its way rather
                // than already in the inbox.
                const TextSpan(text: 'We are sending an email to '),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(
                  text: '. It should arrive within a minute. Open it and tap '
                      'the green "Confirm my email" button, then come back '
                      'here and log in.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'If it is not there, please look in your Spam or Junk folder.',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          // DEMO: nothing on the phone can send an email, so the address is
          // already confirmed and there is nothing to wait for.
          if (kDemoMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4C2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFB8860B), width: 2),
              ),
              child: const Text(
                'DEMO: no email is sent. Your address already counts as '
                'confirmed, so just tap "Go to Login".',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (_sent != null) ...[
            const SizedBox(height: 16),
            _Box(
              text: _sent!,
              color: AppColors.primary,
              background: AppColors.primaryLight,
              icon: Icons.check_circle_outline,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _Box(
              text: _error!,
              color: AppColors.danger,
              background: const Color(0xFFFDECEE),
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: 28),
          BigButton(
            label: 'Go to Login',
            icon: Icons.login,
            onPressed: _busy ? null : _goToLogin,
          ),
          const SizedBox(height: 12),
          BigButton(
            label: _busy ? 'Sending...' : 'Resend email',
            icon: _busy ? Icons.hourglass_top : Icons.refresh,
            style: BigButtonStyle.tonal,
            onPressed: _busy ? null : _resend,
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData icon;

  const _Box({
    required this.text,
    required this.color,
    required this.background,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
