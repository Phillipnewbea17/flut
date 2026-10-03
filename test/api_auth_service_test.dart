import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/auth_service.dart';
import 'package:my_senior_app/storage/secure_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  ApiAuthService serviceFor(int status, String body, ApiClient Function(MockClient) make) {
    final api = make(MockClient((_) async => http.Response(body, status)));
    return ApiAuthService(api: api, vault: const SecureVault());
  }

  ApiClient client(MockClient mock) =>
      ApiClient(baseUrl: 'http://backend:8000', client: mock);

  test('a right code saves the token and sends it from then on', () async {
    late ApiClient api;
    final service = serviceFor(
      200,
      '{"token":"1|secret","account":{"phone":"9171234567"}}',
      (mock) => api = client(mock),
    );

    final ok = await service.verifyOtp(phone: '9171234567', code: '1234');

    expect(ok, true);
    expect(api.token, '1|secret');
    expect(await const SecureVault().readToken(), '1|secret');
  });

  test('a wrong code returns false', () async {
    final service = serviceFor(
      422,
      '{"message":"Wrong code. Please check and try again.","code":"wrong_code"}',
      client,
    );

    expect(await service.verifyOtp(phone: '9171234567', code: '1111'), false);
  });

  test('an expired code shows the server message', () async {
    final service = serviceFor(
      422,
      '{"message":"This code has expired. Please ask for a new one.","code":"expired"}',
      client,
    );

    expect(
      service.verifyOtp(phone: '9171234567', code: '1111'),
      throwsA(isA<AuthException>()
          .having((e) => e.message, 'message', contains('expired'))),
    );
  });

  test('asking for a code too soon shows the server message', () async {
    final service = serviceFor(
      429,
      '{"message":"Please wait a minute before asking for a new code."}',
      client,
    );

    expect(
      service.sendOtp('9171234567'),
      throwsA(isA<AuthException>()
          .having((e) => e.message, 'message', contains('wait a minute'))),
    );
  });
}
