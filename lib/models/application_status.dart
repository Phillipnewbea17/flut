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
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
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

  /// The office's decision on each paper. Optional: the backend does not
  /// send per-paper results yet (it only has one note for the whole
  /// application), so this is usually empty and [message] explains instead.
  final List<DocumentReview> documents;

  const ApplicationStatus({
    required this.applicationNo,
    required this.stage,
    required this.message,
    this.updatedAt,
    this.history = const [],
    this.documents = const [],
  });

  /// The office's latest decision on [type], or null.
  DocumentReview? reviewOf(DocumentType type) {
    for (final review in documents) {
      if (review.type == type) return review;
    }
    return null;
  }

  factory ApplicationStatus.empty() => const ApplicationStatus(
    applicationNo: '',
    stage: ApplicationStage.notStarted,
    message: 'Send photos of your papers to start your application.',
  );

  ApplicationStatus copyWith({
    String? applicationNo,
    ApplicationStage? stage,
    String? message,
    DateTime? updatedAt,
    List<StatusEvent>? history,
    List<DocumentReview>? documents,
  }) {
    return ApplicationStatus(
      applicationNo: applicationNo ?? this.applicationNo,
      stage: stage ?? this.stage,
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
      documents: documents ?? this.documents,
    );
  }

  Map<String, dynamic> toJson() => {
    'applicationNo': applicationNo,
    'stage': stage.name,
    'message': message,
    'updatedAt': updatedAt?.toIso8601String(),
    'history': history.map((e) => e.toJson()).toList(),
    'documents': documents.map((e) => e.toJson()).toList(),
  };

  factory ApplicationStatus.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    final rawDocuments = json['documents'];
    return ApplicationStatus(
      applicationNo: json['applicationNo'] as String? ?? '',
      stage: ApplicationStageText.parse(json['stage'] as String?),
      message: json['message'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      history: rawHistory is List
          ? rawHistory
          .whereType<Map>()
          .map((e) => StatusEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList()
          : const [],
      documents: rawDocuments is List
          ? rawDocuments
          .whereType<Map>()
          .map((e) => DocumentReview.fromJson(Map<String, dynamic>.from(e)))
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

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    date: date,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
    'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
    );
  }
}