import '../models/registration_name.dart';
import '../storage/auth_storage.dart';
import 'api_client.dart';

/// Why a sign-in step failed. Each one has its own plain-words message.
enum AuthError {
  invalidName,

  /// Each part of the name fits, but together they are longer than the
  /// account can hold.
  nameTooLong,
  invalidEmail,
  invalidPassword,
  weakPassword,

  /// Change Password: the new password is the current one.
  samePassword,
  passwordMismatch,
  alreadyRegistered,

  /// A wrong address and a wrong password both land here: the backend will
  /// not say which, so nobody can use Login to find out who has an account.
  invalidCredentials,

  /// The account exists and the password was right, but the address has not
  /// been confirmed yet. The app offers to send the email again.
  emailNotVerified,

  accountLocked,
  accountDeactivated,
  sessionExpired,
  emailFailed,

  /// Too many tries in a short time (HTTP 429). Nothing typed was wrong:
  /// the senior only has to wait a moment.
  tooManyAttempts,
  unavailable,
  network,
  server,
  unknown,
}

/// Thrown when a sign-in step fails. [message] is written in plain words
/// so a screen can show it as-is. It never contains the server's own text,
/// so nothing about the backend is shown to the user.
class AuthException implements Exception {
  final AuthError error;

  /// How long to wait before trying again, when the backend says.
  final Duration? retryAfter;

  /// The address the backend is talking about, when it says so (an
  /// unconfirmed account).
  final String? email;

  const AuthException(this.error, {this.retryAfter, this.email});

  String get message => switch (error) {
        AuthError.invalidName => 'Please check your name. Use letters only.',
        AuthError.nameTooLong =>
          'Your name is too long. Please use a shorter form of it.',
        AuthError.invalidEmail =>
          'Please enter your email address, like rosela@gmail.com.',
        AuthError.invalidPassword =>
          'Please use a password of at least 8 characters.',
        AuthError.weakPassword =>
          'This password is too easy to guess. Please choose another one.',
        AuthError.samePassword =>
          'Please choose a new password that is different from your current '
              'one.',
        AuthError.passwordMismatch =>
          'The passwords do not match. Please type them again.',
        AuthError.alreadyRegistered =>
          'This email address is already registered. Please log in instead.',
        AuthError.invalidCredentials => 'Incorrect email or password.',
        AuthError.emailNotVerified =>
          'Please confirm your email address first. Check your inbox for '
              'our email.',
        AuthError.accountLocked => 'Too many wrong passwords. Please use '
            '"Forgot password?" or try again later.',
        AuthError.accountDeactivated =>
          'This account has been deactivated. Please contact the OSCA office.',
        AuthError.sessionExpired =>
          'Your session has ended. Please log in again.',
        AuthError.emailFailed =>
          'We could not send the email right now. Please try again later.',
        AuthError.tooManyAttempts =>
          'Too many tries. Please wait a minute and try again.',
        AuthError.unavailable => 'Signing in is not available right now. '
            'Please contact the OSCA office for help.',
        AuthError.network =>
          'Could not connect. Please check your internet and try again.',
        AuthError.server =>
          'Something went wrong on our side. Please try again later.',
        AuthError.unknown => "We couldn't verify your information. Please "
            'check your details and try again.',
      };

  @override
  String toString() => message;
}

/// Is the saved session still good?
enum SessionStatus {
  /// The backend accepted the token.
  valid,

  /// There is no token on this phone.
  none,

  /// The backend refused the token: sign in again.
  expired,

  /// The backend could not be reached. The token is kept; the backend
  /// still refuses it for every request if it has expired.
  offline,
}

/// Signing in through the SCMS backend: an email address and a password,
/// with the address confirmed by tapping a link in the inbox.
///
/// The password is sent to the backend only (over HTTPS), which stores it
/// as a bcrypt hash. It is never saved on the phone and never written to
/// any log.
///
/// Nothing is ever typed out of an email. [register] and [forgotPassword]
/// ask the backend to send a link; the page it opens is served by the
/// backend, not by this app.
abstract class AuthService {
  /// Creates the account and asks the backend to email a confirmation
  /// link. Does NOT sign in: the address has to be confirmed first.
  Future<void> register({
    required RegistrationName name,
    required String email,
    required String password,
  });

  /// Signs in. Throws [AuthError.emailNotVerified] when the address has
  /// not been confirmed yet, and [AuthError.invalidCredentials] for both a
  /// wrong address and a wrong password.
  Future<void> login({required String email, required String password});

  /// Sends the confirmation email again. The password is needed so only
  /// the account's owner can ask for it. Returns true when the address
  /// turned out to be confirmed already.
  Future<bool> resendVerification({
    required String email,
    required String password,
  });

  /// Forgot password: asks the backend to email a single-use link. Returns
  /// normally whether or not the address has an account, so this can never
  /// be used to find out who has registered.
  Future<void> forgotPassword({required String email});

  /// Changes the password of the signed-in account (Account > Change
  /// Password).
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  });

  /// Asks the backend whether the saved session is still good.
  Future<SessionStatus> checkSession();

  /// Ends the session on the backend (when reachable) and forgets the token.
  Future<void> signOut();
}

/// The real service: /api/mobile/auth/* on the SCMS backend.
class ApiAuthService implements AuthService {
  ApiAuthService({required ApiClient api, required AuthStorage storage})
      : _api = api,
        _storage = storage;

  final ApiClient _api;
  final AuthStorage _storage;

  @override
  Future<void> register({
    required RegistrationName name,
    required String email,
    required String password,
  }) async {
    await _call(() => _api.post('/auth/register', {
          ...name.toJson(),
          'email': email,
          'password': password,
        }));
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await _call(() => _api.post('/auth/login', {
          'email': email,
          'password': password,
        }));
    await _saveSession(data);
  }

  @override
  Future<bool> resendVerification({
    required String email,
    required String password,
  }) async {
    final data = await _call(() => _api.post('/auth/verification/resend', {
          'email': email,
          'password': password,
        }));
    return data['alreadyVerified'] == true;
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _call(() => _api.post('/auth/password/forgot', {'email': email}));
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    final data = await _call(() => _api.post('/auth/password/change', {
          'currentPassword': currentPassword,
          'password': password,
        }));
    if (data['ok'] != true) throw const AuthException(AuthError.unknown);
  }

  @override
  Future<SessionStatus> checkSession() async {
    if (_api.token == null) {
      try {
        _api.token = await _storage.readToken();
      } catch (_) {
        _api.token = null; // Secure storage unreadable: sign in again.
      }
    }
    if (_api.token == null) return SessionStatus.none;
    try {
      await _api.get('/profile');
      return SessionStatus.valid;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _forgetToken();
        return SessionStatus.expired;
      }
      // Offline or a server problem: the token may still be good.
      return SessionStatus.offline;
    }
  }

  @override
  Future<void> signOut() async {
    if (_api.token != null) {
      try {
        await _api.post('/auth/sign-out', const {});
      } catch (_) {
        // Offline: the token is still forgotten on this phone below.
      }
    }
    await _forgetToken();
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthException(AuthError.server);
    }
    await _storage.saveToken(token);
    _api.token = token;
  }

  Future<void> _forgetToken() async {
    _api.token = null;
    try {
      await _storage.deleteToken();
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() send,
  ) async {
    try {
      return await send();
    } on ApiException catch (e) {
      throw toAuthException(e);
    }
  }

  /// Turns the backend's answer into one of the app's own messages.
  static AuthException toAuthException(ApiException e) {
    final status = e.statusCode;
    final code = e.code ?? '';
    final retry = e.retryAfter;

    final error = switch (code) {
      'invalid_name' => AuthError.invalidName,
      'name_too_long' => AuthError.nameTooLong,
      'invalid_email' => AuthError.invalidEmail,
      'invalid_password' => AuthError.invalidPassword,
      'weak_password' => AuthError.weakPassword,
      'same_password' => AuthError.samePassword,
      'already_registered' => AuthError.alreadyRegistered,
      'invalid_credentials' => AuthError.invalidCredentials,
      'email_not_verified' => AuthError.emailNotVerified,
      'account_locked' || 'locked' => AuthError.accountLocked,
      'account_deactivated' => AuthError.accountDeactivated,
      'email_failed' => AuthError.emailFailed,
      'too_many_attempts' => AuthError.tooManyAttempts,
      _ => null,
    };
    if (error != null) {
      return AuthException(error, retryAfter: retry, email: e.email);
    }
    if (status == null) return const AuthException(AuthError.network);
    if (status == 401) return const AuthException(AuthError.sessionExpired);
    // Rate limited without a code (an older backend): still only a wait,
    // never "check your details".
    if (status == 429) {
      return AuthException(AuthError.tooManyAttempts, retryAfter: retry);
    }
    // Laravel answers 404 without a "code" when a route does not exist.
    if (status == 404 || status == 405) {
      return const AuthException(AuthError.unavailable);
    }
    if (status >= 500) return const AuthException(AuthError.server);
    return const AuthException(AuthError.unknown);
  }
}

/// Used when the app has no backend address (plain `flutter run`).
/// Nothing can be checked without the SCMS backend, so signing in is never
/// faked: every step says it is not available.
class UnavailableAuthService implements AuthService {
  const UnavailableAuthService();

  static const _error = AuthException(AuthError.unavailable);

  @override
  Future<void> register({
    required RegistrationName name,
    required String email,
    required String password,
  }) async =>
      throw _error;

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async =>
      throw _error;

  @override
  Future<bool> resendVerification({
    required String email,
    required String password,
  }) async =>
      throw _error;

  @override
  Future<void> forgotPassword({required String email}) async => throw _error;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async =>
      throw _error;

  @override
  Future<SessionStatus> checkSession() async => SessionStatus.none;

  @override
  Future<void> signOut() async {}
}
