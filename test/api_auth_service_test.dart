import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/models/registration_name.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/auth_service.dart';
import 'package:my_senior_app/storage/auth_storage.dart';

/// One canned answer, and the last request the "backend" received.
class _Backend {
  _Backend(this.status, this.body);
  final int status;
  final String body;
  http.Request? last;

  late final ApiClient api = ApiClient(
    baseUrl: 'http://backend:8000',
    client: MockClient((request) async {
      last = request;
      return http.Response(body, status);
    }),
  );

  late final ApiAuthService auth =
      ApiAuthService(api: api, storage: const AuthStorage());

  Map<String, dynamic> get sent =>
      jsonDecode(last!.body) as Map<String, dynamic>;
}

Matcher _authError(AuthError error) =>
    throwsA(isA<AuthException>().having((e) => e.error, 'error', error));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('request a code', () {
    test('sends the phone and the purpose, reads the timers', () async {
      final b = _Backend(200, '{"expiresIn":180,"resendIn":45}');
      final ticket =
          await b.auth.requestOtp(phone: '9171234567', flow: AuthFlow.register);

      expect(b.last!.url.path, '/api/mobile/auth/code');
      expect(b.sent, {'phone': '9171234567', 'purpose': 'register'});
      expect(ticket.expiresIn, const Duration(seconds: 180));
      expect(ticket.resendIn, const Duration(seconds: 45));
    });

    test('purpose for login and Forgot MPIN', () async {
      final b = _Backend(200, '{}');
      await b.auth.requestOtp(phone: '9171234567', flow: AuthFlow.login);
      expect(b.sent['purpose'], 'login');
      await b.auth.requestOtp(phone: '9171234567', flow: AuthFlow.resetMpin);
      expect(b.sent['purpose'], 'reset_mpin');
    });

    test('default timers when the backend does not say', () async {
      final ticket = await _Backend(200, '{}')
          .auth
          .requestOtp(phone: '9171234567', flow: AuthFlow.login);
      expect(ticket.expiresIn, OtpTicket.defaultExpiry);
      expect(ticket.resendIn, OtpTicket.defaultResend);
    });

    test('registering an existing number', () {
      final b = _Backend(409,
          '{"message":"Phone taken","code":"already_registered"}');
      expect(
        b.auth.requestOtp(phone: '9171234567', flow: AuthFlow.register),
        _authError(AuthError.alreadyRegistered),
      );
    });

    test('logging in with an unknown number', () {
      final b = _Backend(404,
          '{"message":"No account","code":"account_not_found"}');
      expect(
        b.auth.requestOtp(phone: '9171234567', flow: AuthFlow.login),
        _authError(AuthError.accountNotFound),
      );
    });

    test('resend too soon (429)', () {
      final b = _Backend(429, '{"message":"Too Many Attempts."}');
      expect(
        b.auth.requestOtp(phone: '9171234567', flow: AuthFlow.login),
        _authError(AuthError.tooManyRequests),
      );
    });

    test('a backend without the route is "not available"', () {
      final b = _Backend(404, '{"message":"Not Found"}');
      expect(
        b.auth.requestOtp(phone: '9171234567', flow: AuthFlow.login),
        _authError(AuthError.unavailable),
      );
    });
  });

  group('verify the code', () {
    test('a right code returns a verification token, not a session',
        () async {
      final b = _Backend(200, '{"verificationToken":"v-1","expiresIn":600}');
      final token = await b.auth.verifyOtp(
          phone: '9171234567', code: '4827', flow: AuthFlow.login);

      expect(token, 'v-1');
      expect(b.sent,
          {'phone': '9171234567', 'code': '4827', 'purpose': 'login'});
      expect(b.api.token, isNull);
      expect(await const AuthStorage().readToken(), isNull);
    });

    test('an incorrect code, with tries left', () {
      final b = _Backend(422,
          '{"message":"Wrong","code":"wrong_code","attemptsLeft":2}');
      expect(
        b.auth.verifyOtp(
            phone: '9171234567', code: '1111', flow: AuthFlow.login),
        throwsA(isA<AuthException>()
            .having((e) => e.error, 'error', AuthError.wrongCode)
            .having((e) => e.attemptsLeft, 'attemptsLeft', 2)
            .having((e) => e.message, 'message',
                startsWith('That code is incorrect.'))),
      );
    });

    test('an expired code', () {
      final b = _Backend(422, '{"message":"Expired","code":"expired"}');
      expect(
        b.auth.verifyOtp(
            phone: '9171234567', code: '1111', flow: AuthFlow.login),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            'This code has expired. Please request a new code.')),
      );
    });

    test('too many attempts', () {
      final b =
          _Backend(429, '{"message":"Locked","code":"too_many_attempts"}');
      expect(
        b.auth.verifyOtp(
            phone: '9171234567', code: '1111', flow: AuthFlow.login),
        _authError(AuthError.tooManyAttempts),
      );
    });

    test('an old backend that signs in with the code alone is refused',
        () async {
      final b = _Backend(200, '{"token":"1|session"}');
      await expectLater(
        b.auth.verifyOtp(
            phone: '9171234567', code: '4827', flow: AuthFlow.login),
        _authError(AuthError.unavailable),
      );
      expect(b.api.token, isNull);
    });

    test("the server's own words are never shown", () async {
      final b = _Backend(
          422, '{"message":"SQLSTATE[42S22] column otp_hash","code":"x"}');
      try {
        await b.auth.verifyOtp(
            phone: '9171234567', code: '1111', flow: AuthFlow.login);
        fail('should throw');
      } on AuthException catch (e) {
        expect(e.message, isNot(contains('SQLSTATE')));
        expect(e.error, AuthError.unknown);
      }
    });
  });

  group('MPIN', () {
    test('register sends the name and saves the session token', () async {
      final b = _Backend(201, '{"token":"1|secret"}');
      await b.auth.register(
        name: const RegistrationName(
          firstName: ' Rosela ',
          middleName: 'ignored',
          lastName: 'Mabuhay',
          suffix: '',
          noMiddleName: true,
        ),
        phone: '9171234567',
        verificationToken: 'v-1',
        mpin: '4827',
      );

      expect(b.last!.url.path, '/api/mobile/auth/register');
      expect(b.sent, {
        'firstName': 'Rosela',
        'middleName': null,
        'lastName': 'Mabuhay',
        'suffix': null,
        'noMiddleName': true,
        'phone': '9171234567',
        'verificationToken': 'v-1',
        'mpin': '4827',
      });
      expect(b.api.token, '1|secret');
      expect(await const AuthStorage().readToken(), '1|secret');
    });

    test('correct MPIN login saves the session token', () async {
      final b = _Backend(200, '{"token":"2|secret"}');
      await b.auth.login(
          phone: '9171234567', verificationToken: 'v-1', mpin: '4827');
      expect(b.last!.url.path, '/api/mobile/auth/login');
      expect(b.api.token, '2|secret');
    });

    test('incorrect MPIN login', () async {
      final b = _Backend(422,
          '{"message":"Wrong","code":"wrong_mpin","attemptsLeft":2}');
      await expectLater(
        b.auth.login(
            phone: '9171234567', verificationToken: 'v-1', mpin: '4828'),
        throwsA(isA<AuthException>()
            .having((e) => e.error, 'error', AuthError.wrongMpin)
            .having((e) => e.message, 'message',
                startsWith('Your MPIN is incorrect.'))),
      );
      expect(b.api.token, isNull);
    });

    test('locked MPIN', () {
      final b = _Backend(423, '{"message":"Locked","code":"mpin_locked"}');
      expect(
        b.auth.login(
            phone: '9171234567', verificationToken: 'v-1', mpin: '4828'),
        _authError(AuthError.mpinLocked),
      );
    });

    test('Forgot MPIN resets without signing in', () async {
      final b = _Backend(200, '{"ok":true}');
      await b.auth.resetMpin(
          phone: '9171234567', verificationToken: 'v-1', mpin: '5190');
      expect(b.last!.url.path, '/api/mobile/auth/mpin/reset');
      expect(b.api.token, isNull);
    });

    test('a used or old verification token', () {
      final b = _Backend(
          422, '{"message":"Expired","code":"verification_expired"}');
      expect(
        b.auth.resetMpin(
            phone: '9171234567', verificationToken: 'v-1', mpin: '5190'),
        _authError(AuthError.verificationExpired),
      );
    });
  });

  group('session', () {
    test('a valid session', () async {
      final b = _Backend(200, '{"firstName":"Rosela"}');
      b.api.token = '1|secret';
      expect(await b.auth.checkSession(), SessionStatus.valid);
      expect(b.last!.headers['Authorization'], 'Bearer 1|secret');
    });

    test('an expired session is forgotten', () async {
      await const AuthStorage().saveToken('1|old');
      final b = _Backend(401, '{"message":"Unauthenticated."}');
      expect(await b.auth.checkSession(), SessionStatus.expired);
      expect(b.api.token, isNull);
      expect(await const AuthStorage().readToken(), isNull);
    });

    test('no token at all', () async {
      expect(await _Backend(200, '{}').auth.checkSession(), SessionStatus.none);
    });

    test('offline keeps the token', () async {
      final api = ApiClient(
        baseUrl: 'http://backend:8000',
        client: MockClient((_) async => throw http.ClientException('down')),
      )..token = '1|secret';
      final auth = ApiAuthService(api: api, storage: const AuthStorage());
      expect(await auth.checkSession(), SessionStatus.offline);
      expect(api.token, '1|secret');
    });

    test('logout tells the backend and forgets the token', () async {
      await const AuthStorage().saveToken('1|secret');
      final b = _Backend(200, '{"ok":true}');
      b.api.token = '1|secret';
      await b.auth.signOut();
      expect(b.last!.url.path, '/api/mobile/auth/sign-out');
      expect(b.api.token, isNull);
      expect(await const AuthStorage().readToken(), isNull);
    });

    test('a refused token on a signed-in request reports the expiry', () async {
      var expired = 0;
      final b = _Backend(401, '{"message":"Unauthenticated."}');
      b.api
        ..token = '1|secret'
        ..onSessionExpired = () => expired++;
      await expectLater(b.api.get('/profile'), throwsA(isA<ApiException>()));
      expect(expired, 1);

      // Sign-in requests never do.
      await expectLater(
          b.api.post('/auth/login', {}), throwsA(isA<ApiException>()));
      expect(expired, 1);
    });
  });

  test('without a backend nobody can sign in', () async {
    const auth = UnavailableAuthService();
    await expectLater(
      auth.requestOtp(phone: '9171234567', flow: AuthFlow.login),
      _authError(AuthError.unavailable),
    );
    await expectLater(
      auth.verifyOtp(phone: '9171234567', code: '9109', flow: AuthFlow.login),
      _authError(AuthError.unavailable),
    );
    expect(await auth.checkSession(), SessionStatus.none);
  });
}
