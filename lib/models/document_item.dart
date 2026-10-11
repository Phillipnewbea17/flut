/// The papers needed for a Senior Citizen ID.
enum DocumentType { proofOfAge, proofOfResidence, idPhoto, other }

extension DocumentTypeInfo on DocumentType {
  String get title {
    switch (this) {
      case DocumentType.proofOfAge:
        return 'Birth certificate or valid ID';
      case DocumentType.proofOfResidence:
        return 'Barangay certificate';
      case DocumentType.idPhoto:
        return '1x1 ID photo';
      case DocumentType.other:
        return 'Other paper';
    }
  }

  String get hint {
    switch (this) {
      case DocumentType.proofOfAge:
        return 'Shows your birthday. A PSA birth certificate, or any '
            'government ID with your birth date.';
      case DocumentType.proofOfResidence:
        return 'Shows that you live in this town.';
      case DocumentType.idPhoto:
        return 'A clear photo of your face, for the ID card.';
      case DocumentType.other:
        return 'Any other paper the OSCA office asked for.';
    }
  }

  bool get isRequired => this != DocumentType.other;

  static DocumentType parse(String? name) {
    return DocumentType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => DocumentType.other,
    );
  }
}

enum DocumentStatus { saved, uploading, uploaded, failed }

DocumentStatus _parseStatus(String? name) {
  return DocumentStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => DocumentStatus.saved,
  );
}

/// A photo of a paper, saved privately on the phone (see DocumentVault).
class DocumentItem {
  final String id;
  final DocumentType type;
  final String filePath;
  final int sizeBytes;
  final DateTime addedAt;
  final DocumentStatus status;

  const DocumentItem({
    required this.id,
    required this.type,
    required this.filePath,
    required this.sizeBytes,
    required this.addedAt,
    required this.status,
  });

  bool get isUploaded => status == DocumentStatus.uploaded;

  DocumentItem copyWith({DocumentStatus? status}) => DocumentItem(
        id: id,
        type: type,
        filePath: filePath,
        sizeBytes: sizeBytes,
        addedAt: addedAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'status': status.name,
      };

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'] as String? ?? '',
      type: DocumentTypeInfo.parse(json['type'] as String?),
      filePath: json['filePath'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      status: _parseStatus(json['status'] as String?),
    );
  }
}

/// The OSCA office's decision on one paper (web Document Verification).
enum DocumentReviewStatus { pending, approved, needsCorrection, rejected }

/// One entry of the optional "documents" list in GET /application:
///   {"type": "proofOfResidence", "status": "needsCorrection",
///    "note": "The photo is blurred.", "reviewedAt": "2026-10-02T10:00:00"}
class DocumentReview {
  final DocumentType type;
  final DocumentReviewStatus status;
  final String note;
  final DateTime? reviewedAt;

  const DocumentReview({
    required this.type,
    required this.status,
    this.note = '',
    this.reviewedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'status': status.name,
        'note': note,
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory DocumentReview.fromJson(Map<String, dynamic> json) {
    return DocumentReview(
      type: DocumentTypeInfo.parse(json['type'] as String?),
      status: DocumentReviewStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DocumentReviewStatus.pending,
      ),
      note: json['note'] as String? ?? '',
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
    );
  }
}

/// What the user sees for one paper, from the photo on the phone and the
/// office's decision together.
enum DocumentState {
  notSubmitted,
  sending,
  notSent,

  /// No backend address: kept on the phone, nothing was sent.
  savedOnPhone,
  submitted,
  needsCorrection,
  approved,
  rejected,
}

extension DocumentStateInfo on DocumentState {
  String get label {
    switch (this) {
      case DocumentState.notSubmitted:
        return 'Not submitted';
      case DocumentState.sending:
        return 'Sending...';
      case DocumentState.notSent:
        return 'Not sent. Please send again.';
      case DocumentState.savedOnPhone:
        return 'Not sent: not connected to the OSCA office';
      case DocumentState.submitted:
        return 'Submitted';
      case DocumentState.needsCorrection:
        return 'Needs correction';
      case DocumentState.approved:
        return 'Approved';
      case DocumentState.rejected:
        return 'Rejected';
    }
  }

  /// The user should take a new photo of this paper.
  bool get needsNewPhoto =>
      this == DocumentState.notSubmitted ||
      this == DocumentState.needsCorrection ||
      this == DocumentState.rejected;
}

/// Combines the newest photo of a paper ([item]) with the office's
/// [review]. A photo taken after the review replaces the reviewed one, so it
/// shows as "Submitted" (waiting for a new check) instead.
DocumentState documentStateOf({
  required DocumentItem? item,
  required DocumentReview? review,
  required bool applicationApproved,
  required bool sendsToOffice,
}) {
  if (item == null) return DocumentState.notSubmitted;
  switch (item.status) {
    case DocumentStatus.uploading:
      return DocumentState.sending;
    case DocumentStatus.saved:
    case DocumentStatus.failed:
      return DocumentState.notSent;
    case DocumentStatus.uploaded:
      break;
  }
  if (!sendsToOffice) return DocumentState.savedOnPhone;

  final reviewedAt = review?.reviewedAt;
  final newerPhoto = reviewedAt != null && item.addedAt.isAfter(reviewedAt);
  if (review != null && !newerPhoto) {
    switch (review.status) {
      case DocumentReviewStatus.approved:
        return DocumentState.approved;
      case DocumentReviewStatus.needsCorrection:
        return DocumentState.needsCorrection;
      case DocumentReviewStatus.rejected:
        return DocumentState.rejected;
      case DocumentReviewStatus.pending:
        return DocumentState.submitted;
    }
  }
  return applicationApproved ? DocumentState.approved : DocumentState.submitted;
}
