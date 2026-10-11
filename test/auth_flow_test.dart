import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/app_state/auth/login_flow.dart';
import 'package:my_senior_app/app_state/auth/mpin_reset_flow.dart';
import 'package:my_senior_app/app_state/auth/otp_challenge.dart';
import 'package:my_senior_app/app_state/auth/registration_flow.dart';
import 'package:my_senior_app/app_state/session_provider.dart';
import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/models/registration_name.dart';
import 'package:my_senior_app/services/auth_service.dart';
import 'package:my_senior_app/storage/preferences.dart';
import 'package:my_senior_app/storage/secure_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

const _phone = '9171234567';

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
  late MpinResetFlow reset;
  late List<String> signedIn;
  late int wiped;

  Future<SessionProvider> start() async {
    final s = SessionProvider(
      prefs: prefs,
      vault: const SecureVault(),
      auth: backend,
    )
      ..afterSignIn = ((phone, name) async => signedIn.add(phone))
      ..addLogoutHook(() async => wiped++);
    await s.init();
    await s.finishSplash();
    return s;
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
    login = LoginFlow(auth: backend, session: session);
    reset = MpinResetFlow(auth: backend, session: session);
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

  group('new user (Create Account)', () {
    test('name -> number -> code -> create + confirm MPIN -> Home', () async {
      expect(await registration.saveName(_name), isEmpty);
      expect(session.stage, OnboardingStage.phoneEntry);
      expect(session.flow, AuthFlow.register);

      backend.nextCode = '5190';
      await registration.requestRegistrationOtp('0917 123 4567');
      expect(session.stage, OnboardingStage.otpVerify);
      expect(backend.calls, ['code:register']);

      await registration.verifyRegistrationOtp('5190');
      expect(session.stage, OnboardingStage.mpinSetup);
      expect(backend.calls, isNot(contains('register')),
          reason: 'no account before the MPIN');

      await registration.createMpin('4827');
      expect(session.stage, OnboardingStage.mpinConfirm);
      expect(backend.mpins, isEmpty, reason: 'nothing sent before confirm');

      await registration.confirmMpin('4827');
      expect(backend.mpins[_phone], '4827');
      expect(backend.names[_phone]!.lastName, 'Mabuhay');
      expect(backend.names[_phone]!.middleName, 'Santos');
      expect(signedIn, [_phone]);
      // Account created -> Home (no other setup in between).
      expect(session.stage, OnboardingStage.completed);
      expect(prefs.stage, OnboardingStage.completed);
    });

    test('the mobile number step needs the name first', () async {
      await registration.requestRegistrationOtp(_phone);
      expect(backend.calls, isEmpty);
      expect(session.stage, OnboardingStage.signedOut);
    });

    test('an existing number is sent to Login, no new account', () async {
      backend.mpins[_phone] = '4827';
      await registration.saveName(_name);
      await expectLater(
        registration.requestRegistrationOtp(_phone),
        _authError(AuthError.alreadyRegistered),
      );
      expect(backend.calls, isNot(contains('register')));
    });

    test('an invalid number never reaches the backend', () async {
      await registration.saveName(_name);
      await expectLater(
        registration.requestRegistrationOtp('12345'),
        _authError(AuthError.invalidPhone),
      );
      expect(backend.calls, isEmpty);
    });

    test('mismatching MPINs go back to Create MPIN', () async {
      await registration.saveName(_name);
      backend.nextCode = '5190';
      await registration.requestRegistrationOtp(_phone);
      await registration.verifyRegistrationOtp('5190');
      await registration.createMpin('4827');

      await expectLater(
          registration.confirmMpin('4828'), _authError(AuthError.mpinMismatch));
      expect(session.stage, OnboardingStage.mpinSetup);
      expect(backend.mpins, isEmpty);
    });

    test('the MPIN cannot be the code or a weak one', () async {
      await registration.saveName(_name);
      backend.nextCode = '5190';
      await registration.requestRegistrationOtp(_phone);
      await registration.verifyRegistrationOtp('5190');

      expect(registration.validateNewMpin('5190'), isNotNull);
      expect(registration.validateNewMpin('1234'), isNotNull);
      await expectLater(
          registration.createMpin('0000'), _authError(AuthError.weakMpin));
      expect(session.stage, OnboardingStage.mpinSetup);
    });
  });

  group('code (OTP)', () {
    setUp(() async {
      backend.mpins[_phone] = '4827';
      backend.nextCode = '5190';
      await login.requestLoginOtp(_phone);
    });

    test('an incorrect code keeps the user on the code screen', () async {
      await expectLater(
          login.verifyLoginOtp('0000'), _authError(AuthError.wrongCode));
      expect(session.stage, OnboardingStage.otpVerify);
    });

    test('letters or a short code are never sent', () async {
      await expectLater(
          login.verifyLoginOtp('51a0'), _authError(AuthError.wrongCode));
      await expectLater(
          login.verifyLoginOtp('519'), _authError(AuthError.wrongCode));
      expect(backend.calls.where((c) => c == 'verify'), isEmpty);
    });

    test('an expired code', () async {
      backend.codeExpired = true;
      await expectLater(
          login.verifyLoginOtp('5190'), _authError(AuthError.codeExpired));
    });

    test('a code past its time is not sent at all', () async {
      backend.nextCode = '6011';
      // A code that ran out a second ago.
      backend.ticket = const OtpTicket(expiresIn: Duration(seconds: -1));
      await login.resendOtp();
      expect(login.codeExpired, isTrue);
      await expectLater(
          login.verifyLoginOtp('6011'), _authError(AuthError.codeExpired));
      expect(backend.calls.where((c) => c == 'verify'), isEmpty);
    });

    test('too many wrong codes locks this code until a new one', () async {
      backend.maxCodeAttempts = 99; // the app's own limit is reached first
      for (var i = 1; i < OtpChallenge.maxAttempts; i++) {
        await expectLater(
            login.verifyLoginOtp('0000'), _authError(AuthError.wrongCode));
      }
      await expectLater(
          login.verifyLoginOtp('0000'), _authError(AuthError.tooManyAttempts));
      await expectLater(
          login.verifyLoginOtp('5190'), _authError(AuthError.tooManyAttempts));

      backend.nextCode = '7302';
      await login.resendOtp();
      expect(login.codeLocked, isFalse);
      await expectLater(
          login.verifyLoginOtp('5190'), _authError(AuthError.wrongCode));
      await login.verifyLoginOtp('7302');
      expect(session.stage, OnboardingStage.mpinEntry);
    });

    test('change number goes back to the number screen', () async {
      await login.changeNumber();
      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.login);
    });
  });

  group('returning user (Login)', () {
    setUp(() {
      backend.mpins[_phone] = '4827';
      backend.nextCode = '5190';
    });

    Future<void> codeOk() async {
      await login.requestLoginOtp(_phone);
      await login.verifyLoginOtp('5190');
    }

    test('unknown number: create an account first', () async {
      await expectLater(
        login.requestLoginOtp('9998887777'),
        _authError(AuthError.accountNotFound),
      );
    });

    test('code then existing MPIN opens Home; nothing is created', () async {
      await codeOk();
      expect(session.stage, OnboardingStage.mpinEntry);

      await login.verifyMpin('4827');
      expect(session.stage, OnboardingStage.completed);
      expect(prefs.stage, OnboardingStage.completed);
      expect(signedIn, [_phone]);
      expect(backend.calls, isNot(contains('register')));
      expect(backend.names, isEmpty, reason: 'Login never asks for a name');
    });

    test('an incorrect MPIN does not sign in', () async {
      await codeOk();
      await expectLater(
          login.verifyMpin('4828'), _authError(AuthError.wrongMpin));
      expect(session.stage, OnboardingStage.mpinEntry);
      expect(backend.sessionPhone, isNull);

      await login.verifyMpin('4827');
      expect(session.stage, OnboardingStage.completed);
    });

    test('too many incorrect MPINs locks the account', () async {
      await codeOk();
      for (var i = 1; i < backend.maxMpinAttempts; i++) {
        await expectLater(
            login.verifyMpin('4828'), _authError(AuthError.wrongMpin));
      }
      await expectLater(
          login.verifyMpin('4828'), _authError(AuthError.mpinLocked));
    });

    test('the MPIN cannot be sent without a verified code', () async {
      await expectLater(login.verifyMpin('4827'),
          _authError(AuthError.verificationExpired));
      expect(backend.calls, isNot(contains('login')));
    });
  });

  group('Forgot MPIN', () {
    test('code -> new MPIN -> confirm -> Login, not signed in', () async {
      backend.mpins[_phone] = '4827';
      backend.nextCode = '5190';

      await reset.requestResetOtp(_phone);
      await reset.verifyResetOtp('5190');
      expect(session.stage, OnboardingStage.mpinSetup);
      await reset.createMpin('3958');
      expect(session.stage, OnboardingStage.mpinConfirm);
      await reset.confirmMpin('3958');

      expect(backend.mpins[_phone], '3958');
      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.login);
      expect(session.lastPhone, _phone);
      expect(backend.sessionPhone, isNull);
      expect(signedIn, isEmpty);
      expect(session.takeNotice(), contains('MPIN was changed'));

      backend.nextCode = '6011';
      await login.requestLoginOtp(_phone);
      await login.verifyLoginOtp('6011');
      await expectLater(
          login.verifyMpin('4827'), _authError(AuthError.wrongMpin));
      await login.verifyMpin('3958');
      expect(session.stage, OnboardingStage.completed);
    });

    test('from the MPIN screen', () async {
      await session.startFlow(AuthFlow.resetMpin);
      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.resetMpin);
    });
  });

  group('session', () {
    Future<void> signIn() async {
      backend.mpins[_phone] = '4827';
      backend.nextCode = '5190';
      await login.requestLoginOtp(_phone);
      await login.verifyLoginOtp('5190');
      await login.verifyMpin('4827');
      await const SecureVault().saveToken('1|secret');
    }

    test('a valid saved session opens Home on the next start', () async {
      await signIn();
      final next = await start();
      expect(next.stage, OnboardingStage.completed);
    });

    test('an expired saved session goes to Login', () async {
      await signIn();
      backend.sessionStatus = SessionStatus.expired;
      final next = await start();
      expect(next.stage, OnboardingStage.signedOut);
      expect(next.flow, AuthFlow.login);
      expect(next.takeNotice(), contains('session has ended'));
    });

    test('a saved stage without a token is not trusted', () async {
      await prefs.setStage(OnboardingStage.completed);
      final next = await start();
      expect(next.stage, OnboardingStage.signedOut);
    });

    test('expired while using the app: cleared, back to Login', () async {
      await signIn();
      await session.expireSession();
      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.login);
      expect(wiped, 1);
      expect(await const SecureVault().readToken(), isNull);
    });

    test('logout clears this phone only, then Login', () async {
      await signIn();
      await session.logout();
      expect(session.stage, OnboardingStage.signedOut);
      expect(session.flow, AuthFlow.login);
      expect(backend.calls.last, 'sign-out');
      expect(wiped, 1);
      expect(await const SecureVault().readToken(), isNull);
      expect(backend.mpins[_phone], '4827');
    });

    test('change MPIN checks the current one with the backend', () async {
      await signIn();
      expect(await session.changeMpin(currentMpin: '0000', newMpin: '3958'),
          isNotNull);
      expect(await session.changeMpin(currentMpin: '4827', newMpin: '1234'),
          isNotNull);
      expect(await session.changeMpin(currentMpin: '4827', newMpin: '3958'),
          isNull);
      expect(backend.mpins[_phone], '3958');
    });

    test('an old plain-text MPIN on the phone is deleted', () async {
      FlutterSecureStorage.setMockInitialValues({'mpin': '4827'});
      await start();
      expect(await const FlutterSecureStorage().read(key: 'mpin'), isNull);
    });
  });
}
