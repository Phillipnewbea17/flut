/// One pension release for the signed-in senior (web: Pension Releases).
/// Statuses on the web: Released, Pending, On Hold.
class PensionRecord {
  final String period; // e.g. "July–September 2026"
  final String status;
  final DateTime? releaseDate;
  final String reference;

  const PensionRecord({
    required this.period,
    required this.status,
    this.releaseDate,
    this.reference = '',
  });

  bool get isReleased => status.toLowerCase() == 'released';

  factory PensionRecord.fromJson(Map<String, dynamic> json) {
    return PensionRecord(
      period: json['period'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      releaseDate: DateTime.tryParse(json['releaseDate'] as String? ?? ''),
      reference: json['reference'] as String? ?? '',
    );
  }
}
