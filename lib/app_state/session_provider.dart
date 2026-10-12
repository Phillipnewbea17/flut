import 'package:flutter/foundation.dart';

import '../models/onboarding_stage.dart';
import '../models/registration_name.dart';
import '../services/auth_service.dart';
import '../storage/auth_storage.dart';
import '../storage/preferences.dart';
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
    required AuthStorage storage,
    required AuthService auth,
  })  : _prefs = prefs,
        _storage = storage,
        _auth = auth,
        _stage = prefs.stage;

  final Preferences _prefs;
  final AuthStorage _storage;
  final AuthService _auth;

  OnboardingStage _stage;
  AuthFlow? _flow;
  bool _splashDone = false;
  String? _notice;
  String _lastPhone = '';
  bool _registered = false;

  /// Extra clean-up to run on log out (wipe offline data, forget photos,
  /// clear the sign-in flows...). main.dart registers these.
  final List<Future<void> Function()> _logoutHooks = [];

  /// Runs right after the backend created the account or logged in, with
  /// the phone number and, for Create Account, the name that was sent
  /// (main.dart: remember them, then load the profile from the server).
  Future<void> Function(String phone, RegistrationName? name)? afterSignIn;

  /// Opens "Enter your MPIN" for the account already on this phone, with
  /// the number and name read from [AuthStorage] (main.dart: fill in the
  /// user, then LoginFlow.resumeOnThisPhone). No code is texted.
  Future<void> Function(String phone, String? fullName)? resumeMpinLogin;

  OnboardingStage get stage => _stage;

  /// The flow whose screens are showing (or were last used).
  AuthFlow? get flow => _flow;

  /// False until the splash screen has checked the saved session.
  bool get splashDone => _splashDone;

  /// Signed in: the tabs may open.
  bool get onboardingComplete => _stage == OnboardingStage.completed;

  /// An account was created or logged in on this phone before, so the app
  /// opens at "Enter your MPIN" and never at Create Account. Read from
  /// [AuthStorage] in [init]; only Logout or Delete account clears it.
  bool get isRegistered => _registered;

  /// The last number used, to fill in Login after the session ended.
  String get lastPhone => _lastPhone;

  /// One-time message for the Login screen ("Your MPIN was changed").
  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  void addLogoutHook(Future<void> Function() hook) => _logoutHooks.add(hook);

  /// Call once in main() before the app starts: reads what this phone
  /// remembers about the account, before any screen is built.
  Future<void> init() async {
    // Older builds kept the MPIN on the phone in plain text.
    try {
      await _storage.deleteLegacyMpin();
    } catch (_) {}

    // Does this phone already have an account? (Only Logout or Delete
    // account clears this; closing the app never does.)
    _registered = await _storage.isRegistered();

    // The account's number fills in Login (MPIN only, no code).
    _lastPhone = await _auth.trustedPhone() ??
        await _storage.registeredPhone() ??
        '';

    // A saved "signed in" stage without a session token cannot be trusted.
    if (_stage != OnboardingStage.signedOut) {
      String? token;
      try {
        token = await _storage.readToken();
      } catch (_) {
        token = null;
      }
      if (token == null) await _endSession(serverSignOut: false);
    }
  }

  /// Called by the splash screen. Checks the saved session with the
  /// backend: valid -> Home; refused or missing -> "Enter your MPIN" when
  /// this phone is registered, Welcome when it is not.
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
    // Not signed in, but the account is on this phone: the MPIN screen,
    // not Create Account.
    if (_stage == OnboardingStage.signedOut) await _askForMpin();
    _splashDone = true;
    notifyListeners();
  }

  /// Opens "Enter your MPIN" when this phone is registered and its number
  /// is known. Otherwise nothing changes and the user sees Welcome.
  Future<void> _askForMpin() async {
    if (!_registered) return;
    final resume = resumeMpinLogin;
    if (resume == null) return;
    final phone = await _storage.registeredPhone();
    if (phone == null || phone.isEmpty) return;
    _lastPhone = phone;
    try {
      await resume(phone, await _storage.registeredName());
    } catch (_) {
      // Could not be prepared: Login asks for the number as before.
    }
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
  /// token is saved: remember this phone as registered, then open Home.
  ///
  /// [mpin] is the MPIN the backend just accepted. It is kept here as a
  /// salted hash only (AuthStorage), so the next start can open the MPIN
  /// screen and check it without texting a code.
  Future<void> startSession(
    String phone, {
    RegistrationName? name,
    String? mpin,
  }) async {
    _lastPhone = phone;
    try {
      await _storage.saveRegistration(
        phone: phone,
        mpin: mpin,
        fullName: name?.cleaned.fullName,
      );
      _registered = true;
    } catch (_) {
      // Secure storage unavailable: the next start asks for the number
      // and a code, as before.
    }
    try {
      await afterSignIn?.call(phone, name);
    } catch (_) {
      // The profile loads again on Home.
    }
    await _moveTo(OnboardingStage.completed);
  }

  /// Forgot MPIN finished: keep the new MPIN's hash on this phone (the
  /// account is NOT created again), then back to Login.
  Future<void> mpinWasReset(String phone, {String? mpin}) async {
    _lastPhone = phone;
    if (mpin != null) {
      try {
        await _storage.saveMpin(mpin);
      } catch (_) {
        // Only the backend will check it then.
      }
    }
    _notice = 'Your MPIN was changed. Please log in with your new MPIN.';
    await enter(OnboardingStage.signedOut, AuthFlow.login);
  }

  /// Checks [mpin] against the hash saved on this phone (Login on a phone
  /// that already has the account), and counts the wrong tries.
  ///
  /// Throws [AuthError.wrongMpin] with the tries left, or
  /// [AuthError.mpinLocked] when there are none left ("Forgot MPIN").
  /// Returns normally when this phone has no hash saved: only the backend
  /// can judge then.
  Future<void> checkStoredMpin(String mpin) async {
    if (!await _storage.hasMpin()) return;
    if (await _storage.mpinAttemptsLeft() <= 0) {
      throw const AuthException(AuthError.mpinLocked);
    }
    if (await _storage.verifyMpin(mpin)) {
      await _storage.clearMpinAttempts();
      return;
    }
    final left = await _storage.countWrongMpin();
    throw AuthException(
      left <= 0 ? AuthError.mpinLocked : AuthError.wrongMpin,
      attemptsLeft: left,
    );
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
      // Keep this phone's hash in step with the backend's.
      try {
        await _storage.saveMpin(newMpin);
      } catch (_) {}
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

  /// The backend refused the session token: forget the token and go to
  /// Login. This phone STAYS registered (the number and the MPIN hash are
  /// kept), so the next start opens "Enter your MPIN".
  Future<void> expireSession() async {
    if (_stage == OnboardingStage.signedOut) return;
    await _endSession(
      serverSignOut: false,
      notice: const AuthException(AuthError.sessionExpired).message,
    );
  }

  /// Explicit Logout: ends the session on the backend and forgets the
  /// account on this phone, registration included, then Welcome. Nothing is
  /// deleted on the server. Text size and language are kept.
  ///
  /// This and a future Delete account are the ONLY things that clear the
  /// registration: closing the app, disposing a screen or going back never
  /// do.
  Future<void> logout() => _endSession(forgetAccount: true);

  Future<void> _endSession({
    bool serverSignOut = true,
    bool forgetAccount = false,
    String? notice,
  }) async {
    // A refused token can be reported by several requests at once: they
    // all wait for the same clean-up.
    final running = _ending;
    if (running != null) return running;
    final wipe = _wipe(
      serverSignOut: serverSignOut,
      forgetAccount: forgetAccount,
      notice: notice,
    );
    _ending = wipe;
    try {
      await wipe;
    } finally {
      _ending = null;
    }
  }

  Future<void>? _ending;

  Future<void> _wipe({
    required bool serverSignOut,
    required bool forgetAccount,
    String? notice,
  }) async {
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
      // Logout forgets everything; a refused token only loses the token.
      if (forgetAccount) {
        await _storage.clearAll();
      } else {
        await _storage.clearSession();
      }
    } catch (_) {}
    if (forgetAccount) _registered = false;
    _notice = notice;
    await enter(OnboardingStage.signedOut, AuthFlow.login);
  }

  Future<void> _moveTo(OnboardingStage next) async {
    _stage = next;
    notifyListeners();
    if (next.isSaved) await _prefs.setStage(next);
  }
}
