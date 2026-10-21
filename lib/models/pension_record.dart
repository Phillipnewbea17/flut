import '../utils/manila_time.dart';

/// One pension release for the signed-in senior (web: Pension Releases).
/// Statuses on the web: Released, Pending, On Hold. Only the office issues
/// pensions, and no amounts are kept.
class PensionRecord {
  final String period; // e.g. "July–September 2026"
  final String status;
  final DateTime? releaseDate;
  final String reference;

  /// Who signed for it: the senior, or a named representative.
  final String receivedBy;

  /// The office's note on this release (empty when there is none).
  final String remarks;

  /// When the office recorded this release (Philippine time), or null.
  final DateTime? recordedAt;

  const PensionRecord({
    required this.period,
    required this.status,
    this.releaseDate,
    this.reference = '',
    this.receivedBy = '',
    this.remarks = '',
    this.recordedAt,
  });

  bool get isReleased => status.toLowerCase() == 'released';
  bool get isOnHold => status.toLowerCase() == 'on hold';

  factory PensionRecord.fromJson(Map<String, dynamic> json) {
    return PensionRecord(
      period: json['period'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      releaseDate: DateTime.tryParse(json['releaseDate'] as String? ?? ''),
      reference: json['reference'] as String? ?? '',
      receivedBy: json['receivedBy'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      recordedAt: parseServerTime(json['recordedAt'] as String?),
    );
  }
}
