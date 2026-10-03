import 'dart:convert';

enum UserRole { senior, familyRelative }

extension UserRoleLabel on UserRole {
  String get label =>
      this == UserRole.senior ? 'Senior citizen' : 'Family relative';
}

class UserProfile {
  final String phone; // digits only, no country code, e.g. 9551402068
  final String fullName;
  final UserRole role;
  final DateTime? birthDate;
  final String barangay;
  final String municipality;
  final String province;

  const UserProfile({
    required this.phone,
    required this.fullName,
    required this.role,
    this.birthDate,
    this.barangay = '',
    this.municipality = '',
    this.province = '',
  });

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
  }) {
    return UserProfile(
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      birthDate: birthDate ?? this.birthDate,
      barangay: barangay ?? this.barangay,
      municipality: municipality ?? this.municipality,
      province: province ?? this.province,
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
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
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
