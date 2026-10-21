import '../utils/manila_time.dart';

/// A Certificate of Eligibility: the OSCA office approved a Medical or Burial
/// request. The senior shows it, with a valid ID, at the office
/// to collect the assistance. Staff check its verification code there and
/// mark it claimed, which works only once. It names no amount.
///
/// From the backend's request JSON ("certificate"):
///   {"number": "CRT-2026-0001", "code": "K7Q4-M2XD-9PRT",
///    "program": "Medical assistance", "seniorName": "...",
///    "seniorNumber": "SC-2026-0001", "oscaIdNumber": "...",
///    "claimantName": "...", "issuedAt": "...",
///    "issuedBy": "...", "state": "Ready to claim", "claimedAt": null,
///    "receivedBy": null}
class AssistanceCertificate {
  final String number;

  /// What the office checks, also inside the QR code.
  final String code;
  final String program;
  final String seniorName;
  final String seniorNumber;
  final String oscaIdNumber;

  /// Burial: the relative who collects it for the family.
  final String claimantName;

  final DateTime? issuedAt;
  final String issuedBy;

  /// Set once it was claimed at the office.
  final DateTime? claimedAt;
  final String receivedBy;

  const AssistanceCertificate({
    required this.number,
    required this.code,
    required this.program,
    required this.seniorName,
    this.seniorNumber = '',
    this.oscaIdNumber = '',
    this.claimantName = '',
    this.issuedAt,
    this.issuedBy = '',
    this.claimedAt,
    this.receivedBy = '',
  });

  bool get isClaimed => claimedAt != null;

  Map<String, dynamic> toJson() => {
        'number': number,
        'code': code,
        'program': program,
        'seniorName': seniorName,
        'seniorNumber': seniorNumber,
        'oscaIdNumber': oscaIdNumber,
        'claimantName': claimantName,
        'issuedAt': issuedAt?.toIso8601String(),
        'issuedBy': issuedBy,
        'claimedAt': claimedAt?.toIso8601String(),
        'receivedBy': receivedBy,
      };

  /// Null when [json] is not a certificate (e.g. a request not approved).
  static AssistanceCertificate? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    String text(String key) => map[key] is String ? map[key] as String : '';
    DateTime? date(String key) => parseServerTime(text(key));

    final code = text('code');
    if (code.isEmpty) return null;
    return AssistanceCertificate(
      number: text('number'),
      code: code,
      program: text('program'),
      seniorName: text('seniorName'),
      seniorNumber: text('seniorNumber'),
      oscaIdNumber: text('oscaIdNumber'),
      claimantName: text('claimantName'),
      issuedAt: date('issuedAt'),
      issuedBy: text('issuedBy'),
      claimedAt: date('claimedAt'),
      receivedBy: text('receivedBy'),
    );
  }
}
