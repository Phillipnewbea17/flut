import 'package:flutter/foundation.dart';

import '../models/application_status.dart';
import '../models/emergency_contact.dart';
import '../models/identity_verification.dart';
import '../models/registration_name.dart';
import '../models/user_profile.dart';
import '../storage/preferences.dart';

/// Holds WHO the user is: profile, role and emergency contact.
/// (Where they are in the app is SessionProvider's job.)
class UserProvider extends ChangeNotifier {
  final Preferences _prefs;

  UserProfile? _profile;
  List<EmergencyContact> _emergencyContacts;

  UserProvider(this._prefs)
      : _profile = _prefs.profile,
        _emergencyContacts = _prefs.emergencyContacts;

  UserProfile? get profile => _profile;

  /// The people SOS calls, first to last.
  List<EmergencyContact> get emergencyContacts =>
      List.unmodifiable(_emergencyContacts);

  /// The person SOS calls first.
  EmergencyContact? get emergencyContact =>
      _emergencyContacts.isEmpty ? null : _emergencyContacts.first;

  /// True when a family relative is helping a senior (proxy mode).
  bool get isProxy => _profile?.isProxy ?? false;

  /// The first name, for "Mabuhay, Rosela". Older profiles only have the
  /// full name: then its first word.
  String get firstName {
    final first = _profile?.firstName.trim() ?? '';
    if (first.isNotEmpty) return first;
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

  /// Call after signing in. Saves the phone right away so the number is
  /// not lost if the app is closed in the middle of setup.
  Future<void> confirmPhone(String phone) async {
    final previous = _profile;
    final profile = (previous != null && previous.phone == phone)
        ? previous
        : UserProfile(phone: phone, fullName: '', role: UserRole.senior);
    _profile = profile;
    notifyListeners();
    await _prefs.saveProfile(profile);
  }

  /// "Who is using this phone?" screen: role + full name.
  Future<void> saveProfile({
    required String fullName,
    required UserRole role,
  }) async {
    final base = _profile ?? UserProfile(phone: '', fullName: '', role: role);
    await updateProfile(base.copyWith(fullName: fullName.trim(), role: role));
  }

  /// Account screens (personal information, address).
  Future<void> updateProfile(UserProfile updated) async {
    _profile = updated;
    notifyListeners();
    await _prefs.saveProfile(updated);
  }

  /// Create Account: the name typed before the mobile number. Shown right
  /// away on Home ("Mabuhay, Rosela") and in Account > Personal information.
  Future<void> applyRegistrationName(RegistrationName name) async {
    final base = _profile ??
        const UserProfile(phone: '', fullName: '', role: UserRole.senior);
    final clean = name.cleaned;
    await updateProfile(base.copyWith(
      fullName: clean.fullName,
      firstName: clean.firstName,
      middleName: clean.middleName,
      lastName: clean.lastName,
      suffix: clean.suffix,
      noMiddleName: clean.noMiddleName,
    ));
  }

  /// The name, birthday and address the server has for the account: the
  /// linked senior citizen record (the source of truth), or what was given
  /// in Create Account. Empty values never wipe what is already shown.
  Future<void> applyLinkedProfile(LinkedProfile linked) async {
    final info = linked.info;
    final base = _profile ??
        const UserProfile(phone: '', fullName: '', role: UserRole.senior);
    String keep(String fresh, String old) => fresh.trim().isEmpty ? old : fresh;
    final hasName = info.firstName.trim().isNotEmpty ||
        info.lastName.trim().isNotEmpty;

    await updateProfile(base.copyWith(
      fullName: keep(info.fullName, base.fullName),
      role: UserRole.senior,
      birthDate: info.birthDate ?? base.birthDate,
      barangay: keep(info.barangay, base.barangay),
      municipality: keep(info.municipality, base.municipality),
      province: keep(info.province, base.province),
      firstName: hasName ? info.firstName : base.firstName,
      middleName: hasName ? info.middleName : base.middleName,
      lastName: hasName ? info.lastName : base.lastName,
      suffix: hasName ? info.suffix : base.suffix,
      noMiddleName: hasName ? info.middleName.trim().isEmpty : base.noMiddleName,
    ));
  }

  // ---------------------------------------------------------------------------
  // Personal information: status, OSCA record, profile photo
  // ---------------------------------------------------------------------------

  /// The Senior ID status:
  /// 1. approved, when the account is linked to its OSCA record;
  /// 2. otherwise the application's own status.
  UserApplicationStatus applicationStatus(
    ApplicationStage stage, {
    bool recordLinked = false,
  }) {
    if (recordLinked ||
        _profile?.recordSource == RecordSource.linked ||
        _profile?.applicationStatus == UserApplicationStatus.approved) {
      return UserApplicationStatus.approved;
    }
    return switch (stage) {
      ApplicationStage.notStarted ||
      ApplicationStage.cancelled =>
        UserApplicationStatus.none,
      ApplicationStage.submitted => UserApplicationStatus.submitted,
      ApplicationStage.review => UserApplicationStatus.underReview,
      ApplicationStage.needsAction => UserApplicationStatus.needsAction,
      ApplicationStage.approved => UserApplicationStatus.approved,
      ApplicationStage.rejected => UserApplicationStatus.rejected,
    };
  }

  /// The app-profile photo (path on this phone), or null to remove it.
  Future<void> setPhotoPath(String? path) async {
    final base = _profile;
    if (base == null) return;
    await updateProfile(base.copyWith(photoPath: () => path));
  }

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    _emergencyContacts = List.of(contacts);
    notifyListeners();
    await _prefs.saveEmergencyContacts(contacts);
  }

  /// Clears what is in memory. SessionProvider.logout() wipes the saved copy.
  void reset() {
    _profile = null;
    _emergencyContacts = [];
    notifyListeners();
  }
}
