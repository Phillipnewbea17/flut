import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../session_provider.dart';
import '../user_provider.dart';

/// Forgot password:
///
///   email -> (single-use link in the inbox) -> back to Login
///
/// The new password is set on a page served by the backend, which the link
/// opens in the senior's browser. The app's part ends once the email has
/// been asked for, so there is no code to type and nothing else to hold.
///
/// The backend answers the same whether or not the address has an account,
/// so this flow can never be used to find out who has registered.
class PasswordResetFlow {
  PasswordResetFlow({
    required AuthService auth,
    required SessionProvider session,
  })  : _auth = auth,
        _session = session;

  final AuthService _auth;
  final SessionProvider _session;

  String _email = '';
  bool _sent = false;

  AuthFlow get kind => AuthFlow.forgotPassword;

  /// The address the link was asked for.
  String get email => _email;

  /// True once the backend has been asked to send the link.
  bool get sent => _sent;

  /// Asks Laravel to email the link. Returns normally even for an address
  /// with no account: the screen says the same thing either way.
  Future<void> sendLink(String rawEmail) async {
    final email = UserProvider.normalizeEmail(rawEmail);
    if (!UserProvider.isValidEmail(email)) {
      throw const AuthException(AuthError.invalidEmail);
    }

    await _auth.forgotPassword(email: email);
    _email = email;
    _sent = true;
  }

  /// "Back to Login", from either the form or the "email sent" message.
  Future<void> backToLogin() async {
    final email = _email;
    reset();
    if (email.isNotEmpty) await _session.rememberEmail(email);
    await _session.startFlow(AuthFlow.login);
  }

  void reset() {
    _email = '';
    _sent = false;
  }
}
