import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for secrets: the MPIN and (later) the session token.
class SecureVault {
  static const _kMpin = 'mpin';
  static const _kToken = 'session_token';

  final FlutterSecureStorage _storage;

  const SecureVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  // MPIN
  Future<void> saveMpin(String pin) => _storage.write(key: _kMpin, value: pin);
  Future<String?> readMpin() => _storage.read(key: _kMpin);
  Future<bool> hasMpin() async => (await readMpin()) != null;

  Future<bool> verifyMpin(String pin) async => (await readMpin()) == pin;

  // Session token
  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);
  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> clear() => _storage.deleteAll();
}
