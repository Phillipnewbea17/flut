/// The digital Senior Citizen ID. It only exists after the application is
/// approved; until then the Wallet shows a "waiting" card.
class SeniorId {
  final String idNumber;
  final String fullName;
  final DateTime birthDate;
  final String address;
  final String issuedBy; // e.g. "OSCA Ubay, Bohol"
  final DateTime issuedAt;

  const SeniorId({
    required this.idNumber,
    required this.fullName,
    required this.birthDate,
    required this.address,
    required this.issuedBy,
    required this.issuedAt,
  });

  /// What the cashier's scanner reads.
  String get qrData => 'SCID|$idNumber|$fullName';

  Map<String, dynamic> toJson() => {
        'idNumber': idNumber,
        'fullName': fullName,
        'birthDate': birthDate.toIso8601String(),
        'address': address,
        'issuedBy': issuedBy,
        'issuedAt': issuedAt.toIso8601String(),
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
    );
  }
}
