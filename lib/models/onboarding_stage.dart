/// Where the user is in signing in.
/// The router reads this (with [AuthFlow]) to decide which screen to show.
///
/// Only [signedOut], [identitySetup] and [completed] are saved on the phone.
/// The others last only while the app is open: the code, the verification
/// token and the typed MPIN are never saved, so after a restart the steps
/// start again.
///
/// A restart on a phone that already has the account does not start any
/// flow again: AuthStorage says it is registered and the splash opens
/// [mpinEntry] (Login, "Enter your MPIN") straight away.
enum OnboardingStage {
  signedOut, // Welcome, Create Account name, Login or Forgot MPIN number
  phoneEntry, // Create Account: mobile number (after the name)
  otpVerify, // "Enter the 4-digit code"
  mpinSetup, // create a new MPIN (Create Account or Forgot MPIN)
  mpinConfirm, // type the new MPIN again
  mpinEntry, // Login: "Enter your MPIN"
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
/// logic (RegistrationFlow, LoginFlow, MpinResetFlow); only the code (OTP)
/// step and the session are shared.
///
/// - register:  name -> mobile -> code -> create + confirm MPIN -> Home
/// - login:     mobile -> code -> enter MPIN -> Home
/// - resetMpin: mobile -> code -> new MPIN + confirm -> Login
enum AuthFlow {
  register,
  login,
  resetMpin;

  /// The value sent to the backend as "purpose".
  String get wireName => switch (this) {
        AuthFlow.register => 'register',
        AuthFlow.login => 'login',
        AuthFlow.resetMpin => 'reset_mpin',
      };

  static const int registerSteps = 4;

  /// "Step 2 of 4" on the Create Account screens, null otherwise.
  String? stepLabel(OnboardingStage stage) {
    if (this != AuthFlow.register) return null;
    final n = switch (stage) {
      OnboardingStage.signedOut => 1,
      OnboardingStage.phoneEntry => 2,
      OnboardingStage.otpVerify => 3,
      OnboardingStage.mpinSetup || OnboardingStage.mpinConfirm => 4,
      _ => null,
    };
    return n == null ? null : 'Step $n of $registerSteps';
  }
}
