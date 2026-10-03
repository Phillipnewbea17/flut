import 'package:flutter/foundation.dart';

import '../models/onboarding_stage.dart';
import '../storage/preferences.dart';
import '../storage/secure_vault.dart';
import '../utils/mpin_validator.dart';

/// Holds WHERE the user is: onboarding stage, and whether the app is
/// unlocked with the MPIN. The router listens to this and moves the user
/// to the right screen on its own.
class SessionProvider extends ChangeNotifier {
  final Preferences _prefs;
  final SecureVault _vault;

  OnboardingStage _stage;
  bool _splashDone = false;
  bool _unlocked = false;

  /// Extra clean-up to run on log out (wipe offline data, forget photos...).
  /// main.dart registers these.
  final List<Future<void> Function()> _logoutHooks = [];

  SessionProvider({required Preferences prefs, required SecureVault vault})
      : _prefs = prefs,
        _vault = vault,
        _stage = prefs.stage;

  OnboardingStage get stage => _stage;

  /// False until the splash screen has finished its short loading time.
  bool get splashDone => _splashDone;

  /// True once the MPIN has been entered (or created) in this app session.
  bool get unlocked => _unlocked;

  bool get onboardingComplete => _stage == OnboardingStage.completed;

  void addLogoutHook(Future<void> Function() hook) => _logoutHooks.add(hook);

  /// Call once in main() before the app starts. Repairs states that would
  /// otherwise trap the user on a screen they cannot get past.
  Future<void> init() async {
    // The phone number typed on the login screen is not saved until the code
    // is confirmed, so after a restart this step has to be done again.
    if (_stage == OnboardingStage.otpVerify) {
      _stage = OnboardingStage.phoneEntry;
      await _prefs.setStage(_stage);
    }

    // Setup finished but there is no MPIN to check against (for example the
    // secure storage was cleared). Ask the user to create a new one.
    if (_stage == OnboardingStage.completed) {
      var hasMpin = false;
      try {
        hasMpin = await _vault.hasMpin();
      } catch (_) {
        hasMpin = false;
      }
      if (!hasMpin) {
        _stage = OnboardingStage.mpinSetup;
        await _prefs.setStage(_stage);
      }
    }
  }

  /// Called by the splash screen when it is done. On the very first launch
  /// the user sees the welcome slides next.
  Future<void> finishSplash() async {
    if (_splashDone) return;
    _splashDone = true;
    if (_stage == OnboardingStage.splash) {
      _stage = OnboardingStage.welcome;
      await _prefs.setStage(_stage);
    }
    notifyListeners();
  }

  /// Move to another onboarding step. The router follows automatically.
  Future<void> advanceTo(OnboardingStage next) async {
    _stage = next;
    notifyListeners();
    await _prefs.setStage(next);
  }

  /// Saves a brand new MPIN. Returns an error message when the PIN is too
  /// easy to guess, or null when it was saved and the user moved on.
  Future<String?> createMpin(String pin) async {
    final error = MpinValidator.validate(pin);
    if (error != null) return error;
    await _vault.saveMpin(pin);
    _unlocked = true;

    // If the user already finished setup before (and only the MPIN was
    // missing), do not make them answer the same questions again.
    final alreadySetUp = (_prefs.profile?.fullName.isNotEmpty ?? false) &&
        _prefs.emergencyContact != null;
    await advanceTo(alreadySetUp
        ? OnboardingStage.completed
        : OnboardingStage.roleSelection);
    return null;
  }

  /// Checks the MPIN when the app is opened. Returns true when it is right.
  Future<bool> unlockWithMpin(String pin) async {
    final ok = await _vault.verifyMpin(pin);
    if (ok) {
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  /// Checks a PIN without changing anything ("Change MPIN" first step).
  Future<bool> checkMpin(String pin) => _vault.verifyMpin(pin);

  /// Replaces the MPIN of a user who is already set up. Returns an error
  /// message when the new PIN is too easy to guess, or null when saved.
  Future<String?> replaceMpin(String pin) async {
    final error = MpinValidator.validate(pin);
    if (error != null) return error;
    await _vault.saveMpin(pin);
    return null;
  }

  /// Last step of setup ("SAVE & ENTER APP HOME").
  Future<void> completeOnboarding() async {
    _unlocked = true;
    await advanceTo(OnboardingStage.completed);
  }

  /// Asks for the MPIN again (for example after the app was in the
  /// background for a while).
  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  /// Wipes the account from this phone and returns to the login screen.
  /// Text size and language are kept.
  Future<void> logout() async {
    for (final hook in _logoutHooks) {
      try {
        await hook();
      } catch (_) {
        // Keep logging out even if one clean-up step fails.
      }
    }
    await _prefs.clearAccount();
    await _vault.clear();
    _unlocked = false;
    _stage = OnboardingStage.phoneEntry;
    notifyListeners();
    await _prefs.setStage(_stage);
  }
}
