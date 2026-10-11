import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import 'login_flow.dart';
import 'mpin_reset_flow.dart';
import 'registration_flow.dart';

/// What the shared code screen needs from a flow.
abstract class OtpStep {
  AuthFlow get kind;
  String get phone;
  OtpTicket get ticket;
  DateTime? get codeSentAt;
  bool get codeExpired;
  bool get codeLocked;
  Future<void> resendOtp();
  Future<void> verifyOtp(String code);

  /// "Change number": back to the mobile number screen.
  Future<void> changeNumber();
}

/// What the shared create / confirm MPIN screens need from a flow
/// (Create Account and Forgot MPIN).
abstract class NewMpinStep {
  AuthFlow get kind;

  /// Rule check for a new MPIN (not easy to guess, not the code).
  String? validateNewMpin(String pin);

  /// Keeps [pin] in memory and opens Confirm MPIN.
  Future<void> createMpin(String pin);

  /// Compares with the first MPIN, then sends it to the backend. Throws
  /// AuthError.mpinMismatch (and goes back to Create MPIN) when different.
  Future<void> confirmMpin(String pin);

  /// "Start over" from Confirm MPIN.
  Future<void> backToCreateMpin();

  /// Back to the mobile number screen.
  Future<void> changeNumber();
}

/// The flow object behind the screens of [kind].
OtpStep otpStepOf(BuildContext context, AuthFlow kind) => switch (kind) {
      AuthFlow.register => context.read<RegistrationFlow>(),
      AuthFlow.login => context.read<LoginFlow>(),
      AuthFlow.resetMpin => context.read<MpinResetFlow>(),
    };

NewMpinStep newMpinStepOf(BuildContext context, AuthFlow kind) =>
    switch (kind) {
      AuthFlow.register => context.read<RegistrationFlow>(),
      AuthFlow.resetMpin => context.read<MpinResetFlow>(),
      AuthFlow.login =>
        throw ArgumentError('Login never creates a new MPIN.'),
    };
