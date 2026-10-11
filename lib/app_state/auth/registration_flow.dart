import '../../models/onboarding_stage.dart';
import '../../models/registration_name.dart';
import '../../services/auth_service.dart';
import '../../utils/mpin_validator.dart';
import '../session_provider.dart';
import 'auth_steps.dart';
import 'otp_challenge.dart';

/// Create Account (new user):
///
///   name -> requestRegistrationOtp -> verifyRegistrationOtp ->
///   createMpin -> confirmMpin -> createAccount -> Home
///
/// Nothing is created until [createAccount]: the backend then makes the
/// account with the name, the verified number and the MPIN (stored hashed),
/// and returns the session token. The name, the code and the MPIN are only
/// kept in memory until then.
class RegistrationFlow implements OtpStep, NewMpinStep {
  RegistrationFlow({required AuthService auth, required SessionProvider session})
      : _auth = auth,
        _session = session,
        _otp = OtpChallenge(auth, AuthFlow.register);

  final AuthService _auth;
  final SessionProvider _session;
  final OtpChallenge _otp;

  RegistrationName? _name;
  String? _firstMpin;

  @override
  AuthFlow get kind => AuthFlow.register;

  /// The name typed in the first step (to fill the form when going back).
  RegistrationName? get name => _name;

  // ---------------------------------------------------------------------------
  // 1. Name
  // ---------------------------------------------------------------------------

  /// Checks the name and opens the mobile number screen. Returns the
  /// problems (field -> message), or an empty map when it moved on.
  Future<Map<String, String>> saveName(RegistrationName name) async {
    final errors = RegistrationName.validate(name);
    if (errors.isNotEmpty) return errors;
    _name = name.cleaned;
    await _session.enter(OnboardingStage.phoneEntry, kind);
    return const {};
  }

  /// "Back" on the mobile number screen.
  Future<void> backToName() async {
    _otp.clear();
    await _session.enter(OnboardingStage.signedOut, kind);
  }

  // ---------------------------------------------------------------------------
  // 2. Mobile number and code
  // ---------------------------------------------------------------------------

  /// The backend refuses a number that already has an account.
  Future<void> requestRegistrationOtp(String rawPhone) async {
    if (_name == null) return backToName();
    await _otp.send(rawPhone);
    await _session.enter(OnboardingStage.otpVerify, kind);
  }

  Future<void> verifyRegistrationOtp(String code) async {
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
  Future<void> verifyOtp(String code) => verifyRegistrationOtp(code);

  @override
  Future<void> changeNumber() async {
    _otp.clear();
    _firstMpin = null;
    await _session.enter(OnboardingStage.phoneEntry, kind);
  }

  // ---------------------------------------------------------------------------
  // 3. MPIN
  // ---------------------------------------------------------------------------

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
    await createAccount(pin);
  }

  @override
  Future<void> backToCreateMpin() async {
    _firstMpin = null;
    await _session.enter(OnboardingStage.mpinSetup, kind);
  }

  // ---------------------------------------------------------------------------
  // 4. Account
  // ---------------------------------------------------------------------------

  /// Laravel creates the account and returns the session. Only then is the
  /// user signed in and taken Home.
  Future<void> createAccount(String mpin) async {
    final name = _name;
    final token = _otp.verificationToken;
    if (name == null || token == null) await _lost();

    try {
      await _auth.register(
        name: name,
        phone: _otp.phone,
        verificationToken: token,
        mpin: mpin,
      );
    } on AuthException catch (e) {
      if (e.error == AuthError.verificationExpired) await _lost();
      if (e.error == AuthError.weakMpin) await backToCreateMpin();
      rethrow;
    }

    final phone = _otp.phone;
    reset();
    await _session.startSession(phone, name: name);
  }

  /// The code's ticket is missing or too old: start again at the number.
  Future<Never> _lost() async {
    await changeNumber();
    throw const AuthException(AuthError.verificationExpired);
  }

  /// Log out, or the account was created: forget everything.
  void reset() {
    _otp.clear();
    _name = null;
    _firstMpin = null;
  }
}
