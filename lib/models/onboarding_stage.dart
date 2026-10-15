/// Where the user is in signing in.
/// The router reads this (with [AuthFlow]) to decide which screen to show.
///
/// Only [signedOut], [identitySetup] and [completed] are saved on the phone.
/// The others last only while the app is open: the typed password is never
/// saved, so after a restart the steps start again.
///
/// A restart on a phone that already has an account goes to Login with the
/// address filled in (AuthStorage remembers it); the session token decides
/// whether even that is needed.
enum OnboardingStage {
  signedOut, // Welcome, Sign up name, Login, Forgot password
  credentials, // Sign up: email address, password, confirm password
  checkInbox, // "Check your inbox" until the address is confirmed
  identitySetup, // linking the senior citizen record (outside sign-in)
  completed; // signed in: the tabs

  /// True for the stages that are kept after the app is closed.
  bool get isSaved =>
      this == OnboardingStage.signedOut ||
      this == OnboardingStage.identitySetup ||
      this == OnboardingStage.completed;

  static OnboardingStage fromName(String? name) {
    switch (name) {
      // Older builds asked "Who is using this phone?" at this step.
      case 'identitySetup':
      case 'roleSelection':
        return OnboardingStage.identitySetup;
      // Older builds had an emergency contact step after the identity.
      case 'completed':
      case 'emergencySetup':
        return OnboardingStage.completed;
      default:
        return OnboardingStage.signedOut;
    }
  }
}

/// Which sign-in flow the screens belong to. Each has its own business
/// logic, so Sign up and Login never share any:
///
/// - register:       name -> email + password + confirm -> check your inbox
/// - login:          email + password -> Home
/// - forgotPassword: email -> (link in the inbox) -> back to Login
///
/// Nothing is typed from an email any more: both the confirmation and the
/// password reset are links the senior taps, and the pages they open are
/// served by the backend.
enum AuthFlow {
  register,
  login,
  forgotPassword;

  static const int registerSteps = 2;

  /// "Step 2 of 2" on the Sign up screens, null otherwise.
  String? stepLabel(OnboardingStage stage) {
    if (this != AuthFlow.register) return null;
    final n = switch (stage) {
      OnboardingStage.signedOut => 1,
      OnboardingStage.credentials => 2,
      _ => null,
    };
    return n == null ? null : 'Step $n of $registerSteps';
  }
}
