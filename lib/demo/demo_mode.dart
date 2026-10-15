/// DEMO MODE: for trying the app without the SCMS server.
///
/// Turn it on when running the app:
///   flutter run --dart-define=DEMO_MODE=true
///
/// Then lib/demo/demo_backend.dart answers on the phone instead of Laravel,
/// with the same answers and rules, and every screen shows a DEMO ribbon.
///
/// Signing in needs no email in demo mode: nothing on the phone can send
/// one or serve the page its link opens, so a new account counts as
/// confirmed the moment it is made, and "Check Your Inbox" says so instead
/// of waiting for a link that can never arrive. Forgot password answers the
/// same as the real backend but no link goes out, so a forgotten demo
/// password cannot be changed — make another account instead.
///
/// To remove demo mode for good: delete the lib/demo folder and the lines
/// marked "DEMO" in lib/main.dart and
/// lib/views/onboarding/check_inbox_view.dart.
library;

const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');
