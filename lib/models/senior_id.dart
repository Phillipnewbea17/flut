/// Senior ID statuses on the web (Senior ID Management):
/// Pending Issuance, Active, For Replacement, Inactive.
enum SeniorIdStatus { pendingIssuance, active, forReplacement, inactive }

extension SeniorIdStatusInfo on SeniorIdStatus {
  String get label {
    switch (this) {
      case SeniorIdStatus.pendingIssuance:
        return 'Being prepared';
      case SeniorIdStatus.active:
        return 'Valid';
      case SeniorIdStatus.forReplacement:
        return 'For replacement';
      case SeniorIdStatus.inactive:
        return 'Not active';
    }
  }

  /// Accepts the web's words ("For Replacement") and the enum names.
  static SeniorIdStatus parse(String? value) {
    final key = (value ?? '').replaceAll(' ', '').toLowerCase();
    return SeniorIdStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == key,
      // Older wallet.json files have no status: an issued ID is active.
      orElse: () => SeniorIdStatus.active,
    );
  }
}

/// The digital Senior Citizen ID. It only exists after the application is
/// approved; until then My ID shows a "waiting" card.
class SeniorId {
  final String idNumber;
  final String fullName;
  final DateTime birthDate;
  final String address;
  final String issuedBy; // e.g. "OSCA Ubay, Bohol"
  final DateTime issuedAt;
  final SeniorIdStatus status;

  /// The office's record number for this senior, e.g. "SC-2026-0010".
  final String recordNo;

  /// Age and sex as the office recorded them ('' when not recorded).
  final int? age;
  final String sex;

  /// Web address of the ID photo, if the office has one.
  final String photoUrl;

  const SeniorId({
    required this.idNumber,
    required this.fullName,
    required this.birthDate,
    required this.address,
    required this.issuedBy,
    required this.issuedAt,
    this.status = SeniorIdStatus.active,
    this.recordNo = '',
    this.age,
    this.sex = '',
    this.photoUrl = '',
  });

  bool get isActive => status == SeniorIdStatus.active;

  /// What the cashier's scanner reads.
  String get qrData => 'SCID|$idNumber|$fullName';

  Map<String, dynamic> toJson() => {
        'idNumber': idNumber,
        'fullName': fullName,
        'birthDate': birthDate.toIso8601String(),
        'address': address,
        'issuedBy': issuedBy,
        'issuedAt': issuedAt.toIso8601String(),
        'status': status.name,
        'recordNo': recordNo,
        'age': age,
        'sex': sex,
        'photoUrl': photoUrl,
      };

  factory SeniorId.fromJson(Map<String, dynamic> json) {
    return SeniorId(
      idNumber: json['idNumber'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      birthDate:
          DateTime.tryParse(json['birthDate'] as String? ?? '') ?? DateTime(1960),
      address: json['address'] as String? ?? '',
      issuedBy: json['issuedBy'] as String? ?? '',
      issuedAt:
          DateTime.tryParse(json['issuedAt'] as String? ?? '') ?? DateTime.now(),
      status: SeniorIdStatusInfo.parse(json['status'] as String?),
      recordNo: json['recordNo'] as String? ?? '',
      age: (json['age'] as num?)?.toInt(),
      sex: json['sex'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
    );
  }
}
