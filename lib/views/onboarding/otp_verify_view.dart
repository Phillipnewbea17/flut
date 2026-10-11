import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state/auth/auth_steps.dart';
import '../../demo/demo_mode.dart'; // DEMO
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/mpin_validator.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';

/// "Enter the 4-digit code". Used by Create Account, Login and Forgot MPIN.
/// A hidden number field collects the digits (so the phone can fill in or
/// paste the code from the text message), and four big boxes show them.
/// The backend checks the code; the screen only counts down its time.
class OtpVerifyView extends StatefulWidget {
  /// Create Account, Login or Forgot MPIN: each has its own code step.
  final AuthFlow flow;

  const OtpVerifyView({super.key, required this.flow});

  @override
  State<OtpVerifyView> createState() => _OtpVerifyViewState();
}

class _OtpVerifyViewState extends State<OtpVerifyView> {
  static const int _codeLength = OtpValidator.length;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _timer;
  bool _autoFilled = false;
  bool _busy = false;
  AuthException? _error;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  OtpStep get _step => otpStepOf(context, widget.flow);

  Duration _left(Duration total) {
    final sent = _step.codeSentAt;
    if (sent == null) return Duration.zero;
    final left = sent.add(total).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Duration get _expiresIn => _left(_step.ticket.expiresIn);
  Duration get _resendIn => _left(_step.ticket.resendIn);

  /// No point checking this code any more: ask for a new one.
  bool get _needsNewCode =>
      _step.codeLocked ||
      _step.codeExpired ||
      _error?.error == AuthError.tooManyAttempts ||
      _error?.error == AuthError.codeExpired;

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
      if (!_needsNewCode) _error = null;
    });
    // All 4 numbers are in: put the keyboard away so the button shows.
    if (value.length == _codeLength) _focusNode.unfocus();
  }

  /// Long-press on the boxes: paste a code copied from the text message.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (!mounted) return;
    if (digits.length != _codeLength) {
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No 4-digit code was found to paste.',
            style: TextStyle(fontSize: 18)),
      ));
      return;
    }
    _codeController.text = digits;
    _lastLength = 0;
    _onChanged(digits);
  }

  void _clearCode() {
    _codeController.clear();
    _lastLength = 0;
    _autoFilled = false;
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _codeController.text;
    if (OtpValidator.validate(code) != null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // When the code is right, the router opens the MPIN screen.
      await _step.verifyOtp(code);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _clearCode();
      });
      if (e.error == AuthError.wrongCode) _showKeyboard();
    } catch (_) {
      if (mounted) {
        setState(() => _error = const AuthException(AuthError.unknown));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _step.resendOtp();
      if (!mounted) return;
      setState(() {
        _clearCode();
        _error = null;
      });
      messenger.showSnackBar(const SnackBar(
        content: Text('We sent you a new code.', style: TextStyle(fontSize: 18)),
      ));
      _showKeyboard();
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

  void _changeNumber() => _step.changeNumber();

  static String _clock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// "9551402068" -> "+63 9XX XXX 2068". Only the last 4 numbers are shown.
  static String maskPhone(String digits) {
    if (digits.length != 10) return '+63 your mobile number';
    return '+63 ${digits[0]}XX XXX ${digits.substring(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final flow = widget.flow;
    final masked = maskPhone(step.phone);
    final expiresIn = _expiresIn;
    final resendIn = _resendIn;
    final needsNewCode = _needsNewCode;
    final shownError = _error ??
        (step.codeLocked
            ? const AuthException(AuthError.tooManyAttempts)
            : step.codeExpired
                ? const AuthException(AuthError.codeExpired)
                : null);

    return OnboardingScaffold(
      title: flow == AuthFlow.login
          ? 'Verify Your Login'
          : 'Verify Your Mobile Number',
      subtitle: flow.stepLabel(OnboardingStage.otpVerify) ??
          (flow == AuthFlow.login ? 'Log in' : 'Forgot MPIN'),
      onBack: _busy ? null : _changeNumber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter the 4-digit code', style: OnboardingScaffold.cardTitle),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: OnboardingScaffold.cardBody,
              children: [
                TextSpan(
                  text: flow == AuthFlow.login
                      ? 'We sent a code to your registered mobile number, '
                      : 'We sent a verification code to ',
                ),
                TextSpan(
                  text: masked,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          // DEMO: the demo code, since no text message is sent.
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
                'DEMO: no text message is sent. Your code is $kDemoOtp.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
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
                  enabled: !needsNewCode,
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
                    disabledBorder: InputBorder.none,
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
                  onTap: needsNewCode ? null : _showKeyboard,
                  onLongPress: needsNewCode ? null : _paste,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_codeLength, (index) {
                      final hasDigit = index < digits.length;
                      final isCurrent = index == digits.length &&
                          index < _codeLength &&
                          shownError == null;
                      // Up to 64x80, smaller on narrow phones or big text.
                      return Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 64),
                            child: AspectRatio(
                              aspectRatio: 64 / 80,
                              child: _CodeBox(
                                digit: hasDigit ? digits[index] : '',
                                highlighted: isCurrent,
                                hasError: shownError != null,
                              ),
                            ),
                          ),
                        ),
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
            child: _buildStatusLine(shownError),
          ),
          const SizedBox(height: 10),
          if (!needsNewCode)
            Center(
              child: Text(
                'Code expires in ${_clock(expiresIn)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 16),

          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _codeController,
            builder: (context, value, _) => BigButton(
              label: _busy ? 'Checking...' : 'Verify',
              icon: Icons.verified_user_outlined,
              color: AppColors.primaryBright,
              onPressed: _busy ||
                      needsNewCode ||
                      value.text.length != _codeLength
                  ? null
                  : _verify,
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 12),
          // Wraps "Resend" onto its own line when big text makes it too wide.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              if (resendIn > Duration.zero)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text(
                    'Resend OTP in ${_clock(resendIn)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
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
                    'Resend OTP',
                    style: OnboardingScaffold.linkText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine(AuthException? error) {
    if (error != null) {
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
            child: Text(error.message, style: OnboardingScaffold.errorText),
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
          Flexible(
            child: Text(
              'Code found automatically',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: highlighted ? 3.5 : 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
