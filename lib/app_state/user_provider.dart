import 'package:flutter/foundation.dart';

import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../storage/preferences.dart';

/// Holds WHO the user is: profile, role and emergency contact.
/// (Where they are in the app is SessionProvider's job.)
class UserProvider extends ChangeNotifier {
  final Preferences _prefs;

  UserProfile? _profile;
  EmergencyContact? _emergencyContact;

  /// Phone typed on the login screen, kept until the code is confirmed.
  String _pendingPhone = '';

  UserProvider(this._prefs)
      : _profile = _prefs.profile,
        _emergencyContact = _prefs.emergencyContact;

  UserProfile? get profile => _profile;
  EmergencyContact? get emergencyContact => _emergencyContact;
  String get pendingPhone => _pendingPhone;

  /// True when a family relative is helping a senior (proxy mode).
  bool get isProxy => _profile?.isProxy ?? false;

  /// First word of the full name, for "Mabuhay, Rosela".
  String get firstName {
    final name = _profile?.fullName.trim() ?? '';
    if (name.isEmpty) return '';
    return name.split(RegExp(r'\s+')).first;
  }

  // ---------------------------------------------------------------------------
  // Phone helpers (used by the phone entry and emergency contact screens)
  // ---------------------------------------------------------------------------

  /// "+63 955 140 2068", "0955 140 2068" and "9551402068" all become
  /// "9551402068".
  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// A Philippine mobile number is 10 digits starting with 9.
  static bool isValidPhone(String digits) =>
      digits.length == 10 && digits.startsWith('9');

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void setPendingPhone(String raw) {
    _pendingPhone = normalizePhone(raw);
    notifyListeners();
  }

  /// Call after the code is verified. Saves the phone right away so the
  /// number is not lost if the app is closed in the middle of setup.
  Future<void> confirmPhone() async {
    final previous = _profile;
    final profile = (previous != null && previous.phone == _pendingPhone)
        ? previous
        : UserProfile(phone: _pendingPhone, fullName: '', role: UserRole.senior);
    _profile = profile;
    notifyListeners();
    await _prefs.saveProfile(profile);
  }

  /// "Who is using this phone?" screen: role + full name.
  Future<void> saveProfile({
    required String fullName,
    required UserRole role,
  }) async {
    final base = _profile ??
        UserProfile(phone: _pendingPhone, fullName: '', role: role);
    await updateProfile(base.copyWith(fullName: fullName.trim(), role: role));
  }

  /// Account screens (personal information, address).
  Future<void> updateProfile(UserProfile updated) async {
    _profile = updated;
    notifyListeners();
    await _prefs.saveProfile(updated);
  }

  Future<void> saveEmergencyContact(EmergencyContact contact) async {
    _emergencyContact = contact;
    notifyListeners();
    await _prefs.saveEmergencyContact(contact);
  }

  /// Clears what is in memory. SessionProvider.logout() wipes the saved copy.
  void reset() {
    _profile = null;
    _emergencyContact = null;
    _pendingPhone = '';
    notifyListeners();
  }
}
