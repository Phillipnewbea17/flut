import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/auth/auth_steps.dart';
import '../../app_state/auth/login_flow.dart';
import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../utils/mpin_validator.dart';
import '../../widgets/big_button.dart';
import '../../widgets/mpin_keypad.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/pin_dots.dart';

/// How the MPIN screen is used.
/// - create:  Create Account / Forgot MPIN, "Create your MPIN"
/// - confirm: Create Account / Forgot MPIN, "Confirm your MPIN"
/// - enter:   Login, "Enter your MPIN" (the existing one)
/// - change:  Account > Change MPIN (current, new, then again)
///
/// Every MPIN is checked and saved by Laravel. The typed numbers live only
/// in memory until they are sent; nothing is saved on the phone.
enum MpinMode { create, confirm, enter, change }

enum _ChangeStep { current, create, confirm }

class MpinView extends StatefulWidget {
  final MpinMode mode;

  /// The sign-in flow of the screen. Not used by [MpinMode.change].
  final AuthFlow? flow;

  const MpinView({super.key, required this.mode, this.flow});

  @override
  State<MpinView> createState() => _MpinViewState();
}

class _MpinViewState extends State<MpinView> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  // Account > Change MPIN only.
  _ChangeStep _changeStep = _ChangeStep.current;
  String _currentPin = '';
  String _newPin = '';

  MpinMode get _mode => widget.mode;
  bool get _isReset => widget.flow == AuthFlow.resetMpin;

  NewMpinStep get _newMpin => newMpinStepOf(context, widget.flow!);

  // ---------------------------------------------------------------------------
  // Texts
  // ---------------------------------------------------------------------------

  String get _title => switch (_mode) {
        MpinMode.create => _isReset ? 'Create a New MPIN' : 'Create Your MPIN',
        MpinMode.confirm => _isReset ? 'Confirm New MPIN' : 'Confirm Your MPIN',
        MpinMode.enter => 'Enter Your MPIN',
        MpinMode.change => switch (_changeStep) {
            _ChangeStep.current => 'Change Your MPIN',
            _ChangeStep.create => 'Choose a New MPIN',
            _ChangeStep.confirm => 'Confirm New MPIN',
          },
      };

  String _subtitle(BuildContext context) {
    switch (_mode) {
      case MpinMode.enter:
        final name = context.read<UserProvider>().firstName;
        return name.isEmpty ? 'Welcome back' : 'Welcome back, $name';
      case MpinMode.change:
        return 'Step ${_changeStep.index + 1} of 3';
      case MpinMode.create:
      case MpinMode.confirm:
        return widget.flow?.stepLabel(OnboardingStage.mpinSetup) ??
            'Forgot MPIN';
    }
  }

  String get _body => switch (_mode) {
        MpinMode.create => 'Create a 4-digit MPIN that you will use to access '
            'your account. Do not share it with anyone.',
        MpinMode.confirm => 'Enter your 4-digit MPIN again.',
        MpinMode.enter => 'Enter your 4-digit MPIN to continue.',
        MpinMode.change => switch (_changeStep) {
            _ChangeStep.current => 'Enter your current 4-digit MPIN.',
            _ChangeStep.create => 'Create a new 4-digit MPIN.',
            _ChangeStep.confirm => 'Enter your new 4-digit MPIN again.',
          },
      };

  String get _buttonLabel => switch (_mode) {
        MpinMode.enter => 'Unlock',
        MpinMode.confirm => _isReset ? 'Save new MPIN' : 'Create Account',
        MpinMode.change when _changeStep == _ChangeStep.confirm =>
          'Change MPIN',
        _ => 'Continue',
      };

  // ---------------------------------------------------------------------------
  // Typing
  // ---------------------------------------------------------------------------

  void _onDigit(String digit) {
    if (_busy) return;
    setState(() {
      if (_error != null && _pin.length == MpinValidator.length) _pin = '';
      _error = null;
      if (_pin.length < MpinValidator.length) _pin += digit;
    });
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _pin = '';
    });
  }

  // ---------------------------------------------------------------------------
  // Checking
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_busy || !MpinValidator.isComplete(_pin)) return;
    final pin = _pin;
    setState(() => _busy = true);
    try {
      switch (_mode) {
        case MpinMode.create:
          final rule = _newMpin.validateNewMpin(pin);
          if (rule != null) {
            _fail(rule);
          } else {
            // The router opens Confirm MPIN.
            await _newMpin.createMpin(pin);
          }
        case MpinMode.confirm:
          // Create Account: Laravel creates the account, then Home.
          // Forgot MPIN: Laravel changes the MPIN, then Login.
          await _newMpin.confirmMpin(pin);
        case MpinMode.enter:
          // Laravel checks the existing MPIN; then Home.
          await context.read<LoginFlow>().verifyMpin(pin);
        case MpinMode.change:
          await _submitChange(pin);
      }
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(const AuthException(AuthError.unknown).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitChange(String pin) async {
    switch (_changeStep) {
      case _ChangeStep.current:
        _currentPin = pin;
        setState(() {
          _changeStep = _ChangeStep.create;
          _pin = '';
        });
      case _ChangeStep.create:
        final rule = MpinValidator.validate(pin);
        if (rule != null) return _fail(rule);
        _newPin = pin;
        setState(() {
          _changeStep = _ChangeStep.confirm;
          _pin = '';
        });
      case _ChangeStep.confirm:
        if (!MpinValidator.matches(_newPin, pin)) {
          setState(() => _changeStep = _ChangeStep.create);
          return _fail(const AuthException(AuthError.mpinMismatch).message);
        }
        final messenger = ScaffoldMessenger.of(context);
        final error = await context.read<SessionProvider>().changeMpin(
              currentMpin: _currentPin,
              newMpin: pin,
            );
        _currentPin = '';
        _newPin = '';
        if (!mounted) return;
        if (error != null) {
          setState(() => _changeStep = _ChangeStep.current);
          return _fail(error);
        }
        messenger.showSnackBar(const SnackBar(
          content: Text('Your MPIN was changed.', style: TextStyle(fontSize: 18)),
        ));
        if (context.canPop()) context.pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Other buttons
  // ---------------------------------------------------------------------------

  void _goBack() {
    switch (_mode) {
      case MpinMode.change:
        if (context.canPop()) context.pop();
      case MpinMode.confirm:
        _newMpin.backToCreateMpin();
      case MpinMode.create:
        _newMpin.changeNumber();
      case MpinMode.enter:
        context.read<LoginFlow>().changeNumber();
    }
  }

  Widget _buildLink() {
    Widget link(String label, VoidCallback onPressed) => TextButton(
          onPressed: _busy ? null : onPressed,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(label, style: OnboardingScaffold.linkText),
        );

    return switch (_mode) {
      MpinMode.enter => link('Forgot MPIN',
          () => context.read<SessionProvider>().startFlow(AuthFlow.resetMpin)),
      MpinMode.confirm => link('Start over', _newMpin.backToCreateMpin),
      _ => const SizedBox(height: 48),
    };
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return OnboardingScaffold(
      title: _title,
      subtitle: _subtitle(context),
      onBack: _busy ? null : _goBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_body, style: OnboardingScaffold.cardBody),
          const SizedBox(height: 24),
          PinDots(
            length: MpinValidator.length,
            filled: _pin.length,
            error: error != null,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: error == null
                  ? const SizedBox.shrink()
                  : Text(
                      error,
                      textAlign: TextAlign.center,
                      style: OnboardingScaffold.errorText,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          MpinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
          const SizedBox(height: 16),
          BigButton(
            label: _busy ? 'Please wait...' : _buttonLabel,
            icon: _mode == MpinMode.enter ? Icons.lock_open : Icons.arrow_forward,
            onPressed:
                _busy || !MpinValidator.isComplete(_pin) ? null : _submit,
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 8),
          Center(child: _buildLink()),
        ],
      ),
    );
  }
}
