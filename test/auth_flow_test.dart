import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/app_state/auth/login_flow.dart';
import 'package:my_senior_app/app_state/auth/password_reset_flow.dart';
import 'package:my_senior_app/app_state/auth/registration_flow.dart';
import 'package:my_senior_app/app_state/session_provider.dart';
import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/models/registration_name.dart';
import 'package:my_senior_app/services/auth_service.dart';
import 'package:my_senior_app/storage/auth_storage.dart';
import 'package:my_senior_app/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

const _email = 'ana@example.com';
const _password = 'Tahimik-2026';

const _name = RegistrationName(
  firstName: 'Rosela',
  middleName: 'Santos',
  lastName: 'Mabuhay',
  suffix: '',
  noMiddleName: false,
);

Matcher _authError(AuthError error) =>
    throwsA(isA<AuthException>().having((e) => e.error, 'error', error));

void main() {
  late FakeAuthBackend backend;
  late Preferences prefs;
  late SessionProvider session;
  late RegistrationFlow registration;
  late LoginFlow login;
  late PasswordResetFlow reset;
  late List<String> signedIn;
  late int wiped;

  /// Starts the app as main() does: one session, one LoginFlow, and the
  /// splash hook that fills Login in on a phone that already has an
  /// account.
  Future<SessionProvider> start() async {
    final s = SessionProvider(
      prefs: prefs,
      storage: const AuthStorage(),
      auth: backend,
    )
      ..afterSignIn = ((email, name) async => signedIn.add(email))
      ..addLogoutHook(() async => wiped++);
    login = LoginFlow(auth: backend, session: s);
    s.resumeLogin = (email, fullName) async {};
    await s.init();
    await s.finishSplash();
    return s;
  }

  /// Sign up from the first screen to "check your inbox".
  Future<void> signUp() async {
    await registration.saveName(_name);
    await registration.createAccount(
      rawEmail: _email,
      password: _password,
      confirmation: _password,
    );
  }

  /// Sign up, confirm the address the way tapping the link does, then log
  /// in: the whole way to Home.
  Future<void> signUpAndLogIn() async {
    await signUp();
    backend.verify(_email);
    await registration.goToLogin();
    await login.logIn(rawEmail: _email, password: _password);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await Preferences.load();
    backend = FakeAuthBackend();
    signedIn = [];
    wiped = 0;
    session = await start();
    registration = RegistrationFlow(auth: backend, session: session);
    reset = PasswordResetFlow(auth: backend, session: session);
  });

  group('Create Account name', () {
    test('first and last name are required', () {
      final errors = RegistrationName.validate(const RegistrationName(
          firstName: ' ',
          middleName: 'Santos',
          lastName: '',
          suffix: '',
          noMiddleName: false));
      expect(errors.keys, containsAll(['firstName', 'lastName']));
    });

    test('middle name is required unless "no middle name" is ticked', () {
      const noMiddle = RegistrationName(
          firstName: 'Rosela',
          middleName: '',
          lastName: 'Mabuhay',
          suffix: '',
          noMiddleName: false);
      expect(RegistrationName.validate(noMiddle), contains('middleName'));
      expect(
        RegistrationName.validate(const RegistrationName(
            firstName: 'Rosela',
            middleName: '',
            lastName: 'Mabuhay',
            suffix: '',
            noMiddleName: true)),
        isEmpty,
      );
    });

    test('ticking "no middle name" drops a typed middle name', () {
      const ticked = RegistrationName(
          firstName: 'Rosela',
          middleName: 'Santos',
          lastName: 'Mabuhay',
          suffix: '',
          noMiddleName: true);
      expect(ticked.toJson()['middleName'], isNull);
      expect(ticked.toJson()['noMiddleName'], isTrue);
    });

    test('letters only; suffix like Jr. or III', () {
      RegistrationName named(String first, String suffix) => RegistrationName(
          firstName: first,
          middleName: '',
          lastName: 'Mabuhay',
          suffix: suffix,
          noMiddleName: true);
      expect(RegistrationName.validate(named('R0sela', '')),
          contains('firstName'));
      expect(RegistrationName.validate(named("Ma. Ñiña O'Neil-Cruz", 'Jr.')),
          isEmpty);
      expect(RegistrationName.validate(named('Rosela', 'III')), isEmpty);
      expect(
          RegistrationName.validate(named('Rosela', '3rd!')), contains('suffix'));
    });

    test('each part may be long, but not the whole name', () {
      final part = 'a' * RegistrationName.maxNameLength;
      final errors = RegistrationName.validate(RegistrationName(
          firstName: part,
          middleName: part,
          lastName: part,
          suffix: '',
          noMiddleName: false));
      expect(errors['lastName'], contains('too long'));
      expect(errors.keys, ['lastName']);
    });

    test('a bad name never leaves the name step', () async {
      final errors = await registration.saveName(const RegistrationName(
          firstName: '',
          middleName: '',
          lastName: '',
          suffix: '',
          noMiddleName: false));
      expect(errors, isNotEmpty);
      expect(session.stage, OnboardingStage.signedOut);
    });
  });


  group('new user (Sign up)', () {
    test('name -> email + password -> check your inbox', () async {
      final errors = await registration.saveName(_name);
      expect(errors, isEmpty);
      expect(session.stage, OnboardingStage.credentials);

      await registration.createAccount(
        rawEmail: '  Ana@Example.COM ',
        password: _password,
        confirmation: _password,
      );

      // No session: the address has to be confirmed first.
      expect(session.stage, OnboardingStage.checkInbox);
      expect(signedIn, isEmpty);
      expect(backend.calls, ['register']);
      // The address was tidied up before it was sent.
      expect(backend.passwords.keys, [_email]);
      expect(backend.names[_email]!.lastName, 'Mabuhay');
      expect(backend.sentVerifications[_email], 1);
      expect(backend.unverified, contains(_email));
    });

    test('the email and password step needs the name first', () async {
      await registration.createAccount(
        rawEmail: _email,
        password: _password,
        confirmation: _password,
      );
      expect(session.stage, OnboardingStage.signedOut);
      expect(backend.calls, isEmpty);
    });

    test('an existing address is refused, no second account', () async {
      backend.passwords[_email] = _password;
      await registration.saveName(_name);
      await expectLater(
        registration.createAccount(
          rawEmail: _email,
          password: _password,
          confirmation: _password,
        ),
        _authError(AuthError.alreadyRegistered),
      );
      expect(session.stage, OnboardingStage.credentials);
    });

    test('an invalid address never reaches the backend', () async {
      await registration.saveName(_name);
      await expectLater(
        registration.createAccount(
          rawEmail: 'not-an-address',
          password: _password,
          confirmation: _password,
        ),
        _authError(AuthError.invalidEmail),
      );
      expect(backend.calls, isEmpty);
    });

    test('a short or obvious password never reaches the backend', () async {
      await registration.saveName(_name);
      for (final weak in ['short', 'password123', '12345678']) {
        await expectLater(
          registration.createAccount(
            rawEmail: _email,
            password: weak,
            confirmation: weak,
          ),
          _authError(AuthError.invalidPassword),
        );
      }
      expect(backend.calls, isEmpty);
    });

    test('two different passwords never reach the backend', () async {
      await registration.saveName(_name);
      await expectLater(
        registration.createAccount(
          rawEmail: _email,
          password: _password,
          confirmation: 'Something-Else-1',
        ),
        _authError(AuthError.passwordMismatch),
      );
      expect(backend.calls, isEmpty);
      expect(session.stage, OnboardingStage.credentials);
    });

    test('the password is not kept once the flow is left', () async {
      await signUp();
      backend.verify(_email);
      await registration.goToLogin();
      // "Resend email" has nothing to send with any more.
      await expectLater(
        registration.resendVerification(),
        _authError(AuthError.sessionExpired),
      );
    });
  });

  group('check your inbox', () {
    test('resend asks the backend again', () async {
      await signUp();
      expect(await registration.resendVerification(), isFalse);
      expect(backend.sentVerifications[_email], 2);
    });

    test('resend says so once the address was confirmed', () async {
      await signUp();
      backend.verify(_email);
      expect(await registration.resendVerification(), isTrue);
      // Nothing more was sent: there was nothing to confirm.
      expect(backend.sentVerifications[_email], 1);
    });

    test('"go to Login" fills the address in', () async {
      await signUp();
      await registration.goToLogin();
      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.login);
      expect(session.lastEmail, _email);
      // Signing up alone never makes this phone "registered".
      expect(session.isRegistered, isFalse);
    });
  });

  group('returning user (Login)', () {
    test('the right address and password open Home', () async {
      await signUpAndLogIn();
      expect(session.stage, OnboardingStage.completed);
      expect(signedIn, [_email]);
      expect(session.isRegistered, isTrue);
      expect(backend.sessionEmail, _email);
    });

    test('an unknown address and a wrong password read alike', () async {
      backend.passwords[_email] = _password;
      await expectLater(
        login.logIn(rawEmail: 'nobody@example.com', password: _password),
        _authError(AuthError.invalidCredentials),
      );
      await expectLater(
        login.logIn(rawEmail: _email, password: 'Wrong-Password-1'),
        _authError(AuthError.invalidCredentials),
      );
      expect(session.stage, OnboardingStage.signedOut);
      expect(signedIn, isEmpty);
    });

    test('an empty password never reaches the backend', () async {
      await expectLater(
        login.logIn(rawEmail: _email, password: ''),
        _authError(AuthError.invalidCredentials),
      );
      expect(backend.calls, isEmpty);
    });

    test('an invalid address never reaches the backend', () async {
      await expectLater(
        login.logIn(rawEmail: 'not-an-address', password: _password),
        _authError(AuthError.invalidEmail),
      );
      expect(backend.calls, isEmpty);
    });

    test('an unconfirmed address goes to check your inbox', () async {
      await signUp();
      await registration.goToLogin();

      await expectLater(
        login.logIn(rawEmail: _email, password: _password),
        _authError(AuthError.emailNotVerified),
      );
      expect(session.stage, OnboardingStage.checkInbox);
      expect(session.flow, AuthFlow.login);
      expect(login.unverifiedEmail, _email);

      // Resend works from here without typing anything again.
      expect(await login.resendVerification(), isFalse);
      expect(backend.sentVerifications[_email], 2);

      // Once confirmed, the same details log in.
      backend.verify(_email);
      await login.backToLogin();
      await login.logIn(rawEmail: _email, password: _password);
      expect(session.stage, OnboardingStage.completed);
    });

    test('too many wrong passwords locks the account', () async {
      backend.passwords[_email] = _password;
      backend.maxPasswordAttempts = 3;
      for (var i = 0; i < 2; i++) {
        await expectLater(
          login.logIn(rawEmail: _email, password: 'Wrong-Password-1'),
          _authError(AuthError.invalidCredentials),
        );
      }
      await expectLater(
        login.logIn(rawEmail: _email, password: 'Wrong-Password-1'),
        _authError(AuthError.accountLocked),
      );
      // Even the right password is refused while the lock lasts.
      await expectLater(
        login.logIn(rawEmail: _email, password: _password),
        _authError(AuthError.accountLocked),
      );
    });
  });

  group('forgot password', () {
    test('asks the backend for a link and remembers the address', () async {
      backend.passwords[_email] = _password;
      await reset.sendLink('  Ana@Example.COM ');

      expect(reset.sent, isTrue);
      expect(reset.email, _email);
      expect(backend.calls, ['forgot']);
      expect(backend.sentResetLinks[_email], 1);

      await reset.backToLogin();
      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.login);
      expect(session.lastEmail, _email);
    });

    test('an address with no account looks exactly the same', () async {
      await reset.sendLink('nobody@example.com');
      expect(reset.sent, isTrue);
      expect(backend.sentResetLinks, isEmpty);
    });

    test('an invalid address never reaches the backend', () async {
      await expectLater(
        reset.sendLink('not-an-address'),
        _authError(AuthError.invalidEmail),
      );
      expect(backend.calls, isEmpty);
      expect(reset.sent, isFalse);
    });

    test('nothing in the app can set the new password', () async {
      // The new password is typed on the page the emailed link opens, so
      // the flow has no method for it and the old one still works here.
      backend.passwords[_email] = _password;
      await reset.sendLink(_email);
      expect(backend.passwords[_email], _password);
    });
  });

  group('a phone that already has the account', () {
    test('closing and opening the app opens Login with the address',
        () async {
      await signUpAndLogIn();

      final next = await start();
      expect(next.isRegistered, isTrue);
      expect(next.lastEmail, _email);
      expect(next.stage, OnboardingStage.completed,
          reason: 'the saved session is still good');
    });

    test('an expired session asks for the password again', () async {
      await signUpAndLogIn();
      backend.sessionStatus = SessionStatus.expired;

      final next = await start();
      expect(next.stage, OnboardingStage.signedOut);
      expect(next.flow, AuthFlow.login);
      expect(next.isRegistered, isTrue);
      expect(next.lastEmail, _email);
      expect(next.takeNotice(), contains('log in again'));
    });

    test('a saved stage without a token is not trusted', () async {
      await prefs.setStage(OnboardingStage.completed);
      final next = await start();
      expect(next.stage, OnboardingStage.signedOut);
    });

    test('an old MPIN hash and device key are deleted', () async {
      FlutterSecureStorage.setMockInitialValues({
        'mpin': '4827',
        'mpin_hash': 'old-hash',
        'mpin_salt': 'old-salt',
        'mpin_tries': '2',
        'device_key': 'old-key',
        'device_email': _email,
      });
      await start();
      const storage = FlutterSecureStorage();
      for (final key in [
        'mpin',
        'mpin_hash',
        'mpin_salt',
        'mpin_tries',
        'device_key',
        'device_email',
      ]) {
        expect(await storage.read(key: key), isNull, reason: key);
      }
    });
  });

  group('session', () {
    test('expired while using the app: cleared, back to Login', () async {
      await signUpAndLogIn();
      await session.expireSession();

      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.login);
      expect(wiped, 1);
      // The phone stays registered, so Login opens with the address.
      expect(session.isRegistered, isTrue);
      expect(session.lastEmail, _email);
    });

    test('logout forgets this phone: Welcome again', () async {
      await signUpAndLogIn();
      await session.logout();

      expect(session.stage, OnboardingStage.signedOut);
      expect(session.isRegistered, isFalse);
      expect(session.lastEmail, isEmpty);
      expect(backend.calls, contains('sign-out'));
      expect(await const AuthStorage().readToken(), isNull);
    });

    test('change password checks the current one with the backend', () async {
      await signUpAndLogIn();

      // This screen has no email box, so the answer names only the
      // password.
      expect(
        await session.changePassword(
          currentPassword: 'Wrong-Password-1',
          newPassword: 'Bag-ong-Password-9',
        ),
        SessionProvider.wrongCurrentPassword,
      );
      expect(backend.passwords[_email], _password);

      expect(
        await session.changePassword(
          currentPassword: _password,
          newPassword: 'Bag-ong-Password-9',
        ),
        isNull,
      );
      expect(backend.passwords[_email], 'Bag-ong-Password-9');
    });

    test('change password checks the rules before sending', () async {
      await signUpAndLogIn();
      final before = backend.calls.length;

      expect(
        await session.changePassword(
          currentPassword: _password,
          newPassword: 'short',
        ),
        contains('at least'),
      );
      expect(backend.calls.length, before, reason: 'nothing was sent');
    });
  });
}
