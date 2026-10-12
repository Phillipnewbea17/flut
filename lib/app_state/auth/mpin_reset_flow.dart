import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../utils/mpin_validator.dart';
import '../session_provider.dart';
import 'auth_steps.dart';
import 'otp_challenge.dart';

/// Forgot MPIN (existing account):
///
///   code -> new MPIN -> confirm -> back to Login (not signed in)
class MpinResetFlow implements OtpStep, NewMpinStep {
  MpinResetFlow({required AuthService auth, required SessionProvider session})
      : _auth = auth,
        _session = session,
        _otp = OtpChallenge(auth, AuthFlow.resetMpin);

  final AuthService _auth;
  final SessionProvider _session;
  final OtpChallenge _otp;

  String? _firstMpin;

  @override
  AuthFlow get kind => AuthFlow.resetMpin;

  Future<void> requestResetOtp(String rawPhone) async {
    await _otp.send(rawPhone);
    await _session.enter(OnboardingStage.otpVerify, kind);
  }

  Future<void> verifyResetOtp(String code) async {
    await _otp.verify(code);
    _firstMpin = null;
    await _session.enter(OnboardingStage.mpinSetup, kind);
  }

  @override
  String get phone => _otp.phone;
  @override
  OtpTicket get ticket => _otp.ticket;
  @override
  DateTime? get codeSentAt => _otp.sentAt;
  @override
  bool get codeExpired => _otp.expired;
  @override
  bool get codeLocked => _otp.locked;
  @override
  Future<void> resendOtp() => _otp.resend();
  @override
  Future<void> verifyOtp(String code) => verifyResetOtp(code);

  @override
  Future<void> changeNumber() async {
    _otp.clear();
    _firstMpin = null;
    await _session.enter(OnboardingStage.signedOut, kind);
  }

  @override
  String? validateNewMpin(String pin) =>
      MpinValidator.validate(pin, otp: _otp.verifiedCode);

  @override
  Future<void> createMpin(String pin) async {
    if (_otp.verificationToken == null) await _lost();
    if (validateNewMpin(pin) != null) {
      throw const AuthException(AuthError.weakMpin);
    }
    _firstMpin = pin;
    await _session.enter(OnboardingStage.mpinConfirm, kind);
  }

  @override
  Future<void> confirmMpin(String pin) async {
    final first = _firstMpin;
    if (first == null) return backToCreateMpin();
    if (!MpinValidator.matches(first, pin)) {
      await backToCreateMpin();
      throw const AuthException(AuthError.mpinMismatch);
    }

    final token = _otp.verificationToken;
    if (token == null) await _lost();
    try {
      await _auth.resetMpin(
        phone: _otp.phone,
        verificationToken: token,
        mpin: pin,
      );
    } on AuthException catch (e) {
      if (e.error == AuthError.verificationExpired) await _lost();
      if (e.error == AuthError.weakMpin) await backToCreateMpin();
      rethrow;
    }
    final phone = _otp.phone;
    reset();
    // Only the MPIN changes: the account and this phone's registration
    // stay as they are.
    await _session.mpinWasReset(phone, mpin: pin);
  }

  @override
  Future<void> backToCreateMpin() async {
    _firstMpin = null;
    await _session.enter(OnboardingStage.mpinSetup, kind);
  }

  Future<Never> _lost() async {
    await changeNumber();
    throw const AuthException(AuthError.verificationExpired);
  }

  void reset() {
    _otp.clear();
    _firstMpin = null;
  }
}
