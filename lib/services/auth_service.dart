import '../storage/secure_vault.dart';
import 'api_client.dart';

/// Thrown when sending or checking a code fails. [message] is written in
/// plain words so a screen can show it to the user as-is.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// What the login screens need from "the server".
/// Screens only talk to this interface, so switching from the fake service
/// to a real one later does not change any screen code.
abstract class AuthService {
  /// Text a 4-digit code to [phone] (10 digits, no +63).
  Future<void> sendOtp(String phone);

  /// Returns true when [code] is the right code for [phone].
  Future<bool> verifyOtp({required String phone, required String code});
}

/// Pretend service for building the app without a backend.
/// The correct code is always [demoCode] (the one in your screenshots).
class FakeAuthService implements AuthService {
  static const String demoCode = '9109';

  @override
  Future<void> sendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (phone.length != 10 || !phone.startsWith('9')) {
      throw const AuthException('Please enter a valid mobile number.');
    }
  }

  @override
  Future<bool> verifyOtp({required String phone, required String code}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return code == demoCode;
  }
}

/// Real sign-in through the SCMS backend: the code is texted to the phone
/// (or written to the server log while testing). The token it returns is
/// kept in [SecureVault] and sent with every request by [ApiClient].
class ApiAuthService implements AuthService {
  ApiAuthService({required ApiClient api, required SecureVault vault})
      : _api = api,
        _vault = vault;

  final ApiClient _api;
  final SecureVault _vault;

  @override
  Future<void> sendOtp(String phone) async {
    try {
      await _api.post('/auth/code', {'phone': phone});
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<bool> verifyOtp({required String phone, required String code}) async {
    final Map<String, dynamic> result;
    try {
      result = await _api.post('/auth/verify', {'phone': phone, 'code': code});
    } on ApiException catch (e) {
      if (e.code == 'wrong_code') return false;
      throw AuthException(e.message);
    }
    final token = result['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthException('Something went wrong. Please try again.');
    }
    await _vault.saveToken(token);
    _api.token = token;
    return true;
  }
}
