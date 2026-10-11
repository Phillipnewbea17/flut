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
  Routes.changeMpin,
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

    test('/register, /login and /forgot-mpin open their first step', () {
      expect(redirect(OnboardingStage.signedOut, location: Routes.register),
          Routes.registerName);
      expect(redirect(OnboardingStage.signedOut, location: Routes.login),
          Routes.loginMobile);
      expect(redirect(OnboardingStage.signedOut, location: Routes.forgotMpin),
          Routes.forgotMobile);
    });

    test('may open Welcome, the first step of each flow, and Contact', () {
      for (final page in [
        Routes.welcome,
        Routes.registerName,
        Routes.loginMobile,
        Routes.forgotMobile,
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
        Routes.registerMobile,
        Routes.registerOtp,
        Routes.registerCreateMpin,
        Routes.registerConfirmMpin,
        Routes.loginOtp,
        Routes.loginMpin,
        Routes.forgotOtp,
        Routes.forgotCreateMpin,
      ]) {
        expect(redirect(OnboardingStage.signedOut, location: page),
            Routes.welcome,
            reason: page);
      }
    });

    test("leaving a flow returns to that flow's first step", () {
      expect(
        redirect(OnboardingStage.signedOut,
            flow: AuthFlow.login, location: Routes.loginMpin),
        Routes.loginMobile,
      );
      expect(
        redirect(OnboardingStage.signedOut,
            flow: AuthFlow.register, location: Routes.registerMobile),
        Routes.registerName,
      );
      expect(
        redirect(OnboardingStage.signedOut,
            flow: AuthFlow.resetMpin, location: Routes.forgotOtp),
        Routes.forgotMobile,
      );
    });

    test('after Forgot MPIN, Login (not Home)', () {
      expect(
        redirect(OnboardingStage.signedOut,
            flow: AuthFlow.login, location: Routes.forgotConfirmMpin),
        Routes.loginMobile,
      );
    });
  });

  group('Create Account and Login use separate screens', () {
    test('Create Account: name, mobile, code, create, confirm', () {
      String? at(OnboardingStage stage) =>
          redirect(stage, flow: AuthFlow.register);
      expect(at(OnboardingStage.phoneEntry), Routes.registerMobile);
      expect(at(OnboardingStage.otpVerify), Routes.registerOtp);
      expect(at(OnboardingStage.mpinSetup), Routes.registerCreateMpin);
      expect(at(OnboardingStage.mpinConfirm), Routes.registerConfirmMpin);
    });

    test('Login: mobile, code, existing MPIN', () {
      String? at(OnboardingStage stage) =>
          redirect(stage, flow: AuthFlow.login);
      expect(at(OnboardingStage.otpVerify), Routes.loginOtp);
      expect(at(OnboardingStage.mpinEntry), Routes.loginMpin);
    });

    test('Login never shows a create-MPIN screen', () {
      expect(Routes.screenFor(OnboardingStage.mpinSetup, AuthFlow.login),
          isNull);
      expect(Routes.screenFor(OnboardingStage.mpinConfirm, AuthFlow.login),
          isNull);
    });

    test('Forgot MPIN: code, new MPIN, confirm', () {
      String? at(OnboardingStage stage) =>
          redirect(stage, flow: AuthFlow.resetMpin);
      expect(at(OnboardingStage.otpVerify), Routes.forgotOtp);
      expect(at(OnboardingStage.mpinSetup), Routes.forgotCreateMpin);
      expect(at(OnboardingStage.mpinConfirm), Routes.forgotConfirmMpin);
    });

    test('no redirect when already on the right screen', () {
      expect(
          redirect(OnboardingStage.otpVerify,
              flow: AuthFlow.login, location: Routes.loginOtp),
          isNull);
      expect(
          redirect(OnboardingStage.mpinConfirm,
              flow: AuthFlow.register, location: Routes.registerConfirmMpin),
          isNull);
    });

    test('cannot reach Home before Laravel signs the user in', () {
      for (final (stage, flow) in [
        (OnboardingStage.phoneEntry, AuthFlow.register),
        (OnboardingStage.otpVerify, AuthFlow.register),
        (OnboardingStage.mpinSetup, AuthFlow.register),
        (OnboardingStage.mpinConfirm, AuthFlow.register),
        (OnboardingStage.otpVerify, AuthFlow.login),
        (OnboardingStage.mpinEntry, AuthFlow.login),
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
        Routes.registerConfirmMpin,
        Routes.login,
        Routes.loginMobile,
        Routes.loginMpin,
        Routes.forgotMobile,
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
    test('code and MPIN steps are never resumed after a restart', () {
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
