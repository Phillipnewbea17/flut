import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/app_state/auth/login_flow.dart';
import 'package:my_senior_app/app_state/auth/mpin_reset_flow.dart';
import 'package:my_senior_app/app_state/auth/registration_flow.dart';
import 'package:my_senior_app/app_state/session_provider.dart';
import 'package:my_senior_app/app_state/user_provider.dart';
import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/models/registration_name.dart';
import 'package:my_senior_app/services/auth_service.dart';
import 'package:my_senior_app/storage/preferences.dart';
import 'package:my_senior_app/storage/auth_storage.dart';
import 'package:my_senior_app/views/onboarding/mpin_view.dart';
import 'package:my_senior_app/views/onboarding/otp_verify_view.dart';
import 'package:my_senior_app/views/onboarding/register_name_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

const _phone = '9551402068';

const _name = RegistrationName(
  firstName: 'Rosela',
  middleName: '',
  lastName: 'Mabuhay',
  suffix: '',
  noMiddleName: true,
);

/// The session, the fake backend and the three sign-in flows.
class _Auth {
  _Auth(this.session, this.backend)
      : registration = RegistrationFlow(auth: backend, session: session),
        login = LoginFlow(auth: backend, session: session),
        reset = MpinResetFlow(auth: backend, session: session);

  final SessionProvider session;
  final FakeAuthBackend backend;
  final RegistrationFlow registration;
  final LoginFlow login;
  final MpinResetFlow reset;
}

/// A flow that has just sent a code; [verify] also enters it.
Future<_Auth> _atCode(
  WidgetTester tester,
  AuthFlow flow, {
  bool verify = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  late _Auth auth;
  final backend = FakeAuthBackend()..nextCode = '5190';
  if (flow != AuthFlow.register) backend.mpins[_phone] = '4827';
  await tester.runAsync(() async {
    final prefs = await Preferences.load();
    auth = _Auth(
      SessionProvider(prefs: prefs, storage: const AuthStorage(), auth: backend),
      backend,
    );
    switch (flow) {
      case AuthFlow.register:
        await auth.registration.saveName(_name);
        await auth.registration.requestRegistrationOtp(_phone);
        if (verify) await auth.registration.verifyRegistrationOtp('5190');
      case AuthFlow.login:
        await auth.login.requestLoginOtp(_phone);
        if (verify) await auth.login.verifyLoginOtp('5190');
      case AuthFlow.resetMpin:
        await auth.reset.requestResetOtp(_phone);
        if (verify) await auth.reset.verifyResetOtp('5190');
    }
  });
  return auth;
}

Future<void> _pump(
  WidgetTester tester,
  _Auth auth,
  Widget screen, {
  double textScale = 1.0,
  double height = 1400,
}) async {
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await tester.runAsync(Preferences.load);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth.session),
        ChangeNotifierProvider.value(value: UserProvider(prefs!)),
        Provider.value(value: auth.registration),
        Provider.value(value: auth.login),
        Provider.value(value: auth.reset),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(360, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(home: screen),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapKeys(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
}

/// Taps a button whose work talks to the (fake) backend.
Future<void> _tapAndWait(WidgetTester tester, String label) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(label));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

/// Leaves the countdown timer cleanly.
Future<void> _leave(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  group('Create Account name screen', () {
    testWidgets('names are checked before the mobile number', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeAuthBackend();
      final prefs = await tester.runAsync(Preferences.load);
      final auth = _Auth(
        SessionProvider(prefs: prefs!, storage: const AuthStorage(), auth: backend),
        backend,
      );
      await _pump(tester, auth, const RegisterNameView(), height: 1600);
      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('I have no middle name'), findsOneWidget);

      await _tapAndWait(tester, 'CONTINUE');
      expect(find.text('Please enter your first name.'), findsOneWidget);
      expect(find.text('Please enter your last name.'), findsOneWidget);
      expect(auth.session.stage, OnboardingStage.signedOut);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Rosela');
      await tester.enterText(fields.at(2), 'Mabuhay');
      await tester.tap(find.text('I have no middle name'));
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(1)).enabled, isFalse,
          reason: 'Middle Name is disabled when the box is ticked');

      await _tapAndWait(tester, 'CONTINUE');
      expect(auth.session.stage, OnboardingStage.phoneEntry);
      expect(auth.registration.name!.noMiddleName, isTrue);
      expect(auth.registration.name!.lastName, 'Mabuhay');
      expect(backend.calls, isEmpty, reason: 'nothing sent yet');
    });
  });

  group('code screen', () {
    testWidgets('fits a small phone with big text, masks the number',
        (tester) async {
      final auth = await _atCode(tester, AuthFlow.register);
      await _pump(tester, auth, const OtpVerifyView(flow: AuthFlow.register),
          textScale: 1.3, height: 780);

      // Any overflow stripe would be reported here as an exception.
      expect(tester.takeException(), isNull);
      expect(find.text('Verify Your Mobile Number'), findsOneWidget);
      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.textContaining('+63 9XX XXX 2068', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('551 40', findRichText: true), findsNothing);
      // The countdowns read the real clock, so allow a second or two.
      expect(find.textContaining(RegExp(r'^Resend OTP in (1:00|0:5\d)$')),
          findsOneWidget);
      expect(find.textContaining(RegExp(r'^Code expires in (5:00|4:5\d)$')),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('Verify needs exactly 4 numbers; no letters', (tester) async {
      final auth = await _atCode(tester, AuthFlow.login);
      await _pump(tester, auth, const OtpVerifyView(flow: AuthFlow.login));
      expect(find.text('Verify Your Login'), findsOneWidget);

      Finder verifyButton() => find.ancestor(
          of: find.text('VERIFY'), matching: find.byType(InkWell)).first;
      expect(tester.widget<InkWell>(verifyButton()).onTap, isNull);

      await tester.enterText(find.byType(TextField), '5a1');
      await tester.pump();
      expect(tester.widget<InkWell>(verifyButton()).onTap, isNull,
          reason: '"5a1" becomes "51"');

      await tester.enterText(find.byType(TextField), '519055');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '5190', reason: 'stops at 4 numbers');
      expect(tester.widget<InkWell>(verifyButton()).onTap, isNotNull);
      await _leave(tester);
    });

    testWidgets('an incorrect code shows the message and clears the boxes',
        (tester) async {
      final auth = await _atCode(tester, AuthFlow.login);
      await _pump(tester, auth, const OtpVerifyView(flow: AuthFlow.login));

      await tester.enterText(find.byType(TextField), '0000');
      await tester.pump();
      await _tapAndWait(tester, 'VERIFY');

      expect(find.textContaining('That code is incorrect. Please try again.'),
          findsOneWidget);
      expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(auth.session.stage, OnboardingStage.otpVerify);
      await _leave(tester);
    });

    testWidgets('Resend OTP appears when the wait is over', (tester) async {
      final auth = await _atCode(tester, AuthFlow.login);
      // The server allows a new code after 1 second.
      await tester.runAsync(() async {
        auth.backend.ticket = const OtpTicket(resendIn: Duration(seconds: 1));
        await auth.login.resendOtp();
      });
      await _pump(tester, auth, const OtpVerifyView(flow: AuthFlow.login));
      expect(find.text('Resend OTP'), findsNothing);
      expect(find.textContaining(RegExp(r'^Resend OTP in 0:0[01]$')),
          findsOneWidget);

      // The countdown reads the real clock.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1100)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend OTP'), findsOneWidget);

      auth.backend.nextCode = '7302';
      await _tapAndWait(tester, 'Resend OTP');
      expect(auth.backend.calls.where((c) => c == 'code:login'), hasLength(3));
      await _leave(tester);
    });
  });

  group('MPIN screens', () {
    testWidgets('create: Continue only with 4 numbers, shown as dots',
        (tester) async {
      final auth = await _atCode(tester, AuthFlow.register, verify: true);
      await _pump(tester, auth,
          const MpinView(mode: MpinMode.create, flow: AuthFlow.register));
      expect(find.text('Create Your MPIN'), findsOneWidget);
      expect(find.text('Step 4 of 4'), findsOneWidget);

      Finder continueButton() => find.ancestor(
          of: find.text('CONTINUE'), matching: find.byType(InkWell)).first;
      await _tapKeys(tester, '482');
      expect(tester.widget<InkWell>(continueButton()).onTap, isNull);
      await _tapKeys(tester, '7');
      expect(tester.widget<InkWell>(continueButton()).onTap, isNotNull);
      expect(find.text('●'), findsNWidgets(4));
      expect(find.text('4827'), findsNothing);
      expect(tester.takeException(), isNull);

      await _tapAndWait(tester, 'CONTINUE');
      expect(auth.session.stage, OnboardingStage.mpinConfirm);
    });

    testWidgets('create: a weak MPIN is refused', (tester) async {
      final auth = await _atCode(tester, AuthFlow.register, verify: true);
      await _pump(tester, auth,
          const MpinView(mode: MpinMode.create, flow: AuthFlow.register));

      await _tapKeys(tester, '1234');
      await _tapAndWait(tester, 'CONTINUE');
      expect(find.text('Please avoid easy numbers like 1234.'), findsOneWidget);
      expect(auth.session.stage, OnboardingStage.mpinSetup);
    });

    testWidgets('confirm: a different MPIN is a mismatch', (tester) async {
      final auth = await _atCode(tester, AuthFlow.register, verify: true);
      await tester.runAsync(() => auth.registration.createMpin('4827'));
      await _pump(tester, auth,
          const MpinView(mode: MpinMode.confirm, flow: AuthFlow.register));
      expect(find.text('Confirm Your MPIN'), findsOneWidget);

      await _tapKeys(tester, '4828');
      await _tapAndWait(tester, 'CREATE ACCOUNT');
      expect(find.text('The MPINs do not match. Please try again.'),
          findsOneWidget);
      expect(auth.session.stage, OnboardingStage.mpinSetup);
      expect(auth.backend.calls, isNot(contains('register')));
    });

    testWidgets('confirm: matching MPINs create the account -> Home',
        (tester) async {
      final auth = await _atCode(tester, AuthFlow.register, verify: true);
      await tester.runAsync(() => auth.registration.createMpin('4827'));
      await _pump(tester, auth,
          const MpinView(mode: MpinMode.confirm, flow: AuthFlow.register));

      await _tapKeys(tester, '4827');
      await _tapAndWait(tester, 'CREATE ACCOUNT');

      expect(auth.backend.mpins[_phone], '4827');
      expect(auth.backend.names[_phone]!.firstName, 'Rosela');
      expect(auth.session.stage, OnboardingStage.completed);
    });

    testWidgets('enter: an incorrect MPIN shows the message', (tester) async {
      final auth = await _atCode(tester, AuthFlow.login, verify: true);
      await _pump(tester, auth,
          const MpinView(mode: MpinMode.enter, flow: AuthFlow.login));
      expect(find.text('Enter Your MPIN'), findsOneWidget);
      expect(find.text('Forgot MPIN'), findsOneWidget);

      await _tapKeys(tester, '4828');
      await _tapAndWait(tester, 'UNLOCK');

      expect(find.textContaining('Your MPIN is incorrect. Please try again.'),
          findsOneWidget);
      expect(auth.session.stage, OnboardingStage.mpinEntry);
    });
  });
}
