import 'package:flutter/foundation.dart';

import '../models/onboarding_stage.dart';
import '../models/registration_name.dart';
import '../services/auth_service.dart';
import '../storage/preferences.dart';
import '../storage/secure_vault.dart';
import '../utils/mpin_validator.dart';

/// The session, and WHERE the user is in signing in. The router listens to
/// this and moves the user to the right screen.
///
/// The sign-in steps themselves live in their own classes, so Create
/// Account and Login never share business logic:
///   RegistrationFlow (Create Account), LoginFlow (Login),
///   MpinResetFlow (Forgot MPIN).
/// They move the user on with [enter], and finish with [startSession] or
/// [mpinWasReset].
class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required Preferences prefs,
    required SecureVault vault,
    required AuthService auth,
  })  : _prefs = prefs,
        _vault = vault,
        _auth = auth,
        _stage = prefs.stage;

  final Preferences _prefs;
  final SecureVault _vault;
  final AuthService _auth;

  OnboardingStage _stage;
  AuthFlow? _flow;
  bool _splashDone = false;
  String? _notice;
  String _lastPhone = '';

  /// Extra clean-up to run on log out (wipe offline data, forget photos,
  /// clear the sign-in flows...). main.dart registers these.
  final List<Future<void> Function()> _logoutHooks = [];

  /// Runs right after the backend created the account or logged in, with
  /// the phone number and, for Create Account, the name that was sent
  /// (main.dart: remember them, then load the profile from the server).
  Future<void> Function(String phone, RegistrationName? name)? afterSignIn;

  OnboardingStage get stage => _stage;

  /// The flow whose screens are showing (or were last used).
  AuthFlow? get flow => _flow;

  /// False until the splash screen has checked the saved session.
  bool get splashDone => _splashDone;

  /// Signed in: the tabs may open.
  bool get onboardingComplete => _stage == OnboardingStage.completed;

  /// The last number used, to fill in Login after the session ended.
  String get lastPhone => _lastPhone;

  /// One-time message for the Login screen ("Your MPIN was changed").
  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  void addLogoutHook(Future<void> Function() hook) => _logoutHooks.add(hook);

  /// Call once in main() before the app starts.
  Future<void> init() async {
    // Older builds kept the MPIN on the phone in plain text.
    try {
      await _vault.deleteLegacyMpin();
    } catch (_) {}

    // A trusted phone fills in its number on Login (MPIN only, no code).
    _lastPhone = await _auth.trustedPhone() ?? '';

    // A saved "signed in" stage without a session token cannot be trusted.
    if (_stage != OnboardingStage.signedOut) {
      String? token;
      try {
        token = await _vault.readToken();
      } catch (_) {
        token = null;
      }
      if (token == null) await _endSession(serverSignOut: false);
    }
  }

  /// Called by the splash screen. Checks the saved session with the
  /// backend: valid -> Home; refused or missing -> Login.
  Future<void> finishSplash() async {
    if (_splashDone) return;
    if (_stage != OnboardingStage.signedOut) {
      final status = await _auth.checkSession();
      if (status == SessionStatus.none || status == SessionStatus.expired) {
        await _endSession(
          serverSignOut: false,
          notice: status == SessionStatus.expired
              ? const AuthException(AuthError.sessionExpired).message
              : null,
        );
      }
    }
    _splashDone = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Used by the sign-in flows
  // ---------------------------------------------------------------------------

  /// Shows the screen of [stage] in [flow].
  Future<void> enter(OnboardingStage stage, AuthFlow flow) async {
    _flow = flow;
    await _moveTo(stage);
  }

  /// Leaves the current sign-in flow for the first screen of [flow]
  /// ("Log in instead", "Create Account", "Forgot MPIN").
  Future<void> startFlow(AuthFlow flow) =>
      enter(OnboardingStage.signedOut, flow);

  /// The backend created the account or accepted the MPIN, and the session
  /// token is saved: open Home.
  Future<void> startSession(String phone, {RegistrationName? name}) async {
    _lastPhone = phone;
    try {
      await afterSignIn?.call(phone, name);
    } catch (_) {
      // The profile loads again on Home.
    }
    await _moveTo(OnboardingStage.completed);
  }

  /// Forgot MPIN finished: back to Login (not signed in).
  Future<void> mpinWasReset(String phone) async {
    _lastPhone = phone;
    _notice = 'Your MPIN was changed. Please log in with your new MPIN.';
    await enter(OnboardingStage.signedOut, AuthFlow.login);
  }

  // ---------------------------------------------------------------------------
  // Signed in
  // ---------------------------------------------------------------------------

  /// Account > Change MPIN. Returns an error message, or null when changed.
  Future<String?> changeMpin({
    required String currentMpin,
    required String newMpin,
  }) async {
    final rule = MpinValidator.validate(newMpin);
    if (rule != null) return rule;
    try {
      await _auth.changeMpin(currentMpin: currentMpin, mpin: newMpin);
      return null;
    } on AuthException catch (e) {
      if (e.error == AuthError.sessionExpired) await expireSession();
      return e.message;
    }
  }

  /// The senior record was linked (Personal Information): open Home.
  Future<void> completeIdentity() => _moveTo(OnboardingStage.completed);

  // ---------------------------------------------------------------------------
  // Leaving
  // ---------------------------------------------------------------------------

  /// Asks the backend again whether the session is good (the app came back
  /// from the background). Offline, the user keeps going.
  Future<void> recheckSession() async {
    if (_stage == OnboardingStage.signedOut) return;
    final status = await _auth.checkSession();
    if (status == SessionStatus.none || status == SessionStatus.expired) {
      await expireSession();
    }
  }

  /// The backend refused the session token: clear it and go to Login.
  Future<void> expireSession() async {
    if (_stage == OnboardingStage.signedOut) return;
    await _endSession(
      serverSignOut: false,
      notice: const AuthException(AuthError.sessionExpired).message,
    );
  }

  /// Ends the session on the backend and wipes the account from this phone,
  /// then Login. Nothing is deleted on the server. Text size and language
  /// are kept.
  Future<void> logout() => _endSession();

  Future<void> _endSession({bool serverSignOut = true, String? notice}) async {
    // A refused token can be reported by several requests at once: they
    // all wait for the same clean-up.
    final running = _ending;
    if (running != null) return running;
    final wipe = _wipe(serverSignOut: serverSignOut, notice: notice);
    _ending = wipe;
    try {
      await wipe;
    } finally {
      _ending = null;
    }
  }

  Future<void>? _ending;

  Future<void> _wipe({required bool serverSignOut, String? notice}) async {
    for (final hook in _logoutHooks) {
      try {
        await hook();
      } catch (_) {
        // Keep logging out even if one clean-up step fails.
      }
    }
    if (serverSignOut) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
    await _prefs.clearAccount();
    try {
      await _vault.clear();
    } catch (_) {}
    _notice = notice;
    await enter(OnboardingStage.signedOut, AuthFlow.login);
  }

  Future<void> _moveTo(OnboardingStage next) async {
    _stage = next;
    notifyListeners();
    if (next.isSaved) await _prefs.setStage(next);
  }
}
