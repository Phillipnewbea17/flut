import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/phone_field.dart';

/// "Log in with your phone number" - the first real screen.
class PhoneEntryView extends StatefulWidget {
  const PhoneEntryView({super.key});

  @override
  State<PhoneEntryView> createState() => _PhoneEntryViewState();
}

class _PhoneEntryViewState extends State<PhoneEntryView> {
  final TextEditingController _controller = TextEditingController();

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Coming back from "Change number": show the number typed before.
    final previous = context.read<UserProvider>().pendingPhone;
    if (previous.isNotEmpty) {
      _controller.text = PhoneNumberFormatter.format(previous);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = UserProvider.normalizePhone(_controller.text);
    if (!UserProvider.isValidPhone(phone)) {
      setState(() {
        _error = 'Please enter your 10-digit mobile number. It starts with 9.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthService>();
    final user = context.read<UserProvider>();
    final session = context.read<SessionProvider>();

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.sendOtp(phone);
      user.setPendingPhone(phone);
      await session.advanceTo(OnboardingStage.otpVerify);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please check your internet and '
              'try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Welcome',
      subtitle: DateFormat('EEE, MMM d, y').format(DateTime.now()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log in with your phone number',
            style: OnboardingScaffold.cardTitle,
          ),
          const SizedBox(height: 10),
          const Text(
            'We will text you a 4-digit code to confirm it is you.',
            style: OnboardingScaffold.cardBody,
          ),
          const SizedBox(height: 28),
          const Text('Your mobile number', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          PhoneField(
            controller: _controller,
            enabled: !_busy,
            hasError: _error != null,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _send(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: OnboardingScaffold.errorText),
          ],
          const SizedBox(height: 32),
          BigButton(
            label: 'Send one-time PIN (OTP)',
            icon: Icons.mail_outline,
            onPressed: _busy ? null : _send,
          ),
        ],
      ),
    );
  }
}
