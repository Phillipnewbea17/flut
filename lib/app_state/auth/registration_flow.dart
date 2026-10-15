import '../../models/onboarding_stage.dart';
import '../../models/registration_name.dart';
import '../../services/auth_service.dart';
import '../../utils/password_validator.dart';
import '../session_provider.dart';
import '../user_provider.dart';

/// Sign up (new user):
///
///   name -> email + password + confirm -> "check your inbox" -> Login
///
/// Nothing exists until [createAccount]: the backend then makes the account
/// with the name, the address and the password (stored hashed), leaves it
/// unconfirmed, and emails a link. No session comes back, so the senior
/// confirms the address and then logs in.
///
/// The name is only kept in memory. The address and the password are kept
/// until the Check Your Inbox screen is left, so "Resend email" can be
/// offered without asking the senior to type them again.
class RegistrationFlow {
  RegistrationFlow({required AuthService auth, required SessionProvider session})
      : _auth = auth,
        _session = session;

  final AuthService _auth;
  final SessionProvider _session;

  RegistrationName? _name;
  String _email = '';
  String _password = '';

  AuthFlow get kind => AuthFlow.register;

  /// The name typed in the first step (to fill the form when going back).
  RegistrationName? get name => _name;

  /// The address the confirmation email went to.
  String get email => _email;

  // ---------------------------------------------------------------------------
  // 1. Name
  // ---------------------------------------------------------------------------

  /// Checks the name and opens the email and password screen. Returns the
  /// problems (field -> message), or an empty map when it moved on.
  Future<Map<String, String>> saveName(RegistrationName name) async {
    final errors = RegistrationName.validate(name);
    if (errors.isNotEmpty) return errors;
    _name = name.cleaned;
    await _session.enter(OnboardingStage.credentials, kind);
    return const {};
  }

  /// "Back" on the email and password screen.
  Future<void> backToName() async {
    await _session.enter(OnboardingStage.signedOut, kind);
  }

  // ---------------------------------------------------------------------------
  // 2. Email address and password
  // ---------------------------------------------------------------------------

  /// Checks what was typed, then asks Laravel to make the account and send
  /// the confirmation email. Opens Check Your Inbox when it worked.
  ///
  /// The screen checks the same rules first so it can point at the field
  /// that is wrong; these throws are the backstop.
  Future<void> createAccount({
    required String rawEmail,
    required String password,
    required String confirmation,
  }) async {
    final name = _name;
    if (name == null) return backToName();

    final email = UserProvider.normalizeEmail(rawEmail);
    if (!UserProvider.isValidEmail(email)) {
      throw const AuthException(AuthError.invalidEmail);
    }
    if (PasswordValidator.validate(password, email: email) != null) {
      throw const AuthException(AuthError.invalidPassword);
    }
    if (!PasswordValidator.matches(password, confirmation)) {
      throw const AuthException(AuthError.passwordMismatch);
    }

    await _auth.register(name: name, email: email, password: password);

    _email = email;
    _password = password;
    await _session.enter(OnboardingStage.checkInbox, kind);
  }

  // ---------------------------------------------------------------------------
  // 3. Check your inbox
  // ---------------------------------------------------------------------------

  /// "Resend email". Returns true when the address turned out to be
  /// confirmed already, so the screen can send the senior to Login.
  Future<bool> resendVerification() async {
    if (_email.isEmpty || _password.isEmpty) {
      throw const AuthException(AuthError.sessionExpired);
    }
    return _auth.resendVerification(email: _email, password: _password);
  }

  /// "I have confirmed it - go to Login". Forgets the password here: from
  /// now on the senior types it on the Login screen.
  Future<void> goToLogin() async {
    final email = _email;
    reset();
    await _session.rememberEmail(email);
    await _session.startFlow(AuthFlow.login);
  }

  /// Log out, or the flow finished: forget everything, password included.
  void reset() {
    _name = null;
    _email = '';
    _password = '';
  }
}
