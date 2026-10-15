import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/auth/login_flow.dart';
import '../../app_state/session_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/email_field.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/password_field.dart';

/// Login: an email address and a password, on one screen.
///
/// The backend will not say whether a wrong address or a wrong password was
/// the problem, so this screen shows the one message it sends back,
/// "Incorrect email or password."
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  AuthException? _error;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    // After the session ended, signing up, or asking for a reset link.
    _email.text = session.lastEmail;
    _notice = session.takeNotice();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      // When it works, the router opens Home by itself.
      await context.read<LoginFlow>().logIn(
            rawEmail: _email.text,
            password: _password.text,
          );
    } on AuthException catch (e) {
      // An unconfirmed address moves to Check Your Inbox on its own.
      if (mounted && e.error != AuthError.emailNotVerified) {
        setState(() => _error = e);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = const AuthException(AuthError.unknown));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Leaves Login for the first screen of [flow] ("Forgot password?",
  /// "New here? Sign up").
  ///
  /// The address is what moves the user: the redirect leaves any screen in
  /// [Routes.signedOut] where it is, so setting the flow alone would keep
  /// Login on screen. The flow is still set, so the screens that ask for it
  /// ("Step 1 of 2") know which one they belong to.
  void _switchTo(AuthFlow flow) {
    context.read<SessionProvider>().startFlow(flow);
    context.go(Routes.entryFor(flow));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return OnboardingScaffold(
      title: 'Welcome Back',
      subtitle: 'Log in to your account',
      onBack: _busy ? null : () => context.go(Routes.welcome),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notice != null) ...[
            _NoticeBox(text: _notice!),
            const SizedBox(height: 20),
          ],
          const Text(
            'Enter the email address and password you signed up with.',
            style: OnboardingScaffold.cardBody,
          ),
          const SizedBox(height: 24),
          const Text('Email Address', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          EmailField(
            controller: _email,
            enabled: !_busy,
            hasError: error != null,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 18),
          const Text('Password', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          PasswordField(
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !_busy,
            hasError: error != null,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _logIn(),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error.message, style: OnboardingScaffold.errorText),
            ..._errorActions(error),
          ],
          const SizedBox(height: 28),
          BigButton(
            label: _busy ? 'Please wait...' : 'Log In',
            icon: _busy ? Icons.hourglass_top : Icons.login,
            onPressed: _busy ? null : _logIn,
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 16),
          _link('Forgot password?', () => _switchTo(AuthFlow.forgotPassword)),
          _link('New here? Sign up', () => _switchTo(AuthFlow.register)),
        ],
      ),
    );
  }

  /// A way out for the errors that mean "you are on the wrong screen".
  List<Widget> _errorActions(AuthException error) => switch (error.error) {
        AuthError.accountLocked => [
            const SizedBox(height: 12),
            BigButton(
              label: 'Forgot password?',
              style: BigButtonStyle.tonal,
              onPressed:
                  _busy ? null : () => _switchTo(AuthFlow.forgotPassword),
            ),
          ],
        AuthError.accountDeactivated || AuthError.unavailable => [
            const SizedBox(height: 12),
            BigButton(
              label: 'Contact OSCA',
              style: BigButtonStyle.tonal,
              onPressed: _busy ? null : () => context.push(Routes.contact),
            ),
          ],
        _ => const <Widget>[],
      };

  Widget _link(String label, VoidCallback onPressed) => Center(
        child: TextButton(
          onPressed: _busy ? null : onPressed,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(label, style: OnboardingScaffold.linkText),
        ),
      );
}

class _NoticeBox extends StatelessWidget {
  final String text;
  const _NoticeBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 26),
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
