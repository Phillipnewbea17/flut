import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';

/// "Enter your 4-digit code" - Step 1 of 4.
/// A hidden number field collects the digits (so the phone can paste the code
/// from the text message), and four big boxes show them.
class OtpVerifyView extends StatefulWidget {
  const OtpVerifyView({super.key});

  @override
  State<OtpVerifyView> createState() => _OtpVerifyViewState();
}

class _OtpVerifyViewState extends State<OtpVerifyView> {
  static const int _codeLength = 4;
  static const int _resendSeconds = 60; // the server allows one code a minute

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _autoFilled = false;
  bool _busy = false;
  String? _error;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // If the phone number is missing, go back to the login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<UserProvider>().pendingPhone.isEmpty) {
        context.read<SessionProvider>().advanceTo(OnboardingStage.phoneEntry);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _secondsLeft = 0;
          timer.cancel();
        }
      });
    });
  }

  void _showKeyboard() {
    FocusScope.of(context).requestFocus(_focusNode);
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _onChanged(String value) {
    setState(() {
      // Typing adds one digit at a time. A code that appears all at once
      // came from the text message.
      _autoFilled = _lastLength == 0 && value.length >= _codeLength;
      _lastLength = value.length;
      _error = null;
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _codeController.text;
    if (code.length != _codeLength) {
      setState(() => _error = 'Please enter all 4 numbers.');
      return;
    }

    final auth = context.read<AuthService>();
    final user = context.read<UserProvider>();
    final session = context.read<SessionProvider>();

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await auth.verifyOtp(phone: user.pendingPhone, code: code);
      if (!ok) {
        if (mounted) {
          _codeController.clear();
          setState(() {
            _lastLength = 0;
            _autoFilled = false;
            _error = 'That code is not right. Please try again.';
          });
          _showKeyboard();
        }
        return;
      }
      await user.confirmPhone();
      await session.advanceTo(OnboardingStage.mpinSetup);
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

  Future<void> _resend() async {
    if (_busy) return;
    final auth = context.read<AuthService>();
    final user = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await auth.sendOtp(user.pendingPhone);
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _lastLength = 0;
        _autoFilled = false;
        _error = null;
        _startTimer();
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'We sent you a new code.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
      _showKeyboard();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'We could not send a new code. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeNumber() {
    context.read<SessionProvider>().advanceTo(OnboardingStage.phoneEntry);
  }

  String get _timerText {
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.read<UserProvider>().profile?.displayPhone;
    final pending = context.read<UserProvider>().pendingPhone;
    final shownPhone = _formatPending(pending, fallback: phone);

    return OnboardingScaffold(
      title: 'Verify your phone',
      subtitle: OnboardingStage.otpVerify.stepLabel!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your 4-digit code',
            style: OnboardingScaffold.cardTitle,
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: OnboardingScaffold.cardBody,
              children: [
                const TextSpan(text: 'We sent a text message to '),
                TextSpan(
                  text: shownPhone,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Hidden field that really receives the digits.
          AutofillGroup(
            child: SizedBox(
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _codeController,
                  focusNode: _focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableInteractiveSelection: false,
                  showCursor: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_codeLength),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onChanged,
                  onSubmitted: (_) => _verify(),
                ),
              ),
            ),
          ),

          // The four boxes people see and tap.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _codeController,
            builder: (context, value, _) {
              final digits = value.text;
              return Semantics(
                label: 'Code entry. ${digits.length} of $_codeLength numbers '
                    'entered. Double tap to type.',
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showKeyboard,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_codeLength, (index) {
                      final hasDigit = index < digits.length;
                      final isCurrent = index == digits.length &&
                          index < _codeLength &&
                          _error == null;
                      return _CodeBox(
                        digit: hasDigit ? digits[index] : '',
                        highlighted: isCurrent,
                        hasError: _error != null,
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // One line under the boxes: error, "found automatically", or a hint.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: _buildStatusLine(),
          ),
          const SizedBox(height: 20),

          BigButton(
            label: 'Verify & continue',
            icon: Icons.verified_user_outlined,
            color: AppColors.primaryBright,
            onPressed: _busy ? null : _verify,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _busy ? null : _changeNumber,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Change number',
                  style: OnboardingScaffold.linkText,
                ),
              ),
              if (_secondsLeft > 0)
                Text(
                  'Resend in $_timerText',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                TextButton(
                  onPressed: _busy ? null : _resend,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Resend code',
                    style: OnboardingScaffold.linkText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine() {
    if (_error != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline,
              color: AppColors.danger,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: OnboardingScaffold.errorText),
          ),
        ],
      );
    }
    if (_autoFilled) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.circle, color: AppColors.success, size: 16),
          SizedBox(width: 10),
          Text(
            'Code found automatically',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      );
    }
    return const Text(
      'Type the 4 numbers from the text message.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
    );
  }

  /// "9551402068" -> "+63 955 140 2068"
  String _formatPending(String digits, {String? fallback}) {
    if (digits.length == 10) {
      return '+63 ${digits.substring(0, 3)} ${digits.substring(3, 6)} '
          '${digits.substring(6)}';
    }
    return fallback ?? '+63 $digits';
  }
}

class _CodeBox extends StatelessWidget {
  final String digit;
  final bool highlighted;
  final bool hasError;

  const _CodeBox({
    required this.digit,
    required this.highlighted,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError
        ? AppColors.danger
        : highlighted
            ? AppColors.primaryBright
            : AppColors.primary;

    return Container(
      width: 64,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: highlighted ? 3.5 : 2),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
