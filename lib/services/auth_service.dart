import '../models/onboarding_stage.dart';
import '../models/registration_name.dart';
import '../storage/secure_vault.dart';
import 'api_client.dart';

/// Why a sign-in step failed. Each one has its own plain-words message.
enum AuthError {
  invalidName,
  invalidPhone,
  alreadyRegistered,
  accountNotFound,
  wrongCode,
  codeExpired,
  tooManyAttempts,
  tooManyRequests,
  verificationExpired,
  deviceNotTrusted,
  wrongMpin,
  mpinLocked,
  weakMpin,
  mpinMismatch,
  sessionExpired,
  smsFailed,
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

  /// Tries left, when the backend says (wrong code, wrong MPIN).
  final int? attemptsLeft;

  /// How long to wait before asking again, when the backend says.
  final Duration? retryAfter;

  const AuthException(this.error, {this.attemptsLeft, this.retryAfter});

  String get message {
    final left = attemptsLeft;
    final tries = left == null || left <= 0
        ? ''
        : ' You have $left ${left == 1 ? 'try' : 'tries'} left.';
    return switch (error) {
      AuthError.invalidName =>
        'Please check your name. Use letters only.',
      AuthError.invalidPhone =>
        'Please enter your 10-digit mobile number. It starts with 9.',
      AuthError.alreadyRegistered =>
        'This mobile number is already registered. Please log in instead.',
      AuthError.accountNotFound =>
        'Account not found. Please create an account first.',
      AuthError.wrongCode => 'That code is incorrect. Please try again.$tries',
      AuthError.codeExpired =>
        'This code has expired. Please request a new code.',
      AuthError.tooManyAttempts =>
        'Too many attempts. Please request a new code or try again later.',
      AuthError.tooManyRequests =>
        'Please wait a moment before asking for a new code.',
      AuthError.verificationExpired =>
        'Your verification has expired. Please start again.',
      AuthError.deviceNotTrusted =>
        'Please confirm this phone with the code we texted you.',
      AuthError.wrongMpin => 'Your MPIN is incorrect. Please try again.$tries',
      AuthError.mpinLocked => 'Too many wrong MPIN tries. Please use '
          '"Forgot MPIN" or try again later.',
      AuthError.weakMpin =>
        'This MPIN is too easy to guess. Please choose different numbers.',
      AuthError.mpinMismatch =>
        'The MPINs do not match. Please try again.',
      AuthError.sessionExpired =>
        'Your session has ended. Please log in again.',
      AuthError.smsFailed =>
        'We could not send the code right now. Please try again later.',
      AuthError.unavailable => 'Signing in is not available right now. '
          'Please contact the OSCA office for help.',
      AuthError.network =>
        'Could not connect. Please check your internet and try again.',
      AuthError.server =>
        'Something went wrong on our side. Please try again later.',
      AuthError.unknown => "We couldn't verify your information. Please "
          'check your details and try again.',
    };
  }

  @override
  String toString() => message;
}

/// What the backend says after a code was sent.
class OtpTicket {
  /// How long the code works.
  final Duration expiresIn;

  /// How long before another code may be asked for.
  final Duration resendIn;

  const OtpTicket({
    this.expiresIn = defaultExpiry,
    this.resendIn = defaultResend,
  });

  static const Duration defaultExpiry = Duration(minutes: 5);
  static const Duration defaultResend = Duration(seconds: 60);
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

/// Signing in through the SCMS backend.
///
/// The one-time code (OTP) proves the user has the phone. The MPIN proves
/// it is the account owner. They are separate: a verified code only gives a
/// short-lived [verificationToken] that is good for ONE next step (create
/// the account, log in, or reset the MPIN), together with the MPIN.
///
/// The MPIN is sent to the backend only (over HTTPS), which stores it
/// hashed. It is never saved on the phone or written to any log.
///
/// A verified code also makes this phone trusted: the backend returns a
/// device key, kept in the secure vault, and logging in again on this phone
/// needs only the MPIN ([loginOnTrustedPhone]). So a code is texted only for
/// Create Account, a new phone, and Forgot MPIN.
abstract class AuthService {
  /// Asks the backend to text a 4-digit code to [phone] (10 digits, no +63).
  /// For [AuthFlow.register] the backend refuses a number that already has
  /// an account; for login and reset it refuses an unknown number.
  Future<OtpTicket> requestOtp({required String phone, required AuthFlow flow});

  /// Checks [code]. Returns the verification token for the next step.
  Future<String> verifyOtp({
    required String phone,
    required String code,
    required AuthFlow flow,
  });

  /// Creates the account with its name and MPIN, and signs in.
  Future<void> register({
    required RegistrationName name,
    required String phone,
    required String verificationToken,
    required String mpin,
  });

  /// Signs in an existing account with its MPIN.
  Future<void> login({
    required String phone,
    required String verificationToken,
    required String mpin,
  });

  /// The number this phone already proved with a code, or null.
  Future<String?> trustedPhone();

  /// Signs in on a trusted phone with the MPIN only (no code). Throws
  /// AuthError.deviceNotTrusted when the backend no longer trusts this
  /// phone (e.g. the MPIN was reset on another phone); the device key is
  /// then forgotten and a code is needed.
  Future<void> loginOnTrustedPhone({
    required String phone,
    required String mpin,
  });

  /// Sets a new MPIN (Forgot MPIN). Does NOT sign in.
  Future<void> resetMpin({
    required String phone,
    required String verificationToken,
    required String mpin,
  });

  /// Changes the MPIN of the signed-in account (Account > Change MPIN).
  Future<void> changeMpin({required String currentMpin, required String mpin});

  /// Asks the backend whether the saved session is still good.
  Future<SessionStatus> checkSession();

  /// Ends the session on the backend (when reachable) and forgets the token.
  Future<void> signOut();
}

/// The real service: /api/mobile/auth/* on the SCMS backend.
class ApiAuthService implements AuthService {
  ApiAuthService({required ApiClient api, required SecureVault vault})
      : _api = api,
        _vault = vault;

  final ApiClient _api;
  final SecureVault _vault;

  @override
  Future<OtpTicket> requestOtp({
    required String phone,
    required AuthFlow flow,
  }) async {
    final data = await _call(
        () => _api.post('/auth/code', {'phone': phone, 'purpose': flow.wireName}));
    return OtpTicket(
      expiresIn: _seconds(data['expiresIn']) ?? OtpTicket.defaultExpiry,
      resendIn: _seconds(data['resendIn']) ?? OtpTicket.defaultResend,
    );
  }

  @override
  Future<String> verifyOtp({
    required String phone,
    required String code,
    required AuthFlow flow,
  }) async {
    final data = await _call(() => _api.post('/auth/verify', {
          'phone': phone,
          'code': code,
          'purpose': flow.wireName,
        }));
    final token = data['verificationToken'];
    // An older backend signs in with the code alone (no MPIN). That is not
    // allowed any more, so it is treated as "not available".
    if (token is! String || token.isEmpty) {
      throw const AuthException(AuthError.unavailable);
    }
    return token;
  }

  @override
  Future<void> register({
    required RegistrationName name,
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async {
    final data = await _call(() => _api.post('/auth/register', {
          ...name.toJson(),
          'phone': phone,
          'verificationToken': verificationToken,
          'mpin': mpin,
        }));
    await _saveSession(data);
    await _saveDevice(phone, data);
  }

  @override
  Future<void> login({
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async {
    final data = await _call(() => _api.post('/auth/login', {
          'phone': phone,
          'verificationToken': verificationToken,
          'mpin': mpin,
        }));
    await _saveSession(data);
    await _saveDevice(phone, data);
  }

  @override
  Future<String?> trustedPhone() async {
    try {
      return (await _vault.readDevice())?.$1;
    } catch (_) {
      return null; // Secure storage unreadable: confirm with a code.
    }
  }

  @override
  Future<void> loginOnTrustedPhone({
    required String phone,
    required String mpin,
  }) async {
    (String, String)? device;
    try {
      device = await _vault.readDevice();
    } catch (_) {}
    if (device == null || device.$1 != phone) {
      throw const AuthException(AuthError.deviceNotTrusted);
    }
    final key = device.$2;
    try {
      final data = await _call(() => _api.post('/auth/login', {
            'phone': phone,
            'deviceKey': key,
            'mpin': mpin,
          }));
      await _saveSession(data);
    } on AuthException catch (e) {
      if (e.error == AuthError.deviceNotTrusted ||
          e.error == AuthError.accountNotFound) {
        await _forgetDevice();
      }
      rethrow;
    }
  }

  @override
  Future<void> resetMpin({
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async {
    final data = await _call(() => _api.post('/auth/mpin/reset', {
          'phone': phone,
          'verificationToken': verificationToken,
          'mpin': mpin,
        }));
    if (data['ok'] != true) throw const AuthException(AuthError.unknown);
    // The backend forgot every other phone; this one is trusted again.
    await _saveDevice(phone, data);
  }

  @override
  Future<void> changeMpin({
    required String currentMpin,
    required String mpin,
  }) async {
    final data = await _call(() => _api.post('/auth/mpin/change', {
          'currentMpin': currentMpin,
          'mpin': mpin,
        }));
    if (data['ok'] != true) throw const AuthException(AuthError.unknown);
  }

  @override
  Future<SessionStatus> checkSession() async {
    if (_api.token == null) {
      try {
        _api.token = await _vault.readToken();
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
    await _vault.saveToken(token);
    _api.token = token;
  }

  Future<void> _forgetToken() async {
    _api.token = null;
    try {
      await _vault.deleteToken();
    } catch (_) {}
  }

  /// Keeps the device key from a verified code. A backend without trusted
  /// phones sends none: then every login asks for a code, as before.
  Future<void> _saveDevice(String phone, Map<String, dynamic> data) async {
    final key = data['deviceKey'];
    try {
      if (key is String && key.isNotEmpty) {
        await _vault.saveDevice(phone, key);
      } else {
        await _vault.deleteDevice();
      }
    } catch (_) {
      // Not saved: the next login asks for a code again.
    }
  }

  Future<void> _forgetDevice() async {
    try {
      await _vault.deleteDevice();
    } catch (_) {}
  }

  static Duration? _seconds(Object? value) =>
      value is num && value > 0 ? Duration(seconds: value.toInt()) : null;

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
    final left = e.attemptsLeft;
    final retry = e.retryAfter;

    final error = switch (code) {
      'invalid_name' => AuthError.invalidName,
      'invalid_phone' => AuthError.invalidPhone,
      'already_registered' => AuthError.alreadyRegistered,
      'account_not_found' || 'not_found' => AuthError.accountNotFound,
      'wrong_code' => AuthError.wrongCode,
      'expired' || 'code_expired' => AuthError.codeExpired,
      'too_many_attempts' => AuthError.tooManyAttempts,
      'too_many_requests' => AuthError.tooManyRequests,
      'verification_expired' => AuthError.verificationExpired,
      'device_not_trusted' => AuthError.deviceNotTrusted,
      'wrong_mpin' => AuthError.wrongMpin,
      'mpin_locked' || 'locked' => AuthError.mpinLocked,
      'weak_mpin' => AuthError.weakMpin,
      'invalid_mpin' => AuthError.weakMpin,
      'sms_failed' => AuthError.smsFailed,
      _ => null,
    };
    if (error != null) {
      return AuthException(error, attemptsLeft: left, retryAfter: retry);
    }
    if (status == null) return const AuthException(AuthError.network);
    if (status == 401) return const AuthException(AuthError.sessionExpired);
    if (status == 429) {
      return AuthException(AuthError.tooManyRequests, retryAfter: retry);
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
  Future<OtpTicket> requestOtp({
    required String phone,
    required AuthFlow flow,
  }) async =>
      throw _error;

  @override
  Future<String> verifyOtp({
    required String phone,
    required String code,
    required AuthFlow flow,
  }) async =>
      throw _error;

  @override
  Future<void> register({
    required RegistrationName name,
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async =>
      throw _error;

  @override
  Future<void> login({
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async =>
      throw _error;

  @override
  Future<String?> trustedPhone() async => null;

  @override
  Future<void> loginOnTrustedPhone({
    required String phone,
    required String mpin,
  }) async =>
      throw _error;

  @override
  Future<void> resetMpin({
    required String phone,
    required String verificationToken,
    required String mpin,
  }) async =>
      throw _error;

  @override
  Future<void> changeMpin({
    required String currentMpin,
    required String mpin,
  }) async =>
      throw _error;

  @override
  Future<SessionStatus> checkSession() async => SessionStatus.none;

  @override
  Future<void> signOut() async {}
}
