import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../utils/mpin_validator.dart';
import '../../widgets/mpin_keypad.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/pin_dots.dart';

/// How the MPIN screen is being used.
/// - create: first-time setup (type a new MPIN, then type it again)
/// - enter:  opening the app (type your MPIN)
/// - change: from Account (type the old MPIN, then a new one, then again)
enum MpinMode { create, enter, change }

enum _Step { current, create, confirm, enter }

class MpinView extends StatefulWidget {
  final MpinMode mode;

  const MpinView({super.key, required this.mode});

  @override
  State<MpinView> createState() => _MpinViewState();
}

class _MpinViewState extends State<MpinView> {
  late _Step _step;
  String _pin = '';
  String _firstPin = '';
  String? _error;
  bool _busy = false;

  bool get _isChange => widget.mode == MpinMode.change;

  @override
  void initState() {
    super.initState();
    _step = switch (widget.mode) {
      MpinMode.create => _Step.create,
      MpinMode.enter => _Step.enter,
      MpinMode.change => _Step.current,
    };
  }

  // ---------------------------------------------------------------------------
  // Texts
  // ---------------------------------------------------------------------------

  String get _headerTitle {
    switch (_step) {
      case _Step.enter:
        return 'Enter your MPIN';
      case _Step.current:
        return 'Change your MPIN';
      case _Step.create:
        return _isChange ? 'Choose a new MPIN' : 'Create your MPIN';
      case _Step.confirm:
        return _isChange ? 'Confirm new MPIN' : 'Confirm your MPIN';
    }
  }

  String _headerSubtitle(BuildContext context) {
    if (_step == _Step.enter) {
      final name = context.read<UserProvider>().firstName;
      return name.isEmpty ? 'Welcome back' : 'Welcome back, $name';
    }
    if (_isChange) {
      final number = switch (_step) {
        _Step.current => 1,
        _Step.create => 2,
        _ => 3,
      };
      return 'Step $number of 3';
    }
    return OnboardingStage.mpinSetup.stepLabel!;
  }

  String get _cardTitle {
    switch (_step) {
      case _Step.enter:
        return 'Type your 4-number MPIN';
      case _Step.current:
        return 'Type your current MPIN';
      case _Step.create:
        return 'Choose 4 numbers';
      case _Step.confirm:
        return 'Type the same 4 numbers again';
    }
  }

  String get _cardBody {
    switch (_step) {
      case _Step.enter:
        return 'This keeps your information safe.';
      case _Step.current:
        return 'We need to be sure it is you.';
      case _Step.create:
        return 'You will use this MPIN every time you open the app. '
            'Do not share it with anyone.';
      case _Step.confirm:
        return 'This makes sure you did not make a mistake.';
    }
  }

  // ---------------------------------------------------------------------------
  // Typing
  // ---------------------------------------------------------------------------

  void _onDigit(String digit) {
    if (_busy) return;
    setState(() {
      if (_error != null) {
        _error = null;
        _pin = '';
      }
      if (_pin.length < MpinValidator.length) _pin += digit;
    });
    if (_pin.length == MpinValidator.length) {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _submit();
      });
    }
  }

  void _onBackspace() {
    if (_busy) return;
    setState(() {
      if (_error != null) {
        _error = null;
        _pin = '';
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _go(_Step step) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _pin = '';
      _error = null;
    });
  }

  void _fail(String message, {_Step? goTo}) {
    if (!mounted) return;
    setState(() {
      _error = message;
      if (goTo != null) {
        _step = goTo;
        _pin = '';
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Checking
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_busy || _pin.length != MpinValidator.length) return;
    final pin = _pin;
    setState(() => _busy = true);
    try {
      switch (_step) {
        case _Step.enter:
          await _submitEnter(pin);
        case _Step.current:
          await _submitCurrent(pin);
        case _Step.create:
          _submitCreate(pin);
        case _Step.confirm:
          await _submitConfirm(pin);
      }
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEnter(String pin) async {
    final session = context.read<SessionProvider>();
    final ok = await session.unlockWithMpin(pin);
    // When it is right, the router moves to Home by itself.
    if (!ok) _fail('That MPIN is not right. Please try again.');
  }

  Future<void> _submitCurrent(String pin) async {
    final session = context.read<SessionProvider>();
    final ok = await session.checkMpin(pin);
    if (!ok) {
      _fail('That MPIN is not right. Please try again.');
    } else {
      _go(_Step.create);
    }
  }

  void _submitCreate(String pin) {
    final error = MpinValidator.validate(pin);
    if (error != null) {
      _fail(error);
    } else {
      _firstPin = pin;
      _go(_Step.confirm);
    }
  }

  Future<void> _submitConfirm(String pin) async {
    final session = context.read<SessionProvider>();

    if (!MpinValidator.matches(_firstPin, pin)) {
      _firstPin = '';
      _fail('The numbers do not match. Let us start again.',
          goTo: _Step.create);
      return;
    }

    if (_isChange) {
      final messenger = ScaffoldMessenger.of(context);
      final error = await session.replaceMpin(pin);
      if (!mounted) return;
      if (error != null) {
        _fail(error, goTo: _Step.create);
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your MPIN was changed.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
      if (context.canPop()) context.pop();
    } else {
      final error = await session.createMpin(pin);
      // When it is saved, the router moves to the next step by itself.
      if (error != null) _fail(error, goTo: _Step.create);
    }
  }

  // ---------------------------------------------------------------------------
  // Other buttons
  // ---------------------------------------------------------------------------

  void _goBack() {
    if (context.canPop()) context.pop();
  }

  Future<void> _forgot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Forgot your MPIN?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You will log in again with your phone number. The information '
          'saved on this phone will be removed.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Log in again',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = context.read<UserProvider>();
    final session = context.read<SessionProvider>();
    user.reset();
    await session.logout();
  }

  Widget _buildLink() {
    if (_step == _Step.enter) {
      return TextButton(
        onPressed: _busy ? null : _forgot,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: const Text('Forgot MPIN?', style: OnboardingScaffold.linkText),
      );
    }
    if (_step == _Step.confirm) {
      return TextButton(
        onPressed: _busy ? null : () => _go(_Step.create),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: const Text('Start over', style: OnboardingScaffold.linkText),
      );
    }
    return const SizedBox(height: 48);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: _headerTitle,
      subtitle: _headerSubtitle(context),
      onBack: _isChange ? _goBack : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_cardTitle, style: OnboardingScaffold.cardTitle),
          const SizedBox(height: 8),
          Text(_cardBody, style: OnboardingScaffold.cardBody),
          const SizedBox(height: 28),
          PinDots(
            length: MpinValidator.length,
            filled: _pin.length,
            error: _error != null,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: _error == null
                  ? const SizedBox.shrink()
                  : Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: OnboardingScaffold.errorText,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          MpinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
          const SizedBox(height: 12),
          Center(child: _buildLink()),
        ],
      ),
    );
  }
}
