import 'package:flutter/foundation.dart';

import '../models/onboarding_stage.dart';
import '../models/registration_name.dart';
import '../services/auth_service.dart';
import '../storage/auth_storage.dart';
import '../storage/preferences.dart';
import '../utils/password_validator.dart';

/// The session, and WHERE the user is in signing in. The router listens to
/// this and moves the user to the right screen.
///
/// The sign-in steps themselves live in their own classes, so Create
/// Account and Login never share business logic:
///   RegistrationFlow (Create Account), LoginFlow (Login),
///   PasswordResetFlow (Forgot Password).
/// They move the user on with [enter], and finish with [startSession] or
/// [passwordWasReset].
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
  String _lastEmail = '';
  bool _registered = false;

  /// Extra clean-up to run on log out (wipe offline data, forget photos,
  /// clear the sign-in flows...). main.dart registers these.
  final List<Future<void> Function()> _logoutHooks = [];

  /// Runs right after the backend created the account or logged in, with
  /// the email address and, for Create Account, the name that was sent
  /// (main.dart: remember them, then load the profile from the server).
  Future<void> Function(String email, RegistrationName? name)? afterSignIn;

  /// The app was opened again on a phone that already has an account but no
  /// usable session: Login opens with the address and the name read from
  /// [AuthStorage] (main.dart fills in the user so the greeting has a name).
  Future<void> Function(String email, String? fullName)? resumeLogin;

  OnboardingStage get stage => _stage;

  /// The flow whose screens are showing (or were last used).
  AuthFlow? get flow => _flow;

  /// False until the splash screen has checked the saved session.
  bool get splashDone => _splashDone;

  /// Signed in: the tabs may open.
  bool get onboardingComplete => _stage == OnboardingStage.completed;

  /// An account was created or logged in on this phone before, so the app
  /// opens at Login and never at Create Account. Read from [AuthStorage]
  /// in [init]; only Logout or Delete account clears it.
  bool get isRegistered => _registered;

  /// The last address used, to fill in Login after the session ended.
  String get lastEmail => _lastEmail;

  /// One-time message for the Login screen ("Your password was changed").
  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  void addLogoutHook(Future<void> Function() hook) => _logoutHooks.add(hook);

  /// Call once in main() before the app starts: reads what this phone
  /// remembers about the account, before any screen is built.
  Future<void> init() async {
    // Older builds kept an MPIN hash and a trusted-device key here.
    try {
      await _storage.deleteLegacySecrets();
    } catch (_) {}

    // Does this phone already have an account? (Only Logout or Delete
    // account clears this; closing the app never does.)
    _registered = await _storage.isRegistered();

    // The account's address fills in Login.
    _lastEmail = await _storage.registeredEmail() ?? '';

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
  /// backend: valid -> Home; refused or missing -> Login with the address
  /// filled in when this phone is registered, Welcome when it is not.
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
    // Not signed in, but the account is on this phone: Login, not Create
    // Account.
    if (_stage == OnboardingStage.signedOut) await _prepareLogin();
    _splashDone = true;
    notifyListeners();
  }

  /// Opens Login with the saved address when this phone is registered.
  /// Otherwise nothing changes and the user sees Welcome.
  Future<void> _prepareLogin() async {
    if (!_registered) return;
    final email = await _storage.registeredEmail();
    if (email == null || email.isEmpty) return;
    _lastEmail = email;
    _flow = AuthFlow.login;
    try {
      await resumeLogin?.call(email, await _storage.registeredName());
    } catch (_) {
      // Could not be prepared: Login still asks for the address.
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
  /// ("Log in instead", "Create Account", "Forgot Password").
  Future<void> startFlow(AuthFlow flow) =>
      enter(OnboardingStage.signedOut, flow);

  /// The backend created the account or accepted the password, and the
  /// session token is saved: remember this phone as registered, then open
  /// Home. The password itself is never kept on this phone.
  Future<void> startSession(String email, {RegistrationName? name}) async {
    _lastEmail = email;
    try {
      await _storage.saveRegistration(
        email: email,
        fullName: name?.cleaned.fullName,
      );
      _registered = true;
    } catch (_) {
      // Secure storage unavailable: the next start asks for the address
      // and the password, as before.
    }
    try {
      await afterSignIn?.call(email, name);
    } catch (_) {
      // The profile loads again on Home.
    }
    await _moveTo(OnboardingStage.completed);
  }

  /// Keeps [email] so the Login screen opens with it filled in. Used when a
  /// flow hands over to Login (after signing up, or after asking for a
  /// reset link), so the senior does not type their address twice.
  ///
  /// This is only what to show in a text box. "This phone has an account"
  /// is set by [startSession] alone, once the backend has accepted a login.
  Future<void> rememberEmail(String email) async {
    if (email.isEmpty || email == _lastEmail) return;
    _lastEmail = email;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Signed in
  // ---------------------------------------------------------------------------

  /// Account > Change Password. Returns an error message, or null when
  /// changed.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final rule = PasswordValidator.validate(newPassword, email: _lastEmail);
    if (rule != null) return rule;
    try {
      await _auth.changePassword(
        currentPassword: currentPassword,
        password: newPassword,
      );
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
  /// Login. This phone STAYS registered (the address is kept), so Login
  /// opens with it filled in.
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
    if (forgetAccount) {
      _registered = false;
      _lastEmail = '';
    }
    _notice = notice;
    await enter(OnboardingStage.signedOut, AuthFlow.login);
  }

  Future<void> _moveTo(OnboardingStage next) async {
    _stage = next;
    notifyListeners();
    if (next.isSaved) await _prefs.setStage(next);
  }
}
