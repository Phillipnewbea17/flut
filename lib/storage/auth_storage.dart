import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one place this phone keeps anything about signing in:
///
/// - whether an account was created or logged in on this phone
///   ([isRegistered]),
/// - the session token ([saveToken]),
/// - the account's address and name, to fill in and greet on Login.
///
/// The password is NEVER kept here, in any form. Only the backend can
/// judge it, so there is no on-device hash and no offline sign-in.
///
/// Nothing here is deleted when the app closes, a screen is disposed or the
/// user goes back. Only an explicit Logout or Delete account calls
/// [clearAll]. A session the backend refuses calls [clearSession], which
/// keeps the registration, so the next start opens Login with the address
/// already filled in instead of Welcome.
class AuthStorage {
  static const _kLegacyMpin = 'mpin';
  static const _kLegacyMpinHash = 'mpin_hash';
  static const _kLegacyMpinSalt = 'mpin_salt';
  static const _kLegacyMpinTries = 'mpin_tries';
  static const _kLegacyDeviceKey = 'device_key';
  static const _kLegacyDeviceEmail = 'device_email';

  static const _kRegistered = 'is_registered';
  static const _kToken = 'session_token';
  static const _kAccountEmail = 'account_email';
  static const _kAccountName = 'account_name';

  final FlutterSecureStorage _storage;

  const AuthStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Registration: "this phone has an account"
  // ---------------------------------------------------------------------------

  /// Called in the last step of Create Account and after every login, once
  /// the backend has accepted the password. The session token itself is
  /// saved by [saveToken] during that sign-in, one step earlier.
  Future<void> saveRegistration({
    required String email,
    String? token,
    String? fullName,
  }) async {
    if (token != null && token.isNotEmpty) await saveToken(token);
    if (fullName != null && fullName.trim().isNotEmpty) {
      await saveAccountName(fullName);
    }
    await _storage.write(key: _kAccountEmail, value: email);
    await _storage.write(key: _kRegistered, value: 'true');
  }

  /// True when an account was created or logged in on this phone before.
  /// Only [clearAll] (Logout, Delete account) clears it.
  Future<bool> isRegistered() async {
    try {
      return await _storage.read(key: _kRegistered) == 'true';
    } catch (_) {
      return false; // Secure storage unreadable: start at Welcome.
    }
  }

  /// The address of the account on this phone, to fill in Login.
  Future<String?> registeredEmail() async {
    try {
      final email = await _storage.read(key: _kAccountEmail);
      return email != null && email.isNotEmpty ? email : null;
    } catch (_) {
      return null;
    }
  }

  /// The name to greet with ("Welcome back, Rosela"), or null.
  Future<String?> registeredName() async {
    try {
      return await _storage.read(key: _kAccountName);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAccountName(String fullName) =>
      _storage.write(key: _kAccountName, value: fullName.trim());

  // ---------------------------------------------------------------------------
  // Session token
  // ---------------------------------------------------------------------------

  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);
  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<void> deleteToken() => _storage.delete(key: _kToken);

  // ---------------------------------------------------------------------------
  // Leaving
  // ---------------------------------------------------------------------------

  /// The backend refused the session token, or there is none. Only the
  /// token goes: this phone stays registered, so the next start opens
  /// Login with the address filled in.
  Future<void> clearSession() => deleteToken();

  /// Explicit Logout or Delete account: forget the account completely.
  /// After this the app opens at Welcome again.
  Future<void> clearAll() => _storage.deleteAll();

  /// Removes what older builds kept: the plain-text MPIN, its salted hash
  /// and wrong-try count, and the trusted-device key. None of it means
  /// anything now that the password is the only credential and only the
  /// backend checks it.
  Future<void> deleteLegacySecrets() async {
    for (final key in const [
      _kLegacyMpin,
      _kLegacyMpinHash,
      _kLegacyMpinSalt,
      _kLegacyMpinTries,
      _kLegacyDeviceKey,
      _kLegacyDeviceEmail,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // Nothing to clean up, or storage unreadable: harmless either way.
      }
    }
  }
}
