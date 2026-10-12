/// One pension release for the signed-in senior (web: Pension Releases).
/// Statuses on the web: Released, Pending, On Hold.
class PensionRecord {
  final String period; // e.g. "July–September 2026"
  final String status;
  final DateTime? releaseDate;
  final String reference;

  /// How much was released, once the office paid it out of a fund. Null
  /// while the release is still Pending or On Hold.
  final double? amount;

  /// Who signed for it: the senior, or a named representative.
  final String receivedBy;

  const PensionRecord({
    required this.period,
    required this.status,
    this.releaseDate,
    this.reference = '',
    this.amount,
    this.receivedBy = '',
  });

  bool get isReleased => status.toLowerCase() == 'released';

  factory PensionRecord.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return PensionRecord(
      period: json['period'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      releaseDate: DateTime.tryParse(json['releaseDate'] as String? ?? ''),
      reference: json['reference'] as String? ?? '',
      amount: amount is num ? amount.toDouble() : null,
      receivedBy: json['receivedBy'] as String? ?? '',
    );
  }
}
