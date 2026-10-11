import 'dart:convert';

import 'osca_record.dart';

enum UserRole { senior, familyRelative }

extension UserRoleLabel on UserRole {
  String get label =>
      this == UserRole.senior ? 'Senior citizen' : 'Family relative';
}

/// Where the senior is with the Senior ID application. Drives the whole
/// Personal information screen.
enum UserApplicationStatus {
  none,
  submitted,
  underReview,
  needsAction,
  approved,
  rejected,
}

extension UserApplicationStatusInfo on UserApplicationStatus {
  /// Words on the status chip; null for [UserApplicationStatus.none].
  String? get label => switch (this) {
        UserApplicationStatus.none => null,
        UserApplicationStatus.submitted => 'Submitted',
        UserApplicationStatus.underReview => 'Under review',
        UserApplicationStatus.needsAction => 'Needs action',
        UserApplicationStatus.approved => 'Approved',
        UserApplicationStatus.rejected => 'Rejected',
      };

  static UserApplicationStatus parse(String? name) =>
      UserApplicationStatus.values.firstWhere((s) => s.name == name,
          orElse: () => UserApplicationStatus.none);
}

/// How the OSCA record came: from the app's application, or the user
/// linked a record that already existed at the OSCA office.
enum RecordSource { application, linked }

class UserProfile {
  final String phone; // digits only, no country code, e.g. 9551402068
  final String fullName;
  final UserRole role;
  final DateTime? birthDate;
  final String barangay;
  final String municipality;
  final String province;

  /// Purok / street of the current address.
  final String street;

  /// The name from Create Account (or the linked senior record). [fullName]
  /// is these joined; older saved profiles only have [fullName].
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;

  /// "I have no middle name" was ticked.
  final bool noMiddleName;

  /// Set by "Link my record" (approved + linked). Otherwise the status comes
  /// from the application (see UserProvider.applicationStatus).
  final UserApplicationStatus applicationStatus;
  final RecordSource? recordSource;

  /// The OSCA record, once matched (Link my record).
  final OscaRecord? oscaRecord;

  /// The app-profile photo on this phone (not the Senior ID photo).
  final String? photoPath;

  const UserProfile({
    required this.phone,
    required this.fullName,
    required this.role,
    this.birthDate,
    this.barangay = '',
    this.municipality = '',
    this.province = '',
    this.street = '',
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.suffix = '',
    this.noMiddleName = false,
    this.applicationStatus = UserApplicationStatus.none,
    this.recordSource,
    this.oscaRecord,
    this.photoPath,
  });

  /// True when the name was given in parts (First, Middle, Last, Suffix).
  bool get hasNameParts =>
      firstName.trim().isNotEmpty || lastName.trim().isNotEmpty;

  /// "RM" for the avatar when there is no photo.
  String get initials {
    final words = (hasNameParts ? '$firstName $lastName' : fullName)
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final last = words.length > 1 ? words.last[0] : '';
    return (words.first[0] + last).toUpperCase();
  }

  /// "Purok 3, Poblacion, Ubay, Bohol"
  String get addressLine => [street, barangay, municipality, province]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');

  /// "+63 955 140 2068"
  String get displayPhone => formatPhone(phone);

  static String formatPhone(String p) {
    if (p.length != 10) return '+63 $p';
    return '+63 ${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6)}';
  }

  bool get isProxy => role == UserRole.familyRelative;

  bool get hasAddress => municipality.trim().isNotEmpty;

  /// "Ubay, Bohol" for the Home header.
  String get shortAddress => [municipality, province]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');

  /// "Poblacion, Ubay, Bohol"
  String get fullAddress => [barangay, municipality, province]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');

  int? get age => birthDate == null ? null : ageOn(birthDate!, DateTime.now());

  /// Age in full years on [today].
  static int ageOn(DateTime birth, DateTime today) {
    var years = today.year - birth.year;
    final hadBirthday = today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthday) years--;
    return years;
  }

  UserProfile copyWith({
    String? phone,
    String? fullName,
    UserRole? role,
    DateTime? birthDate,
    String? barangay,
    String? municipality,
    String? province,
    String? street,
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    bool? noMiddleName,
    UserApplicationStatus? applicationStatus,
    RecordSource? recordSource,
    OscaRecord? oscaRecord,
    String? Function()? photoPath,
  }) {
    return UserProfile(
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      birthDate: birthDate ?? this.birthDate,
      barangay: barangay ?? this.barangay,
      municipality: municipality ?? this.municipality,
      province: province ?? this.province,
      street: street ?? this.street,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      noMiddleName: noMiddleName ?? this.noMiddleName,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      recordSource: recordSource ?? this.recordSource,
      oscaRecord: oscaRecord ?? this.oscaRecord,
      photoPath: photoPath != null ? photoPath() : this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'fullName': fullName,
        'role': role.name,
        'birthDate': birthDate?.toIso8601String(),
        'barangay': barangay,
        'municipality': municipality,
        'province': province,
        'street': street,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'suffix': suffix,
        'noMiddleName': noMiddleName,
        'applicationStatus': applicationStatus.name,
        'recordSource': recordSource?.name,
        'oscaRecord': oscaRecord?.toJson(),
        'photoPath': photoPath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final record = json['oscaRecord'];
    return UserProfile(
      phone: json['phone'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.senior,
      ),
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      barangay: json['barangay'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      province: json['province'] as String? ?? '',
      street: json['street'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      noMiddleName: json['noMiddleName'] as bool? ?? false,
      applicationStatus: UserApplicationStatusInfo.parse(
          json['applicationStatus'] as String?),
      recordSource: RecordSource.values
          .where((s) => s.name == json['recordSource'])
          .firstOrNull,
      oscaRecord: record is Map
          ? OscaRecord.fromJson(Map<String, dynamic>.from(record))
          : null,
      photoPath: json['photoPath'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory UserProfile.decode(String source) =>
      UserProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// A senior that a family relative helps in Family mode (proxy mode).
class ManagedSenior {
  final String id;
  final String fullName;
  final DateTime birthDate;
  final String relationship; // "Mother", "Father", "Grandparent", ...

  const ManagedSenior({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.relationship,
  });

  int get age => UserProfile.ageOn(birthDate, DateTime.now());

  bool get isEligible => age >= 60;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'birthDate': birthDate.toIso8601String(),
        'relationship': relationship,
      };

  factory ManagedSenior.fromJson(Map<String, dynamic> json) {
    return ManagedSenior(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? '') ??
          DateTime(1960),
      relationship: json['relationship'] as String? ?? '',
    );
  }
}
