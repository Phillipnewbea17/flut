import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';
import '../models/onboarding_stage.dart';
import '../models/user_profile.dart';

/// Non-secret data saved on the phone (profile, stage, text size, language).
/// The MPIN goes in AuthStorage, NOT here.
class Preferences {
  static const _kStage = 'onboarding_stage';
  static const _kProfile = 'user_profile';
  static const _kEmergency = 'emergency_contact'; // older, single contact
  static const _kEmergencyList = 'emergency_contacts';
  static const _kTextScale = 'text_scale';
  static const _kHighContrast = 'high_contrast';
  static const _kLanguage = 'language';

  final SharedPreferences _prefs;
  Preferences._(this._prefs);

  static Future<Preferences> load() async =>
      Preferences._(await SharedPreferences.getInstance());

  // Onboarding stage
  OnboardingStage get stage =>
      OnboardingStage.fromName(_prefs.getString(_kStage));
  Future<void> setStage(OnboardingStage s) => _prefs.setString(_kStage, s.name);

  // Profile
  UserProfile? get profile {
    final raw = _prefs.getString(_kProfile);
    if (raw == null) return null;
    try {
      return UserProfile.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile p) =>
      _prefs.setString(_kProfile, p.encode());

  // Emergency contacts, in the order SOS calls them
  List<EmergencyContact> get emergencyContacts {
    final raw = _prefs.getString(_kEmergencyList);
    if (raw != null) {
      try {
        return EmergencyContact.decodeList(raw);
      } catch (_) {
        return const [];
      }
    }
    // Older installs saved only one contact.
    final single = _prefs.getString(_kEmergency);
    if (single == null) return const [];
    try {
      return [EmergencyContact.decode(single)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    await _prefs.setString(
        _kEmergencyList, EmergencyContact.encodeList(contacts));
    await _prefs.remove(_kEmergency);
  }

  // Accessibility (these stay after log out)
  double get textScale => _prefs.getDouble(_kTextScale) ?? 1.0;
  Future<void> setTextScale(double v) => _prefs.setDouble(_kTextScale, v);

  bool get highContrast => _prefs.getBool(_kHighContrast) ?? false;
  Future<void> setHighContrast(bool v) => _prefs.setBool(_kHighContrast, v);

  /// "en", "fil" or "ceb".
  String get language => _prefs.getString(_kLanguage) ?? 'en';
  Future<void> setLanguage(String code) => _prefs.setString(_kLanguage, code);

  /// Log out: forget the account but keep text size and language.
  Future<void> clearAccount() async {
    await _prefs.remove(_kStage);
    await _prefs.remove(_kProfile);
    await _prefs.remove(_kEmergency);
    await _prefs.remove(_kEmergencyList);
  }

  /// Remove everything, settings included.
  Future<void> clear() => _prefs.clear();
}
