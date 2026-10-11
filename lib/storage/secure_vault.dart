import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for the session token and this phone's device key.
///
/// The MPIN is NOT kept on the phone: the SCMS backend stores it (hashed)
/// and checks it. Older builds saved it here in plain text, so
/// [deleteLegacyMpin] removes that copy.
class SecureVault {
  static const _kLegacyMpin = 'mpin';
  static const _kToken = 'session_token';
  static const _kDeviceKey = 'device_key';
  static const _kDevicePhone = 'device_phone';

  final FlutterSecureStorage _storage;

  const SecureVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  // Session token
  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);
  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<void> deleteToken() => _storage.delete(key: _kToken);

  // Device key: this phone already proved [phone] with a texted code, so
  // logging in again needs only the MPIN. Kept when the user logs out.
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

  /// Removes the plain-text MPIN older builds saved.
  Future<void> deleteLegacyMpin() => _storage.delete(key: _kLegacyMpin);

  /// Forgets the session (log out). The device key stays, so the next login
  /// on this phone needs only the MPIN.
  Future<void> clear() async {
    final device = await readDevice();
    await _storage.deleteAll();
    if (device != null) await saveDevice(device.$1, device.$2);
  }
}
