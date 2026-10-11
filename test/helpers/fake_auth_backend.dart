import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/models/registration_name.dart';
import 'package:my_senior_app/services/auth_service.dart';

/// Test-only stand-in for the SCMS backend's sign-in rules. Each test sets
/// the code the "server" sent with [nextCode]; there is no fixed code.
class FakeAuthBackend implements AuthService {
  FakeAuthBackend({
    Map<String, String>? mpins,
    this.ticket = const OtpTicket(),
  }) : mpins = mpins ?? {};

  /// Registered accounts: phone -> MPIN.
  final Map<String, String> mpins;

  OtpTicket ticket;

  /// The code the next [requestOtp] "texts" to the phone.
  String nextCode = '';

  /// Wrong codes the server allows per code.
  int maxCodeAttempts = 5;

  /// Wrong MPINs the server allows before locking.
  int maxMpinAttempts = 3;

  /// What [checkSession] answers when a session exists.
  SessionStatus sessionStatus = SessionStatus.valid;

  String? sessionPhone;
  final List<String> calls = [];

  String? _code;
  String? _codePhone;
  AuthFlow? _codeFlow;
  int _wrongCodes = 0;
  bool codeExpired = false;
  final Map<String, AuthFlow> _verified = {};
  int _wrongMpins = 0;
  int _tokens = 0;

  @override
  Future<OtpTicket> requestOtp({
    required String phone,
    required AuthFlow flow,
  }) async {
    calls.add('code:${flow.wireName}');
    final exists = mpins.containsKey(phone);
    if (flow == AuthFlow.register && exists) {
      throw const AuthException(AuthError.alreadyRegistered);
    }
    if (flow != AuthFlow.register && !exists) {
      throw const AuthException(AuthError.accountNotFound);
    }
    _code = nextCode;
    _codePhone = phone;
    _codeFlow = flow;
    _wrongCodes = 0;
    codeExpired = false;
    return ticket;
  }

  @override
  Future<String> verifyOtp({
    required String phone,
    required String code,
    required AuthFlow flow,
  }) async {
    calls.add('verify');
    if (_code == null || phone != _codePhone || flow != _codeFlow) {
      throw const AuthException(AuthError.codeExpired);
    }
    if (codeExpired) throw const AuthException(AuthError.codeExpired);
    if (_wrongCodes >= maxCodeAttempts) {
      throw const AuthException(AuthError.tooManyAttempts);
    }
    if (code != _code) {
      _wrongCodes++;
      throw AuthException(AuthError.wrongCode,
          attemptsLeft: maxCodeAttempts - _wrongCodes);
    }
    _code = null;
    final token = 'verify-${++_tokens}';
    _verified[token] = flow;
    return token;
  }

  void _useVerification(String token, AuthFlow flow) {
    if (_verified.remove(token) != flow) {
      throw const AuthException(AuthError.verificationExpired);
    }
  }

  /// Registered accounts: phone -> name sent with Create Account.
  final Map<String, RegistrationName> names = {};

  @override
  Future<void> register({
    required RegistrationName name,
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async {
    calls.add('register');
    _useVerification(verificationToken, AuthFlow.register);
    if (mpins.containsKey(phone)) {
      throw const AuthException(AuthError.alreadyRegistered);
    }
    mpins[phone] = mpin;
    names[phone] = name;
    sessionPhone = phone;
  }

  @override
  Future<void> login({
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async {
    calls.add('login');
    if (_wrongMpins >= maxMpinAttempts) {
      throw const AuthException(AuthError.mpinLocked);
    }
    if (!_verified.containsKey(verificationToken)) {
      throw const AuthException(AuthError.verificationExpired);
    }
    if (mpins[phone] != mpin) {
      _wrongMpins++;
      if (_wrongMpins >= maxMpinAttempts) {
        throw const AuthException(AuthError.mpinLocked);
      }
      throw AuthException(AuthError.wrongMpin,
          attemptsLeft: maxMpinAttempts - _wrongMpins);
    }
    _useVerification(verificationToken, AuthFlow.login);
    _wrongMpins = 0;
    sessionPhone = phone;
  }

  /// No phone is trusted here: every login asks for a code.
  @override
  Future<String?> trustedPhone() async => null;

  @override
  Future<void> loginOnTrustedPhone({
    required String phone,
    required String mpin,
  }) async {
    calls.add('login-trusted');
    throw const AuthException(AuthError.deviceNotTrusted);
  }

  @override
  Future<void> resetMpin({
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async {
    calls.add('reset');
    _useVerification(verificationToken, AuthFlow.resetMpin);
    mpins[phone] = mpin;
    _wrongMpins = 0;
  }

  @override
  Future<void> changeMpin({
    required String currentMpin,
    required String mpin,
  }) async {
    calls.add('change');
    final phone = sessionPhone;
    if (phone == null) throw const AuthException(AuthError.sessionExpired);
    if (mpins[phone] != currentMpin) {
      throw const AuthException(AuthError.wrongMpin);
    }
    mpins[phone] = mpin;
  }

  @override
  Future<SessionStatus> checkSession() async =>
      sessionPhone == null ? SessionStatus.none : sessionStatus;

  @override
  Future<void> signOut() async {
    calls.add('sign-out');
    sessionPhone = null;
  }
}
