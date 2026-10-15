import 'package:my_senior_app/models/registration_name.dart';
import 'package:my_senior_app/services/auth_service.dart';
import 'package:my_senior_app/storage/auth_storage.dart';

/// Test-only stand-in for the SCMS backend's sign-in rules: an email
/// address and a password, with the address confirmed by a link.
///
/// Nothing here sends mail. [verify] stands in for the senior tapping the
/// link in their inbox, and [sentVerifications] counts the emails the real
/// backend would have sent.
class FakeAuthBackend implements AuthService {
  FakeAuthBackend({Map<String, String>? passwords})
      : passwords = passwords ?? {};

  /// Registered accounts: email -> password. An account put here directly
  /// counts as confirmed, so a test can start from "already signed up".
  final Map<String, String> passwords;

  /// Registered accounts: email -> name sent with Sign up.
  final Map<String, RegistrationName> names = {};

  /// Addresses still waiting for their link to be tapped.
  final Set<String> unverified = {};

  /// How many confirmation emails the backend would have sent, per address.
  final Map<String, int> sentVerifications = {};

  /// How many reset links the backend would have sent, per address.
  final Map<String, int> sentResetLinks = {};

  /// Wrong passwords the server allows before locking the account.
  int maxPasswordAttempts = 3;

  /// What [checkSession] answers when a session exists.
  SessionStatus sessionStatus = SessionStatus.valid;

  String? sessionEmail;
  final List<String> calls = [];

  int _wrongPasswords = 0;
  int _tokens = 0;

  /// Stands in for the senior tapping the link in the confirmation email.
  void verify(String email) => unverified.remove(email);

  @override
  Future<void> register({
    required RegistrationName name,
    required String email,
    required String password,
  }) async {
    calls.add('register');
    if (passwords.containsKey(email)) {
      throw const AuthException(AuthError.alreadyRegistered);
    }
    passwords[email] = password;
    names[email] = name;
    // A new account has to confirm its address before it can log in.
    unverified.add(email);
    sentVerifications[email] = (sentVerifications[email] ?? 0) + 1;
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    calls.add('login');
    if (_wrongPasswords >= maxPasswordAttempts) {
      throw const AuthException(AuthError.accountLocked);
    }
    // A wrong address and a wrong password answer alike, so neither can be
    // told from the other.
    if (!passwords.containsKey(email)) {
      throw const AuthException(AuthError.invalidCredentials);
    }
    if (passwords[email] != password) {
      _wrongPasswords++;
      if (_wrongPasswords >= maxPasswordAttempts) {
        throw const AuthException(AuthError.accountLocked);
      }
      throw const AuthException(AuthError.invalidCredentials);
    }
    if (unverified.contains(email)) {
      throw AuthException(AuthError.emailNotVerified, email: email);
    }
    _wrongPasswords = 0;
    sessionEmail = email;
    // Like ApiAuthService: the token goes to AuthStorage, so a restart can
    // find it and SessionProvider can decide whether to open Home.
    await const AuthStorage().saveToken('fake|${++_tokens}');
  }

  @override
  Future<bool> resendVerification({
    required String email,
    required String password,
  }) async {
    calls.add('resend');
    if (passwords[email] != password) {
      throw const AuthException(AuthError.invalidCredentials);
    }
    if (!unverified.contains(email)) return true;
    sentVerifications[email] = (sentVerifications[email] ?? 0) + 1;
    return false;
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    calls.add('forgot');
    // The real backend answers the same whether or not the address has an
    // account, so this never throws for an unknown one.
    if (passwords.containsKey(email)) {
      sentResetLinks[email] = (sentResetLinks[email] ?? 0) + 1;
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    calls.add('change');
    final email = sessionEmail;
    if (email == null) throw const AuthException(AuthError.sessionExpired);
    if (passwords[email] != currentPassword) {
      throw const AuthException(AuthError.invalidCredentials);
    }
    passwords[email] = password;
  }

  @override
  Future<SessionStatus> checkSession() async {
    // Like ApiAuthService: no token on the phone means no session at all,
    // and a token the server refuses is forgotten here too.
    if (await const AuthStorage().readToken() == null) {
      return SessionStatus.none;
    }
    if (sessionStatus == SessionStatus.expired) {
      await const AuthStorage().deleteToken();
    }
    return sessionStatus;
  }

  @override
  Future<void> signOut() async {
    calls.add('sign-out');
    sessionEmail = null;
    await const AuthStorage().deleteToken();
  }
}
