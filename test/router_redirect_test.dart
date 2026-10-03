import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/routes/app_router.dart';

String? redirect(
  OnboardingStage stage, {
  bool splashDone = true,
  bool unlocked = false,
  String location = Routes.splash,
}) {
  return appRedirect(
    splashDone: splashDone,
    stage: stage,
    unlocked: unlocked,
    location: location,
  );
}

void main() {
  group('splash', () {
    test('stays on splash until it is done', () {
      expect(
        redirect(OnboardingStage.phoneEntry,
            splashDone: false, location: Routes.phone),
        Routes.splash,
      );
      expect(
        redirect(OnboardingStage.phoneEntry,
            splashDone: false, location: Routes.splash),
        isNull,
      );
    });
  });

  group('onboarding stages', () {
    test('each stage sends the user to its own screen', () {
      expect(redirect(OnboardingStage.welcome), Routes.welcome);
      expect(redirect(OnboardingStage.phoneEntry), Routes.phone);
      expect(redirect(OnboardingStage.otpVerify), Routes.otp);
      expect(redirect(OnboardingStage.mpinSetup), Routes.mpin);
      expect(redirect(OnboardingStage.roleSelection), Routes.role);
      expect(redirect(OnboardingStage.emergencySetup), Routes.emergency);
    });

    test('first launch (splash stage) shows the welcome slides', () {
      expect(redirect(OnboardingStage.splash), Routes.welcome);
    });

    test('no redirect when already on the right screen', () {
      expect(
        redirect(OnboardingStage.roleSelection, location: Routes.role),
        isNull,
      );
    });

    test('cannot skip ahead to home before setup is finished', () {
      expect(
        redirect(OnboardingStage.mpinSetup,
            unlocked: true, location: Routes.home),
        Routes.mpin,
      );
      expect(
        redirect(OnboardingStage.roleSelection,
            unlocked: true, location: Routes.qrCashier),
        Routes.role,
      );
    });
  });

  group('completed setup', () {
    test('locked app goes to the MPIN screen', () {
      expect(
        redirect(OnboardingStage.completed, location: Routes.splash),
        Routes.mpin,
      );
      expect(
        redirect(OnboardingStage.completed, location: Routes.home),
        Routes.mpin,
      );
    });

    test('locked app stays on the MPIN screen', () {
      expect(
        redirect(OnboardingStage.completed, location: Routes.mpin),
        isNull,
      );
    });

    test('unlocked app leaves onboarding screens for home', () {
      expect(
        redirect(OnboardingStage.completed,
            unlocked: true, location: Routes.mpin),
        Routes.home,
      );
      expect(
        redirect(OnboardingStage.completed,
            unlocked: true, location: Routes.splash),
        Routes.home,
      );
    });

    test('unlocked app can open every page of the app', () {
      for (final page in [
        Routes.home,
        Routes.progress,
        Routes.calculator,
        Routes.upload,
        Routes.idPhoto,
        Routes.qrCashier,
        Routes.accessibility,
        Routes.faq,
        Routes.changeMpin,
      ]) {
        expect(
          redirect(OnboardingStage.completed, unlocked: true, location: page),
          isNull,
          reason: page,
        );
      }
    });

    test('locked app cannot open app pages', () {
      expect(
        redirect(OnboardingStage.completed, location: Routes.changeMpin),
        Routes.mpin,
      );
      expect(
        redirect(OnboardingStage.completed, location: Routes.qrCashier),
        Routes.mpin,
      );
    });
  });
}
