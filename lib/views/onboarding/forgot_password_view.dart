import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/auth/password_reset_flow.dart';
import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/email_field.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Forgot password: ask for the address, and the backend emails a
/// single-use link. The new password is typed on the page that link opens,
/// so this screen's job ends at "we sent it".
///
/// The message after sending is the same whether or not the address has an
/// account, so nobody can use this screen to find out who has registered.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final TextEditingController _email = TextEditingController();

  AuthException? _error;
  bool _busy = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _email.text = context.read<SessionProvider>().lastEmail;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final email = UserProvider.normalizeEmail(_email.text);
    if (!UserProvider.isValidEmail(email)) {
      setState(() => _error = const AuthException(AuthError.invalidEmail));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<PasswordResetFlow>().sendLink(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) {
        setState(() => _error = const AuthException(AuthError.unknown));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Back to Login". The flow puts the session back on Login, and the
  /// address is what moves the user: the redirect leaves any screen in
  /// [Routes.signedOut] where it is, this one included.
  Future<void> _backToLogin() async {
    await context.read<PasswordResetFlow>().backToLogin();
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.read<PasswordResetFlow>();

    return OnboardingScaffold(
      title: 'Forgot Password',
      subtitle: _sent ? 'Check your inbox' : 'We will email you a link',
      onBack: _busy ? null : _backToLogin,
      child: _sent ? _sentBody(flow) : _formBody(),
    );
  }

  Widget _formBody() {
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the email address you signed up with. We will send you a '
          'link to choose a new password.',
          style: OnboardingScaffold.cardBody,
        ),
        const SizedBox(height: 24),
        const Text('Email Address', style: OnboardingScaffold.fieldLabel),
        const SizedBox(height: 10),
        EmailField(
          controller: _email,
          enabled: !_busy,
          hasError: error != null,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _send(),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error.message, style: OnboardingScaffold.errorText),
        ],
        const SizedBox(height: 28),
        BigButton(
          label: _busy ? 'Please wait...' : 'Send the link',
          icon: _busy ? Icons.hourglass_top : Icons.mail_outline,
          onPressed: _busy ? null : _send,
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _backToLogin,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Back to Login',
                style: OnboardingScaffold.linkText),
          ),
        ),
      ],
    );
  }

  Widget _sentBody(PasswordResetFlow flow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Icon(Icons.mark_email_read_outlined,
              size: 76, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        Text.rich(
          TextSpan(
            style: OnboardingScaffold.cardBody,
            children: [
              const TextSpan(text: 'If '),
              TextSpan(
                text: flow.email,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(
                text: ' has an account, a link is on its way. Open the email '
                    'and tap "Set a new password", then come back here and '
                    'log in.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'The link works for 30 minutes and can be used once. If it is not '
          'in your inbox, please look in your Spam or Junk folder.',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 28),
        BigButton(
          label: 'Go to Login',
          icon: Icons.login,
          onPressed: _busy ? null : _backToLogin,
        ),
        const SizedBox(height: 12),
        BigButton(
          label: 'Send it again',
          icon: Icons.refresh,
          style: BigButtonStyle.tonal,
          onPressed: _busy ? null : () => setState(() => _sent = false),
        ),
      ],
    );
  }
}
