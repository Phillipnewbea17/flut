import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../utils/mpin_validator.dart';
import '../session_provider.dart';
import 'auth_steps.dart';
import 'otp_challenge.dart';

/// Login (returning user, existing account only):
///
///   new phone:      requestLoginOtp -> verifyLoginOtp -> verifyMpin -> Home
///   trusted phone:  requestLoginOtp -> verifyMpin -> Home (no code)
///   app re-opened:  resumeOnThisPhone -> verifyMpin -> Home (no code)
///
/// A phone is trusted once it verified a code for this number (Create
/// Account, an earlier login, or Forgot MPIN). Never creates an account,
/// never asks for a name, never creates an MPIN. The backend refuses an
/// unknown number, checks the code or the phone's device key, then checks
/// the existing MPIN and returns the session token.
class LoginFlow implements OtpStep {
  LoginFlow({required AuthService auth, required SessionProvider session})
      : _auth = auth,
        _session = session,
        _otp = OtpChallenge(auth, AuthFlow.login);

  final AuthService _auth;
  final SessionProvider _session;
  final OtpChallenge _otp;

  /// Set when this phone is trusted for the number: no code is sent.
  String? _trustedPhone;

  @override
  AuthFlow get kind => AuthFlow.login;

  /// The app was opened again on a phone that already has the account
  /// (SessionProvider.resumeMpinLogin at the splash): go straight to
  /// "Enter your MPIN" with its number, without asking for the number and
  /// without texting a code.
  Future<void> resumeOnThisPhone(String phone) async {
    _otp.clear();
    _trustedPhone = phone;
    await _session.enter(OnboardingStage.mpinEntry, kind);
  }

  Future<void> requestLoginOtp(String rawPhone) async {
    final phone = UserProvider.normalizePhone(rawPhone);
    if (UserProvider.isValidPhone(phone) &&
        await _auth.trustedPhone() == phone) {
      _otp.clear();
      _trustedPhone = phone;
      await _session.enter(OnboardingStage.mpinEntry, kind);
      return;
    }
    _trustedPhone = null;
    await _otp.send(rawPhone);
    await _session.enter(OnboardingStage.otpVerify, kind);
  }

  Future<void> verifyLoginOtp(String code) async {
    await _otp.verify(code);
    await _session.enter(OnboardingStage.mpinEntry, kind);
  }

  @override
  String get phone => _trustedPhone ?? _otp.phone;
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
  Future<void> verifyOtp(String code) => verifyLoginOtp(code);

  @override
  Future<void> changeNumber() async {
    reset();
    await _session.enter(OnboardingStage.signedOut, kind);
  }

  /// The existing MPIN. The hash kept on this phone catches a wrong MPIN
  /// first (and counts the tries, so they are limited even offline); the
  /// backend then checks it again and returns the session.
  Future<void> verifyMpin(String mpin) async {
    if (!MpinValidator.isComplete(mpin)) {
      throw const AuthException(AuthError.wrongMpin);
    }
    await _session.checkStoredMpin(mpin);
    await authenticate(mpin);
  }

  /// Laravel checks the MPIN and returns the session token. Only then is the
  /// user signed in and taken Home.
  Future<void> authenticate(String mpin) async {
    final trusted = _trustedPhone;
    if (trusted != null) return _authenticateTrusted(trusted, mpin);

    final token = _otp.verificationToken;
    if (token == null) await _lost();
    try {
      await _auth.login(
        phone: _otp.phone,
        verificationToken: token,
        mpin: mpin,
      );
    } on AuthException catch (e) {
      if (e.error == AuthError.verificationExpired) await _lost();
      rethrow;
    }
    final phone = _otp.phone;
    reset();
    await _session.startSession(phone, mpin: mpin);
  }

  /// MPIN only. When the backend no longer trusts this phone (the MPIN was
  /// reset on another phone), a code is texted and the code screen opens.
  Future<void> _authenticateTrusted(String phone, String mpin) async {
    try {
      await _auth.loginOnTrustedPhone(phone: phone, mpin: mpin);
    } on AuthException catch (e) {
      if (e.error == AuthError.deviceNotTrusted) {
        _trustedPhone = null;
        try {
          await _otp.send(phone);
        } on AuthException {
          await changeNumber();
          rethrow;
        }
        await _session.enter(OnboardingStage.otpVerify, kind);
      }
      rethrow;
    }
    reset();
    await _session.startSession(phone, mpin: mpin);
  }

  Future<Never> _lost() async {
    await changeNumber();
    throw const AuthException(AuthError.verificationExpired);
  }

  void reset() {
    _otp.clear();
    _trustedPhone = null;
  }
}
