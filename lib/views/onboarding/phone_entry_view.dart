import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/auth/login_flow.dart';
import '../../app_state/auth/mpin_reset_flow.dart';
import '../../app_state/auth/registration_flow.dart';
import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/phone_field.dart';

/// The mobile number screen of Create Account, Login and Forgot MPIN.
/// The backend sends a 4-digit code to the number, then the code screen
/// opens by itself.
class PhoneEntryView extends StatefulWidget {
  final AuthFlow flow;

  const PhoneEntryView({super.key, required this.flow});

  @override
  State<PhoneEntryView> createState() => _PhoneEntryViewState();
}

class _PhoneEntryViewState extends State<PhoneEntryView> {
  final TextEditingController _controller = TextEditingController();

  AuthException? _error;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    // After the session ended or the MPIN was reset: the last number.
    if (widget.flow != AuthFlow.register && session.lastPhone.isNotEmpty) {
      _controller.text = PhoneNumberFormatter.format(session.lastPhone);
    }
    if (widget.flow == AuthFlow.login) _notice = session.takeNotice();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title => switch (widget.flow) {
        AuthFlow.register => 'Create Your Account',
        AuthFlow.login => 'Welcome Back',
        AuthFlow.resetMpin => 'Forgot MPIN',
      };

  String get _subtitle =>
      widget.flow.stepLabel(OnboardingStage.phoneEntry) ??
      switch (widget.flow) {
        AuthFlow.login => 'Log in to your account',
        _ => 'Reset your MPIN',
      };

  String get _instructions => switch (widget.flow) {
        AuthFlow.register =>
          "We'll send a 4-digit verification code to your mobile number.",
        AuthFlow.login => 'Enter the mobile number you registered with. '
            "On a new phone, we'll send you a 4-digit code first.",
        AuthFlow.resetMpin => 'Enter your registered mobile number. '
            "We'll send you a 4-digit code so you can create a new MPIN.",
      };

  String get _buttonLabel =>
      widget.flow == AuthFlow.register ? 'Send OTP' : 'Continue';

  Future<void> _send() async {
    if (_busy) return;
    final phone = UserProvider.normalizePhone(_controller.text);
    if (!UserProvider.isValidPhone(phone)) {
      setState(() => _error = const AuthException(AuthError.invalidPhone));
      return;
    }

    FocusScope.of(context).unfocus();
    final send = switch (widget.flow) {
      AuthFlow.register => context.read<RegistrationFlow>().requestRegistrationOtp,
      AuthFlow.login => context.read<LoginFlow>().requestLoginOtp,
      AuthFlow.resetMpin => context.read<MpinResetFlow>().requestResetOtp,
    };
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      // When the code is sent, the router opens the code screen.
      await send(phone);
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

  void _switchTo(AuthFlow flow) =>
      context.read<SessionProvider>().startFlow(flow);

  void _back() {
    // Create Account: back to the name step. Others: back to Welcome.
    if (widget.flow == AuthFlow.register) {
      context.read<RegistrationFlow>().backToName();
    } else {
      context.go(Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return OnboardingScaffold(
      title: _title,
      subtitle: _subtitle,
      onBack: _busy ? null : _back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notice != null) ...[
            _NoticeBox(text: _notice!),
            const SizedBox(height: 20),
          ],
          Text(_instructions, style: OnboardingScaffold.cardBody),
          const SizedBox(height: 24),
          const Text('Mobile Number', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          PhoneField(
            controller: _controller,
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
            ..._errorActions(error),
          ],
          const SizedBox(height: 28),
          BigButton(
            label: _busy ? 'Please wait...' : _buttonLabel,
            icon: _busy ? Icons.hourglass_top : Icons.sms_outlined,
            onPressed: _busy ? null : _send,
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 16),
          ..._links(),
        ],
      ),
    );
  }

  /// A way out for the errors that mean "you are on the wrong screen".
  List<Widget> _errorActions(AuthException error) {
    final (label, route) = switch (error.error) {
      AuthError.alreadyRegistered => ('Log in instead', Routes.loginMobile),
      AuthError.accountNotFound when widget.flow != AuthFlow.register =>
        ('Create Account', Routes.registerName),
      AuthError.unavailable => ('Contact OSCA', Routes.contact),
      _ => ('', ''),
    };
    if (route.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      BigButton(
        label: label,
        style: BigButtonStyle.tonal,
        onPressed: _busy
            ? null
            : () => route == Routes.contact
                ? context.push(route)
                : _switchTo(route == Routes.loginMobile
                    ? AuthFlow.login
                    : AuthFlow.register),
      ),
    ];
  }

  List<Widget> _links() {
    Widget link(String label, VoidCallback onPressed) => Center(
          child: TextButton(
            onPressed: _busy ? null : onPressed,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(label, style: OnboardingScaffold.linkText),
          ),
        );

    return switch (widget.flow) {
      AuthFlow.register => [
          link('Already have an account? Login',
              () => _switchTo(AuthFlow.login)),
        ],
      AuthFlow.login => [
          link('Forgot MPIN', () => _switchTo(AuthFlow.resetMpin)),
          link('New here? Create Account', () => _switchTo(AuthFlow.register)),
        ],
      AuthFlow.resetMpin => [
          link('Back to Login', () => _switchTo(AuthFlow.login)),
        ],
    };
  }
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
