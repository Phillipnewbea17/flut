import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one place this phone keeps anything about signing in:
///
/// - whether an account was created on this phone ([isRegistered]),
/// - the session token ([saveToken]),
/// - the trusted-device key, so logging in again needs no texted code,
/// - the MPIN as a salted hash ([saveMpin]) - never the numbers typed,
/// - the account's number and name, to fill in the MPIN screen.
///
/// Nothing here is deleted when the app closes, a screen is disposed or the
/// user goes back. Only an explicit Logout or Delete account calls
/// [clearAll]. A session the backend refuses calls [clearSession], which
/// keeps the registration, so the next start opens "Enter your MPIN"
/// instead of Create Account.
///
/// The hash only decides which screen opens and catches a wrong MPIN
/// without a round trip; the SCMS backend still has the last word on every
/// sign-in (it keeps its own hash and its own lock-out).
class AuthStorage {
  static const _kLegacyMpin = 'mpin';
  static const _kRegistered = 'is_registered';
  static const _kToken = 'session_token';
  static const _kDeviceKey = 'device_key';
  static const _kDevicePhone = 'device_phone';
  static const _kAccountPhone = 'account_phone';
  static const _kAccountName = 'account_name';
  static const _kMpinHash = 'mpin_hash';
  static const _kMpinSalt = 'mpin_salt';
  static const _kMpinTries = 'mpin_tries';

  /// Wrong MPINs allowed on this phone before "Forgot MPIN" is needed.
  static const int maxMpinAttempts = 5;

  /// Rounds of hashing. A 4-digit MPIN has only 10,000 possibilities, so
  /// this slows down anyone who got hold of the stored hash.
  static const int _rounds = 10000;

  final FlutterSecureStorage _storage;

  const AuthStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Registration: "this phone has an account"
  // ---------------------------------------------------------------------------

  /// Called in the last step of Create Account and after every login, once
  /// the backend has accepted the MPIN. The session token itself is saved
  /// by [saveToken] during that sign-in, one step earlier.
  Future<void> saveRegistration({
    required String phone,
    String? mpin,
    String? token,
    String? fullName,
  }) async {
    if (token != null && token.isNotEmpty) await saveToken(token);
    if (mpin != null && mpin.isNotEmpty) await saveMpin(mpin);
    if (fullName != null && fullName.trim().isNotEmpty) {
      await saveAccountName(fullName);
    }
    await _storage.write(key: _kAccountPhone, value: phone);
    await _storage.write(key: _kRegistered, value: 'true');
    await clearMpinAttempts();
  }

  /// True when an account was created or logged in on this phone before.
  /// False only clears on [clearAll] (Logout, Delete account).
  Future<bool> isRegistered() async {
    try {
      if (await _storage.read(key: _kRegistered) == 'true') return true;
      // Builds before this flag only left the trusted-device key behind.
      return await readDevice() != null;
    } catch (_) {
      return false; // Secure storage unreadable: start at Welcome.
    }
  }

  /// The number of the account on this phone, for the MPIN screen.
  Future<String?> registeredPhone() async {
    try {
      final phone = await _storage.read(key: _kAccountPhone);
      if (phone != null && phone.isNotEmpty) return phone;
      return (await readDevice())?.$1;
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
  // MPIN (hashed)
  // ---------------------------------------------------------------------------

  /// Keeps [mpin] as a salted hash and forgets the wrong tries. The plain
  /// numbers are never written.
  Future<void> saveMpin(String mpin) async {
    final salt = _newSalt();
    await _storage.write(key: _kMpinSalt, value: salt);
    await _storage.write(key: _kMpinHash, value: _hash(mpin, salt));
    await _storage.delete(key: _kMpinTries);
    await deleteLegacyMpin();
  }

  /// True when this phone can check an MPIN by itself.
  Future<bool> hasMpin() async {
    try {
      final hash = await _storage.read(key: _kMpinHash);
      final salt = await _storage.read(key: _kMpinSalt);
      return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// True when [mpin] matches the saved hash. False when it does not, and
  /// also when nothing is saved: ask [hasMpin] first.
  Future<bool> verifyMpin(String mpin) async {
    try {
      final hash = await _storage.read(key: _kMpinHash);
      final salt = await _storage.read(key: _kMpinSalt);
      if (hash == null || salt == null || hash.isEmpty || salt.isEmpty) {
        return false;
      }
      return _sameHash(_hash(mpin, salt), hash);
    } catch (_) {
      return false;
    }
  }

  /// Wrong MPINs this phone still allows before "Forgot MPIN" is needed.
  Future<int> mpinAttemptsLeft() async {
    try {
      final used = int.tryParse(await _storage.read(key: _kMpinTries) ?? '') ?? 0;
      final left = maxMpinAttempts - used;
      return left < 0 ? 0 : left;
    } catch (_) {
      return maxMpinAttempts;
    }
  }

  /// Counts one wrong MPIN and returns the tries left.
  Future<int> countWrongMpin() async {
    final left = await mpinAttemptsLeft();
    final next = left <= 0 ? 0 : left - 1;
    try {
      await _storage.write(
          key: _kMpinTries, value: '${maxMpinAttempts - next}');
    } catch (_) {
      // Not counted: the backend's own lock-out still applies.
    }
    return next;
  }

  Future<void> clearMpinAttempts() async {
    try {
      await _storage.delete(key: _kMpinTries);
    } catch (_) {}
  }

  /// Removes the plain-text MPIN older builds saved.
  Future<void> deleteLegacyMpin() => _storage.delete(key: _kLegacyMpin);

  // ---------------------------------------------------------------------------
  // Session token
  // ---------------------------------------------------------------------------

  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);
  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<void> deleteToken() => _storage.delete(key: _kToken);

  // ---------------------------------------------------------------------------
  // Trusted device
  // ---------------------------------------------------------------------------

  /// This phone already proved [phone] with a texted code, so logging in
  /// again needs only the MPIN.
  Future<void> saveDevice(String phone, String key) async {
    await _storage.write(key: _kDevicePhone, value: phone);
    await _storage.write(key: _kDeviceKey, value: key);
  }

  /// (phone, key), or null when this phone is not trusted yet.
  Future<(String, String)?> readDevice() async {
    final phone = await _storage.read(key: _kDevicePhone);
    final key = await _storage.read(key: _kDeviceKey);
    if (phone == null || phone.isEmpty || key == null || key.isEmpty) {
      return null;
    }
    return (phone, key);
  }

  Future<void> deleteDevice() async {
    await _storage.delete(key: _kDeviceKey);
    await _storage.delete(key: _kDevicePhone);
  }

  // ---------------------------------------------------------------------------
  // Leaving
  // ---------------------------------------------------------------------------

  /// The backend refused the session token, or there is none. Only the
  /// token goes: this phone stays registered, so the next start opens
  /// "Enter your MPIN".
  Future<void> clearSession() => deleteToken();

  /// Explicit Logout or Delete account: forget the account completely.
  /// After this the app opens at Welcome again.
  Future<void> clearAll() => _storage.deleteAll();

  // ---------------------------------------------------------------------------
  // Hashing
  // ---------------------------------------------------------------------------

  static final Random _random = Random.secure();

  static String _newSalt() => base64Url.encode(
      List<int>.generate(16, (_) => _random.nextInt(256)));

  static String _hash(String mpin, String salt) {
    final pepper = utf8.encode(salt);
    var digest = sha256.convert(utf8.encode('$salt:$mpin'));
    for (var i = 1; i < _rounds; i++) {
      digest = sha256.convert([...digest.bytes, ...pepper]);
    }
    return base64Url.encode(digest.bytes);
  }

  /// Compares without telling how much of the hash matched.
  static bool _sameHash(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
