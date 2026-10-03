/// Where the user is in the onboarding flow.
/// The router reads this to decide which screen to show, so a user who
/// closes the app mid-setup resumes at the right step.
enum OnboardingStage {
  splash, // app just opened
  welcome, // intro carousel with the illustrations (first launch only)
  phoneEntry, // "Log in with your phone number"
  otpVerify, // "Enter your 4-digit code" (Step 1 of 4)
  mpinSetup, // create + confirm MPIN (Step 2 of 4)
  roleSelection, // "Who is using this phone?" (Step 3 of 4)
  emergencySetup, // "Emergency contact" (Step 4 of 4)
  completed; // goes to the tab shell

  /// Step number shown in the green header ("Step 3 of 4"), or null.
  int? get stepNumber {
    switch (this) {
      case OnboardingStage.otpVerify:
        return 1;
      case OnboardingStage.mpinSetup:
        return 2;
      case OnboardingStage.roleSelection:
        return 3;
      case OnboardingStage.emergencySetup:
        return 4;
      default:
        return null;
    }
  }

  static const int totalSteps = 4;

  /// "Step 3 of 4", or null for stages without a step number.
  String? get stepLabel {
    final n = stepNumber;
    return n == null ? null : 'Step $n of $totalSteps';
  }

  static OnboardingStage fromName(String? name) {
    return OnboardingStage.values.firstWhere(
      (s) => s.name == name,
      orElse: () => OnboardingStage.splash,
    );
  }
}
