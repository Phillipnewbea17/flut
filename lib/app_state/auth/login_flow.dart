import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../session_provider.dart';
import '../user_provider.dart';

/// Login (returning user, existing account only):
///
///   email + password -> Home
///
/// One screen. Never creates an account, never asks for a name. The backend
/// answers "invalid_credentials" for both a wrong address and a wrong
/// password, so this flow cannot be used to find out who has an account,
/// and locks the account after too many wrong passwords.
///
/// An account whose address was never confirmed is sent to Check Your
/// Inbox instead, with the address and password it just used, so "Resend
/// email" works without asking for them again.
class LoginFlow {
  LoginFlow({required AuthService auth, required SessionProvider session})
      : _auth = auth,
        _session = session;

  final AuthService _auth;
  final SessionProvider _session;

  String _unverifiedEmail = '';
  String _unverifiedPassword = '';

  AuthFlow get kind => AuthFlow.login;

  /// The address to fill in: the one this phone last used, if any.
  String get email => _session.lastEmail;

  /// The address waiting to be confirmed, for Check Your Inbox.
  String get unverifiedEmail => _unverifiedEmail;

  /// Laravel checks the password and returns the session token. Only then
  /// is the user signed in and taken Home.
  Future<void> logIn({
    required String rawEmail,
    required String password,
  }) async {
    final email = UserProvider.normalizeEmail(rawEmail);
    if (!UserProvider.isValidEmail(email)) {
      throw const AuthException(AuthError.invalidEmail);
    }
    if (password.isEmpty) {
      throw const AuthException(AuthError.invalidCredentials);
    }

    try {
      await _auth.login(email: email, password: password);
    } on AuthException catch (e) {
      if (e.error == AuthError.emailNotVerified) {
        // The password was right, so holding it is safe enough to let the
        // senior ask for the email again without retyping it.
        _unverifiedEmail = e.email ?? email;
        _unverifiedPassword = password;
        await _session.enter(OnboardingStage.checkInbox, kind);
      }
      rethrow;
    }

    reset();
    await _session.startSession(email);
  }

  /// "Resend email" on Check Your Inbox. Returns true when the address
  /// turned out to be confirmed already.
  Future<bool> resendVerification() async {
    if (_unverifiedEmail.isEmpty || _unverifiedPassword.isEmpty) {
      throw const AuthException(AuthError.sessionExpired);
    }
    return _auth.resendVerification(
      email: _unverifiedEmail,
      password: _unverifiedPassword,
    );
  }

  /// "I have confirmed it - go to Login": back to the login screen, and the
  /// password is forgotten.
  Future<void> backToLogin() async {
    final email = _unverifiedEmail;
    reset();
    if (email.isNotEmpty) await _session.rememberEmail(email);
    await _session.startFlow(AuthFlow.login);
  }

  /// Log out, or the flow finished: forget the held password.
  void reset() {
    _unverifiedEmail = '';
    _unverifiedPassword = '';
  }
}
