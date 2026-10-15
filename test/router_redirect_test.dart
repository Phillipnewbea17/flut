import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/routes/app_router.dart';

String? redirect(
  OnboardingStage stage, {
  bool splashDone = true,
  AuthFlow? flow,
  String location = Routes.splash,
}) {
  return appRedirect(
    splashDone: splashDone,
    stage: stage,
    flow: flow,
    location: location,
  );
}

/// Every screen that needs a signed-in, linked account.
const _appPages = [
  Routes.home,
  Routes.applications,
  Routes.myId,
  Routes.benefitsTab,
  Routes.account,
  Routes.notifications,
  Routes.applicationStatus,
  Routes.medicalNew,
  Routes.helpNew,
  Routes.idServices,
  Routes.calculator,
  Routes.upload,
  Routes.idPhoto,
  Routes.qrCashier,
  Routes.accessibility,
  Routes.faq,
  Routes.changePassword,
];

void main() {
  group('splash', () {
    test('stays on splash until the session was checked', () {
      expect(
        redirect(OnboardingStage.completed,
            splashDone: false, location: Routes.home),
        Routes.splash,
      );
      expect(
        redirect(OnboardingStage.signedOut,
            splashDone: false, location: Routes.splash),
        isNull,
      );
    });
  });

  group('signed out', () {
    test('first start shows Welcome (onboarding)', () {
      expect(redirect(OnboardingStage.signedOut), Routes.welcome);
    });
    test('/register opens its first step', () {
      expect(redirect(OnboardingStage.signedOut, location: Routes.register),
          Routes.registerName);
    });

    test('may open Welcome, the first step of each flow, and Contact', () {
      for (final page in [
        Routes.welcome,
        Routes.registerName,
        Routes.login,
        Routes.forgotPassword,
        Routes.contact,
      ]) {
        expect(redirect(OnboardingStage.signedOut, location: page), isNull,
            reason: page);
      }
    });

    test('cannot open any app screen', () {
      for (final page in _appPages) {
        expect(redirect(OnboardingStage.signedOut, location: page),
            Routes.welcome,
            reason: page);
      }
    });

    test('cannot skip ahead to later steps', () {
      for (final page in [
        Routes.registerCredentials,
        Routes.checkInbox,
      ]) {
        expect(redirect(OnboardingStage.signedOut, location: page),
            Routes.welcome,
            reason: page);
      }
    });

    test("leaving a flow returns to that flow's first step", () {
      expect(
        redirect(OnboardingStage.signedOut,
            flow: AuthFlow.login, location: Routes.checkInbox),
        Routes.login,
      );
      expect(
        redirect(OnboardingStage.signedOut,
            flow: AuthFlow.register, location: Routes.registerCredentials),
        Routes.registerName,
      );
      expect(
        redirect(OnboardingStage.signedOut,
            flow: AuthFlow.forgotPassword, location: Routes.checkInbox),
        Routes.forgotPassword,
      );
    });
  });

  group('Sign up and Login use separate screens', () {
    test('Sign up: name, then email + password, then check your inbox', () {
      String? at(OnboardingStage stage) =>
          redirect(stage, flow: AuthFlow.register);
      expect(at(OnboardingStage.credentials), Routes.registerCredentials);
      expect(at(OnboardingStage.checkInbox), Routes.checkInbox);
    });

    test('Login reaches check your inbox when the address is unconfirmed',
        () {
      expect(
        redirect(OnboardingStage.checkInbox, flow: AuthFlow.login),
        Routes.checkInbox,
      );
    });

    test('Login never shows the sign-up credentials screen', () {
      expect(
        Routes.screenFor(OnboardingStage.credentials, AuthFlow.login),
        isNull,
      );
      expect(
        Routes.screenFor(OnboardingStage.credentials, AuthFlow.forgotPassword),
        isNull,
      );
    });

    test('Forgot password is one screen, so it has no later stage', () {
      expect(
        Routes.screenFor(OnboardingStage.checkInbox, AuthFlow.forgotPassword),
        isNull,
      );
    });

    test('no redirect when already on the right screen', () {
      expect(
          redirect(OnboardingStage.checkInbox,
              flow: AuthFlow.login, location: Routes.checkInbox),
          isNull);
      expect(
          redirect(OnboardingStage.credentials,
              flow: AuthFlow.register, location: Routes.registerCredentials),
          isNull);
    });

    test('cannot reach Home before Laravel signs the user in', () {
      for (final (stage, flow) in [
        (OnboardingStage.credentials, AuthFlow.register),
        (OnboardingStage.checkInbox, AuthFlow.register),
        (OnboardingStage.checkInbox, AuthFlow.login),
      ]) {
        for (final page in _appPages) {
          expect(redirect(stage, flow: flow, location: page), isNotNull,
              reason: '$stage $flow $page');
        }
      }
    });
  });

  group('signed in', () {
    test('leaves the sign-in screens for Home', () {
      for (final page in [
        Routes.splash,
        Routes.welcome,
        Routes.register,
        Routes.registerName,
        Routes.registerCredentials,
        Routes.login,
        Routes.forgotPassword,
        Routes.checkInbox,
      ]) {
        expect(redirect(OnboardingStage.completed, location: page),
            Routes.home,
            reason: page);
      }
    });

    test('can open every page of the app', () {
      for (final page in _appPages) {
        expect(redirect(OnboardingStage.completed, location: page), isNull,
            reason: page);
      }
    });
  });

  group('saved stages', () {
    test('the sign-up steps are never resumed after a restart', () {
      expect(
          OnboardingStage.fromName('credentials'), OnboardingStage.signedOut);
      expect(
          OnboardingStage.fromName('checkInbox'), OnboardingStage.signedOut);
      // Names from older builds, which had a code and an MPIN.
      expect(OnboardingStage.fromName('otpVerify'), OnboardingStage.signedOut);
      expect(OnboardingStage.fromName('mpinSetup'), OnboardingStage.signedOut);
      expect(OnboardingStage.fromName('phoneEntry'), OnboardingStage.signedOut);
      expect(OnboardingStage.fromName(null), OnboardingStage.signedOut);
    });

    test('older builds keep their place', () {
      expect(OnboardingStage.fromName('roleSelection'),
          OnboardingStage.identitySetup);
      expect(OnboardingStage.fromName('emergencySetup'),
          OnboardingStage.completed);
    });
  });
}
