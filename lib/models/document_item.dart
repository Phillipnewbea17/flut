import '../utils/manila_time.dart';

/// The papers needed for a Senior Citizen ID.
///
/// These are exactly the four documents the OSCA office checks in the web
/// Document Verification page, in the same order. The names below are the
/// `type` the backend stores, so the office sees each photo in the right
/// slot: validId, birthCertificate, proofOfResidence, idPhoto.
enum DocumentType { validId, birthCertificate, proofOfResidence, idPhoto }

extension DocumentTypeInfo on DocumentType {
  String get title {
    switch (this) {
      case DocumentType.validId:
        return 'Valid ID';
      case DocumentType.birthCertificate:
        return 'Birth certificate';
      case DocumentType.proofOfResidence:
        return 'Proof of residence';
      case DocumentType.idPhoto:
        return '2x2 photo';
    }
  }

  String get hint {
    switch (this) {
      case DocumentType.validId:
        return 'A passport, driver\'s license, or any other government ID.';
      case DocumentType.birthCertificate:
        return 'From PSA or the local civil registrar.';
      case DocumentType.proofOfResidence:
        return 'A barangay certificate or a utility bill.';
      case DocumentType.idPhoto:
        return 'A recent photo of your face, with a white background.';
    }
  }

  /// Papers saved by an older version of this app. "proofOfAge" was one
  /// photo for both the valid ID and the birth certificate, and the office
  /// now keeps it as the valid ID (the same rename the server did), so the
  /// photo already sent stays "Submitted" here too. "other" is dropped:
  /// the office has no slot for it.
  static const _renamed = {'proofOfAge': DocumentType.validId};

  /// The matching type, or null if the name is not a paper we ask for.
  static DocumentType? parse(String? name) {
    for (final type in DocumentType.values) {
      if (type.name == name) return type;
    }
    return _renamed[name];
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

  /// Null when the saved type is no longer one of the required papers.
  static DocumentItem? tryFromJson(Map<String, dynamic> json) {
    final type = DocumentTypeInfo.parse(json['type'] as String?);
    if (type == null) return null;
    return DocumentItem(
      id: json['id'] as String? ?? '',
      type: type,
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

  /// Null when the office sent a decision about a paper this app no longer
  /// asks for.
  static DocumentReview? tryFromJson(Map<String, dynamic> json) {
    final type = DocumentTypeInfo.parse(json['type'] as String?);
    if (type == null) return null;
    return DocumentReview(
      type: type,
      status: DocumentReviewStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DocumentReviewStatus.pending,
      ),
      note: json['note'] as String? ?? '',
      reviewedAt: parseServerTime(json['reviewedAt'] as String?),
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

/// What the office's [review] says about a paper it has on the server.
DocumentState _stateOfReview(DocumentReview review) => switch (review.status) {
      DocumentReviewStatus.approved => DocumentState.approved,
      DocumentReviewStatus.needsCorrection => DocumentState.needsCorrection,
      DocumentReviewStatus.rejected => DocumentState.rejected,
      DocumentReviewStatus.pending => DocumentState.submitted,
    };

/// Combines the newest photo of a paper ([item], saved on this phone) with
/// the office's [review] (the paper as the server has it). A photo taken
/// after the review replaces the reviewed one, so it shows as "Submitted"
/// (waiting for a new check) instead. Without a photo on this phone, the
/// server's review is the answer, so a new phone or a logout shows the same.
DocumentState documentStateOf({
  required DocumentItem? item,
  required DocumentReview? review,
  required bool applicationApproved,
  required bool sendsToOffice,
}) {
  if (item == null) {
    return review == null ? DocumentState.notSubmitted : _stateOfReview(review);
  }
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
  // The phone's clock is compared with the office's time in Philippine time.
  final newerPhoto =
      reviewedAt != null && toPhilippineTime(item.addedAt).isAfter(reviewedAt);
  if (review != null && !newerPhoto) return _stateOfReview(review);
  return applicationApproved ? DocumentState.approved : DocumentState.submitted;
}
