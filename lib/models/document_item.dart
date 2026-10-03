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
