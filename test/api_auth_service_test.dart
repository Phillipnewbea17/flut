import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('sign up', () {
    test('sends the name, address and password, and gets no session',
        () async {
      final b = _Backend(201, '{"ok":true,"email":"ana@example.com"}');
      await b.auth.register(
        name: const RegistrationName(
          firstName: ' Rosela ',
          middleName: 'ignored',
          lastName: 'Mabuhay',
          suffix: '',
          noMiddleName: true,
        ),
        email: 'ana@example.com',
        password: 'Tahimik-2026',
      );

      expect(b.last!.url.path, '/api/mobile/auth/register');
      expect(b.sent, {
        'firstName': 'Rosela',
        'middleName': null,
        'lastName': 'Mabuhay',
        'suffix': null,
        'noMiddleName': true,
        'email': 'ana@example.com',
        'password': 'Tahimik-2026',
      });

      // Signing up never signs in: the address has to be confirmed first.
      expect(b.api.token, isNull);
      expect(await const AuthStorage().readToken(), isNull);
    });

    test('an address that already has an account', () {
      final b = _Backend(
          409, '{"message":"Taken","code":"already_registered"}');
      expect(
        b.auth.register(
          name: const RegistrationName(
            firstName: 'Rosela',
            middleName: 'Santos',
            lastName: 'Mabuhay',
            suffix: '',
            noMiddleName: false,
          ),
          email: 'ana@example.com',
          password: 'Tahimik-2026',
        ),
        _authError(AuthError.alreadyRegistered),
      );
    });

    test('a password the backend refuses', () {
      final b =
          _Backend(422, '{"message":"Too short","code":"invalid_password"}');
      expect(
        b.auth.register(
          name: const RegistrationName(
            firstName: 'Rosela',
            middleName: 'Santos',
            lastName: 'Mabuhay',
            suffix: '',
            noMiddleName: false,
          ),
          email: 'ana@example.com',
          password: 'short',
        ),
        _authError(AuthError.invalidPassword),
      );
    });

    test('the confirmation email could not be sent', () {
      final b = _Backend(503, '{"message":"No mail","code":"email_failed"}');
      expect(
        b.auth.register(
          name: const RegistrationName(
            firstName: 'Rosela',
            middleName: 'Santos',
            lastName: 'Mabuhay',
            suffix: '',
            noMiddleName: false,
          ),
          email: 'ana@example.com',
          password: 'Tahimik-2026',
        ),
        _authError(AuthError.emailFailed),
      );
    });

    test('a name too long to save', () {
      final b = _Backend(422, '{"message":"Long","code":"name_too_long"}');
      expect(
        b.auth.register(
          name: const RegistrationName(
            firstName: 'Rosela',
            middleName: 'Santos',
            lastName: 'Mabuhay',
            suffix: '',
            noMiddleName: false,
          ),
          email: 'ana@example.com',
          password: 'Tahimik-2026',
        ),
        _authError(AuthError.nameTooLong),
      );
    });
  });

  group('log in', () {
    test('sends the address and password, and saves the session token',
        () async {
      final b = _Backend(200, '{"token":"2|secret"}');
      await b.auth.login(email: 'ana@example.com', password: 'Tahimik-2026');

      expect(b.last!.url.path, '/api/mobile/auth/login');
      expect(b.sent, {
        'email': 'ana@example.com',
        'password': 'Tahimik-2026',
      });
      expect(b.api.token, '2|secret');
      expect(await const AuthStorage().readToken(), '2|secret');
    });

    test('a wrong address or password reads the same either way', () async {
      final b = _Backend(422,
          '{"message":"Incorrect email or password.","code":"invalid_credentials"}');
      await expectLater(
        b.auth.login(email: 'ana@example.com', password: 'nope-nope-1'),
        throwsA(isA<AuthException>()
            .having((e) => e.error, 'error', AuthError.invalidCredentials)
            .having((e) => e.message, 'message',
                'Incorrect email or password.')),
      );
      expect(b.api.token, isNull);
    });

    test('an address that was never confirmed, with the address to show', () {
      final b = _Backend(
          403,
          '{"message":"Confirm first","code":"email_not_verified",'
              '"email":"ana@example.com"}');
      expect(
        b.auth.login(email: 'ana@example.com', password: 'Tahimik-2026'),
        throwsA(isA<AuthException>()
            .having((e) => e.error, 'error', AuthError.emailNotVerified)
            .having((e) => e.email, 'email', 'ana@example.com')),
      );
    });

    test('too many wrong passwords locks the account', () {
      final b = _Backend(423,
          '{"message":"Locked","code":"account_locked","retryAfter":900}');
      expect(
        b.auth.login(email: 'ana@example.com', password: 'nope-nope-1'),
        throwsA(isA<AuthException>()
            .having((e) => e.error, 'error', AuthError.accountLocked)
            .having((e) => e.retryAfter, 'retryAfter',
                const Duration(minutes: 15))),
      );
    });

    test('a deactivated account', () {
      final b = _Backend(
          403, '{"message":"Off","code":"account_deactivated"}');
      expect(
        b.auth.login(email: 'ana@example.com', password: 'Tahimik-2026'),
        _authError(AuthError.accountDeactivated),
      );
    });

    test('too many tries is a wait, never "check your details"', () {
      final b = _Backend(
          429,
          '{"message":"Too many tries","code":"too_many_attempts",'
              '"retryAfter":42}');
      expect(
        b.auth.login(email: 'ana@example.com', password: 'Tahimik-2026'),
        throwsA(isA<AuthException>()
            .having((e) => e.error, 'error', AuthError.tooManyAttempts)
            .having((e) => e.retryAfter, 'retryAfter',
                const Duration(seconds: 42))
            .having((e) => e.message, 'message', contains('wait'))),
      );
    });

    test('a 429 without a code is still a wait', () {
      final b = _Backend(429, '{"message":"Too Many Attempts."}');
      expect(
        b.auth.login(email: 'ana@example.com', password: 'Tahimik-2026'),
        _authError(AuthError.tooManyAttempts),
      );
    });
  });

  group('resend the confirmation email', () {
    test('needs the password, and says when it was already confirmed',
        () async {
      final b = _Backend(200, '{"ok":true,"alreadyVerified":true}');
      final already = await b.auth.resendVerification(
        email: 'ana@example.com',
        password: 'Tahimik-2026',
      );

      expect(b.last!.url.path, '/api/mobile/auth/verification/resend');
      expect(b.sent, {
        'email': 'ana@example.com',
        'password': 'Tahimik-2026',
      });
      expect(already, isTrue);
    });

    test('still waiting to be confirmed', () async {
      final b = _Backend(200, '{"ok":true,"alreadyVerified":false}');
      expect(
        await b.auth.resendVerification(
          email: 'ana@example.com',
          password: 'Tahimik-2026',
        ),
        isFalse,
      );
    });

    test('a wrong password is refused, so nobody else can make us send', () {
      final b = _Backend(
          422, '{"message":"No","code":"invalid_credentials"}');
      expect(
        b.auth.resendVerification(
          email: 'ana@example.com',
          password: 'guessing',
        ),
        _authError(AuthError.invalidCredentials),
      );
    });
  });

  group('forgot password', () {
    test('asks for the link and keeps no session', () async {
      final b = _Backend(200, '{"ok":true,"expiresInMinutes":30}');
      await b.auth.forgotPassword(email: 'ana@example.com');

      expect(b.last!.url.path, '/api/mobile/auth/password/forgot');
      expect(b.sent, {'email': 'ana@example.com'});
      expect(b.api.token, isNull);
    });

    test('an address with no account answers the same as one with', () async {
      final b = _Backend(200, '{"ok":true,"expiresInMinutes":30}');
      await b.auth.forgotPassword(email: 'nobody@example.com');
      expect(b.last!.url.path, '/api/mobile/auth/password/forgot');
    });

    test('the email could not be sent', () {
      final b = _Backend(503, '{"message":"No mail","code":"email_failed"}');
      expect(
        b.auth.forgotPassword(email: 'ana@example.com'),
        _authError(AuthError.emailFailed),
      );
    });
  });

  group('change the password', () {
    test('sends both passwords', () async {
      final b = _Backend(200, '{"ok":true}');
      await b.auth.changePassword(
        currentPassword: 'Tahimik-2026',
        password: 'Bag-ong-Password-9',
      );

      expect(b.last!.url.path, '/api/mobile/auth/password/change');
      expect(b.sent, {
        'currentPassword': 'Tahimik-2026',
        'password': 'Bag-ong-Password-9',
      });
    });

    test('a wrong current password', () {
      final b = _Backend(
          422, '{"message":"No","code":"invalid_credentials"}');
      expect(
        b.auth.changePassword(
          currentPassword: 'wrong-wrong-1',
          password: 'Bag-ong-Password-9',
        ),
        _authError(AuthError.invalidCredentials),
      );
    });

    test('the same password again', () {
      final b = _Backend(
          422, '{"message":"Same","code":"same_password"}');
      expect(
        b.auth.changePassword(
          currentPassword: 'Tahimik-2026',
          password: 'Tahimik-2026',
        ),
        _authError(AuthError.samePassword),
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
      auth.login(email: 'ana@example.com', password: 'Tahimik-2026'),
      _authError(AuthError.unavailable),
    );
    await expectLater(
      auth.register(
        name: const RegistrationName(
          firstName: 'Rosela',
          middleName: 'Santos',
          lastName: 'Mabuhay',
          suffix: '',
          noMiddleName: false,
        ),
        email: 'ana@example.com',
        password: 'Tahimik-2026',
      ),
      _authError(AuthError.unavailable),
    );
    await expectLater(
      auth.forgotPassword(email: 'ana@example.com'),
      _authError(AuthError.unavailable),
    );
    expect(await auth.checkSession(), SessionStatus.none);
  });
}
