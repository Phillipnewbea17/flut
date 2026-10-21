import '../utils/manila_time.dart';
import 'document_item.dart';

/// Where the Senior Citizen ID application is.
///
/// The backend (Mobile\ApplicationController::status) maps the web's
/// Document Verification statuses to these names:
///   Pending  -> submitted (or review, once the office marks it as opened)
///   Rejected -> needsAction (the office asks for corrected papers)
///   Verified -> approved
/// [rejected] (final, cannot be fixed) and [cancelled] are ready for when the
/// web adds those decisions.
enum ApplicationStage {
  notStarted,
  submitted,
  review,
  needsAction,
  approved,
  rejected,
  cancelled,
}

extension ApplicationStageText on ApplicationStage {
  /// Key in lib/l10n/app_*.arb, e.g. "stageReview" -> "Under review".
  String get labelKey {
    switch (this) {
      case ApplicationStage.notStarted:
        return 'stageNotStarted';
      case ApplicationStage.submitted:
        return 'stageSubmitted';
      case ApplicationStage.review:
        return 'stageReview';
      case ApplicationStage.needsAction:
        return 'stageNeedsAction';
      case ApplicationStage.approved:
        return 'stageApproved';
      case ApplicationStage.rejected:
        return 'stageRejected';
      case ApplicationStage.cancelled:
        return 'stageCancelled';
    }
  }

  /// Can the user still send or change papers?
  bool get canSubmit =>
      this == ApplicationStage.notStarted ||
      this == ApplicationStage.needsAction ||
      this == ApplicationStage.rejected ||
      this == ApplicationStage.cancelled;

  /// Was something sent that the OSCA office is (or was) looking at?
  bool get wasSent =>
      this != ApplicationStage.notStarted &&
      this != ApplicationStage.cancelled;

  static ApplicationStage parse(String? name) {
    return ApplicationStage.values.firstWhere(
          (s) => s.name == name,
      orElse: () => ApplicationStage.notStarted,
    );
  }
}

/// One line in the "What happened so far" list.
class StatusEvent {
  final ApplicationStage stage;
  final DateTime date;
  final String note;

  const StatusEvent({
    required this.stage,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory StatusEvent.fromJson(Map<String, dynamic> json) {
    return StatusEvent(
      stage: ApplicationStageText.parse(json['stage'] as String?),
      date: parseServerTime(json['date'] as String?) ?? DateTime.now(),
      note: json['note'] as String? ?? '',
    );
  }
}

class ApplicationStatus {
  final String applicationNo;
  final ApplicationStage stage;
  final String message;
  final DateTime? updatedAt;
  final List<StatusEvent> history;

  /// The papers the OSCA office has, with its decision on each one (GET
  /// /application "documents"). Empty when the office has none, e.g. an
  /// account registered at the office.
  final List<DocumentReview> documents;

  /// May the senior send or replace papers now? The server decides: true
  /// before a first submission, or when the office asked for new photos.
  final bool canUpload;

  /// The papers the office asked to be sent again. Empty when it asked for
  /// none (then a first submission needs all the papers).
  final List<DocumentType> reuploadTypes;

  const ApplicationStatus({
    required this.applicationNo,
    required this.stage,
    required this.message,
    this.updatedAt,
    this.history = const [],
    this.documents = const [],
    this.canUpload = false,
    this.reuploadTypes = const [],
  });

  /// The office's latest decision on [type], or null.
  DocumentReview? reviewOf(DocumentType type) {
    for (final review in documents) {
      if (review.type == type) return review;
    }
    return null;
  }

  /// May the senior send or replace this paper? Only when uploading is
  /// allowed, and, after a request for new photos, only for the papers asked
  /// for.
  bool canUploadType(DocumentType type) =>
      canUpload && (reuploadTypes.isEmpty || reuploadTypes.contains(type));

  factory ApplicationStatus.empty() => const ApplicationStatus(
    applicationNo: '',
    stage: ApplicationStage.notStarted,
    message: 'Send photos of your papers to start your application.',
    canUpload: true,
  );

  ApplicationStatus copyWith({
    String? applicationNo,
    ApplicationStage? stage,
    String? message,
    DateTime? updatedAt,
    List<StatusEvent>? history,
    List<DocumentReview>? documents,
    bool? canUpload,
    List<DocumentType>? reuploadTypes,
  }) {
    return ApplicationStatus(
      applicationNo: applicationNo ?? this.applicationNo,
      stage: stage ?? this.stage,
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
      documents: documents ?? this.documents,
      canUpload: canUpload ?? this.canUpload,
      reuploadTypes: reuploadTypes ?? this.reuploadTypes,
    );
  }

  Map<String, dynamic> toJson() => {
    'applicationNo': applicationNo,
    'stage': stage.name,
    'message': message,
    'updatedAt': updatedAt?.toIso8601String(),
    'history': history.map((e) => e.toJson()).toList(),
    'documents': documents.map((e) => e.toJson()).toList(),
    'canUpload': canUpload,
    'reuploadTypes': reuploadTypes.map((t) => t.name).toList(),
  };

  /// A saved copy from before [canUpload] existed reads the old way: the
  /// stage decides whether papers can be sent.
  factory ApplicationStatus.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    final rawDocuments = json['documents'];
    final rawReupload = json['reuploadTypes'];
    final stage = ApplicationStageText.parse(json['stage'] as String?);
    final canUpload = json['canUpload'];
    return ApplicationStatus(
      applicationNo: json['applicationNo'] as String? ?? '',
      stage: stage,
      message: json['message'] as String? ?? '',
      updatedAt: parseServerTime(json['updatedAt'] as String?),
      history: rawHistory is List
          ? rawHistory
          .whereType<Map>()
          .map((e) => StatusEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList()
          : const [],
      documents: rawDocuments is List
          ? rawDocuments
          .whereType<Map>()
          .map((e) => DocumentReview.tryFromJson(Map<String, dynamic>.from(e)))
          .whereType<DocumentReview>()
          .toList()
          : const [],
      canUpload: canUpload is bool ? canUpload : stage.canSubmit,
      reuploadTypes: rawReupload is List
          ? rawReupload
          .whereType<String>()
          .map((s) => DocumentTypeInfo.parse(s))
          .whereType<DocumentType>()
          .toList()
          : const [],
    );
  }
}

/// A message in the bell (Notifications) list. Kept in this file because
/// most notifications are about the application.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final bool read;

  /// The Medical or Burial request it is about (its reference),
  /// so the message can open it. Empty for other messages.
  final String requestReference;

  /// The request was approved and has a certificate to show at the office.
  final bool hasCertificate;

  /// What kind of message it is: "greeting" for a birthday greeting from the
  /// OSCA office, "" for everything else.
  final String kind;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.read = false,
    this.requestReference = '',
    this.hasCertificate = false,
    this.kind = '',
  });

  /// A birthday greeting from the OSCA office.
  bool get isGreeting => kind == 'greeting';

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    date: date,
    read: read ?? this.read,
    requestReference: requestReference,
    hasCertificate: hasCertificate,
    kind: kind,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
    'read': read,
    'request': requestReference.isEmpty ? null : {'reference': requestReference},
    'hasCertificate': hasCertificate,
    'kind': kind,
  };

  /// The backend sends {"id", "title", "body", "date"}, plus for an
  /// assistance decision "request": {"kind", "reference"} and
  /// "hasCertificate", and "kind": "greeting" for a birthday greeting.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final request = json['request'];
    return AppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      date: parseServerTime(json['date'] as String?) ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
      requestReference:
          request is Map ? (request['reference'] as String? ?? '') : '',
      hasCertificate: json['hasCertificate'] as bool? ?? false,
      kind: json['kind'] as String? ?? '',
    );
  }
}