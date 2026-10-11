/// DEMO MODE: for trying the app without the SCMS server.
///
/// Turn it on when running the app:
///   flutter run --dart-define=DEMO_MODE=true
///
/// Then lib/demo/demo_backend.dart answers on the phone instead of Laravel,
/// with the same answers and rules, and every screen shows a DEMO ribbon.
/// The sign-in code is always [kDemoOtp] and is shown on the code screen.
///
/// To remove demo mode for good: delete the lib/demo folder and the lines
/// marked "DEMO" in lib/main.dart and lib/views/onboarding/otp_verify_view.dart.
library;

const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');

/// The code every demo sign-in uses (shown on the code screen).
const String kDemoOtp = '1234';
