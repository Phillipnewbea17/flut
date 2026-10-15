import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state/auth/registration_flow.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../utils/password_validator.dart';
import '../../widgets/big_button.dart';
import '../../widgets/email_field.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/password_field.dart';

/// Sign up, step 2: the email address and the password, with the password
/// typed twice. Creating the account sends a confirmation email, and the
/// Check Your Inbox screen opens.
class RegisterCredentialsView extends StatefulWidget {
  const RegisterCredentialsView({super.key});

  @override
  State<RegisterCredentialsView> createState() =>
      _RegisterCredentialsViewState();
}

class _RegisterCredentialsViewState extends State<RegisterCredentialsView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  /// Which box the message belongs under, so the senior knows where to look.
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_emailError == null &&
        _passwordError == null &&
        _confirmError == null &&
        _formError == null) {
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _formError = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;

    // Checked here first so the message can sit under the box it is about.
    final email = UserProvider.normalizeEmail(_email.text);
    final emailError = UserProvider.isValidEmail(email)
        ? null
        : 'Please enter your email address, like rosela@gmail.com.';
    final passwordError = PasswordValidator.validate(
      _password.text,
      email: email,
    );
    final confirmError =
        PasswordValidator.matches(_password.text, _confirm.text)
            ? null
            : 'The passwords do not match. Please type them again.';

    if (emailError != null || passwordError != null || confirmError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _confirmError = passwordError == null ? confirmError : null;
        _formError = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _formError = null;
    });

    try {
      // When it works, the router opens Check Your Inbox.
      await context.read<RegistrationFlow>().createAccount(
            rawEmail: _email.text,
            password: _password.text,
            confirmation: _confirm.text,
          );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.error) {
          case AuthError.alreadyRegistered:
          case AuthError.invalidEmail:
            _emailError = e.message;
          case AuthError.invalidPassword:
          case AuthError.weakPassword:
            _passwordError = e.message;
          case AuthError.passwordMismatch:
            _confirmError = e.message;
          default:
            _formError = e.message;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _formError = const AuthException(AuthError.unknown).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.read<RegistrationFlow>();

    return OnboardingScaffold(
      title: 'Create Your Account',
      subtitle: AuthFlow.register.stepLabel(OnboardingStage.credentials) ??
          'Your login details',
      onBack: _busy ? null : flow.backToName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose the email address and password you will log in with. '
            "We'll email you a link to confirm the address.",
            style: OnboardingScaffold.cardBody,
          ),
          const SizedBox(height: 24),
          const Text('Email Address', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          EmailField(
            controller: _email,
            enabled: !_busy,
            hasError: _emailError != null,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearErrors(),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          ..._message(_emailError),
          const SizedBox(height: 18),
          const Text('Password', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          PasswordField(
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !_busy,
            isNew: true,
            hintText: 'At least ${PasswordValidator.minLength} characters',
            hasError: _passwordError != null,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearErrors(),
            onSubmitted: (_) => _confirmFocus.requestFocus(),
          ),
          ..._message(_passwordError),
          if (_passwordError == null) ...[
            const SizedBox(height: 8),
            Text(
              'Use at least ${PasswordValidator.minLength} characters. A few '
              'words together are easy to remember and hard to guess.',
              style: const TextStyle(fontSize: 16, height: 1.35),
            ),
          ],
          const SizedBox(height: 18),
          const Text('Confirm Password',
              style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          PasswordField(
            controller: _confirm,
            focusNode: _confirmFocus,
            enabled: !_busy,
            isNew: true,
            hintText: 'Type your password again',
            hasError: _confirmError != null,
            onChanged: (_) => _clearErrors(),
            onSubmitted: (_) => _submit(),
          ),
          ..._message(_confirmError),
          ..._message(_formError),
          const SizedBox(height: 28),
          BigButton(
            label: _busy ? 'Please wait...' : 'Create Account',
            icon: _busy ? Icons.hourglass_top : Icons.person_add_alt,
            onPressed: _busy ? null : _submit,
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  List<Widget> _message(String? text) => text == null
      ? const []
      : [
          const SizedBox(height: 10),
          Text(text, style: OnboardingScaffold.errorText),
        ];
}

