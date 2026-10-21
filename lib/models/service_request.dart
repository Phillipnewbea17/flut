import 'package:flutter/material.dart';

import '../utils/manila_time.dart';
import 'assistance_certificate.dart';

/// Requests a senior sends to the OSCA office from the app. Each kind
/// matches a module of the SCMS web app, where staff process it:
///   medical       -> Medical Requests
///   burial        -> Burial Requests
///   help          -> Help & Complaint Desk
///   idReplacement -> Senior ID Management ("Request replacement")
///
/// Medical and burial end in a Certificate of Eligibility once the office
/// approves them (see [ServiceRequest.certificate]). Pension is not
/// requested: only the office issues it (Benefits shows the releases).
enum RequestKind { medical, burial, help, idReplacement }

extension RequestKindInfo on RequestKind {
  String get title {
    switch (this) {
      case RequestKind.medical:
        return 'Medical assistance';
      case RequestKind.burial:
        return 'Burial assistance';
      case RequestKind.help:
        return 'Help & complaints';
      case RequestKind.idReplacement:
        return 'ID replacement';
    }
  }

  /// SCMS backend address (/api/mobile). GET lists the account's own requests,
  /// POST creates one (see RequestsService for the JSON).
  String get apiPath {
    switch (this) {
      case RequestKind.medical:
        return '/medical-requests';
      case RequestKind.burial:
        return '/burial-requests';
      case RequestKind.help:
        return '/help-requests';
      case RequestKind.idReplacement:
        return '/senior-id/replacement-requests';
    }
  }

  static RequestKind parse(String? name) => RequestKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => RequestKind.help,
      );
}

/// One status list for every kind of request. The web modules use different
/// words, so [RequestStatusInfo.parse] maps them, and ServiceRequest keeps
/// the office's own word in [ServiceRequest.statusText] to show the senior
/// exactly what staff see.
enum RequestStatus {
  /// Only on this phone: never reached the OSCA office.
  notSent,
  pending,
  inProgress,
  onHold,
  approved,
  completed,
  rejected,
  closed,
}

extension RequestStatusInfo on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.notSent:
        return 'Not sent yet';
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.inProgress:
        return 'Under review';
      case RequestStatus.onHold:
        return 'On hold';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.rejected:
        return 'Not approved';
      case RequestStatus.closed:
        return 'Closed';
    }
  }

  /// Still waiting for something (shown under "Current requests").
  bool get isActive =>
      this == RequestStatus.notSent ||
      this == RequestStatus.pending ||
      this == RequestStatus.inProgress ||
      this == RequestStatus.onHold ||
      this == RequestStatus.approved;

  /// Status words from the SCMS web modules:
  ///   Medical, Burial: Pending, On Hold, Approved (certificate issued),
  ///              Declined, Claimed (collected at the office)
  ///   Help Desk: Pending, Working on it, Resolved, Closed
  ///   Senior ID: For Replacement (the request is open)
  /// Older words (Completed, Released) still read as completed.
  static RequestStatus parse(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'notsent':
        return RequestStatus.notSent;
      case 'inprogress':
      case 'under review':
      case 'working on it':
      case 'for replacement':
        return RequestStatus.inProgress;
      case 'onhold':
      case 'on hold':
        return RequestStatus.onHold;
      case 'approved':
        return RequestStatus.approved;
      case 'completed':
      case 'released':
      case 'claimed':
      case 'resolved':
      case 'replaced':
        return RequestStatus.completed;
      case 'rejected':
      case 'denied':
      case 'declined':
        return RequestStatus.rejected;
      case 'closed':
      case 'cancelled':
        return RequestStatus.closed;
      default:
        return RequestStatus.pending;
    }
  }
}

/// The words every screen shows for a request's status (display only; the
/// stored [RequestStatus] and the office's [ServiceRequest.statusText] are
/// never changed).
///   Active:    Submitted, Under review, Needs action
///   Completed: Approved, Rejected, Cancelled
/// A value outside this list ([other]) is shown as its own words.
enum RequestDisplayStatus {
  notSent,
  submitted,
  underReview,
  needsAction,
  approved,
  rejected,
  cancelled,
  other,
}

extension RequestDisplayStatusInfo on RequestDisplayStatus {
  /// The fixed words. Null for [RequestDisplayStatus.other] (raw text).
  String? get label => switch (this) {
        RequestDisplayStatus.notSent => 'Not sent yet',
        RequestDisplayStatus.submitted => 'Submitted',
        RequestDisplayStatus.underReview => 'Under review',
        RequestDisplayStatus.needsAction => 'Needs action',
        RequestDisplayStatus.approved => 'Approved',
        RequestDisplayStatus.rejected => 'Rejected',
        RequestDisplayStatus.cancelled => 'Cancelled',
        RequestDisplayStatus.other => null,
      };
}

/// The groups on Applications and My requests.
enum RequestCategory { medical, burial, documents, complaints }

extension RequestCategoryInfo on RequestCategory {
  String get label => switch (this) {
        RequestCategory.medical => 'Medical',
        RequestCategory.burial => 'Burial',
        RequestCategory.documents => 'Documents',
        RequestCategory.complaints => 'Complaints',
      };

  IconData get icon => switch (this) {
        RequestCategory.medical => Icons.medical_services_outlined,
        RequestCategory.burial => Icons.local_florist_outlined,
        RequestCategory.documents => Icons.description_outlined,
        RequestCategory.complaints => Icons.forum_outlined,
      };
}

/// A label and value shown on the review and detail screens,
/// e.g. ("Type of help", "Medicine").
class RequestDetail {
  final String label;
  final String value;

  const RequestDetail(this.label, this.value);

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  factory RequestDetail.fromJson(Map<String, dynamic> json) => RequestDetail(
        json['label'] as String? ?? '',
        json['value'] as String? ?? '',
      );
}

/// A public update from the office ("What happened so far"). The backend
/// must only send updates meant for the senior, never internal staff notes.
class RequestEvent {
  final DateTime date;
  final String note;

  const RequestEvent({required this.date, required this.note});

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'note': note};

  factory RequestEvent.fromJson(Map<String, dynamic> json) => RequestEvent(
        date: parseServerTime(json['date'] as String?) ?? DateTime.now(),
        note: json['note'] as String? ?? '',
      );
}

class ServiceRequest {
  /// Made on the phone, sent as "clientId" so sending twice is harmless.
  final String id;
  final RequestKind kind;

  /// From the office, e.g. "MA-2026-0012". Empty until it was received.
  final String reference;
  final RequestStatus status;

  /// The office's own status word ("Working on it"). Empty = [status].label.
  final String statusText;

  /// Short name, e.g. "Medicine" or "Senior ID concern".
  final String title;

  /// What the senior entered, in the words shown on screen.
  final List<RequestDetail> details;

  /// What is sent to the backend (camelCase keys).
  final Map<String, String> payload;

  /// Photos saved on the phone (DocumentVault) to send with the request.
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  /// The office's latest message to the senior.
  final String latestResponse;
  final List<RequestEvent> history;

  /// Why the last try to send failed, if it did.
  final String? sendError;

  /// Medical and burial: the Certificate of Eligibility, once the office
  /// approved the request. Null before that (and for other kinds).
  final AssistanceCertificate? certificate;

  const ServiceRequest({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.reference = '',
    this.status = RequestStatus.notSent,
    this.statusText = '',
    this.details = const [],
    this.payload = const {},
    this.attachments = const [],
    this.submittedAt,
    this.updatedAt,
    this.latestResponse = '',
    this.history = const [],
    this.sendError,
    this.certificate,
  });

  bool get isSent => status != RequestStatus.notSent;

  String get statusLabel => statusText.isNotEmpty ? statusText : status.label;

  /// Which status words to show (see [RequestDisplayStatus]). "Pending"
  /// shows as Submitted; an unknown word stays as it is ([other]).
  RequestDisplayStatus get displayStatus {
    switch (statusText.trim().toLowerCase()) {
      case 'pending':
      case 'submitted':
        return RequestDisplayStatus.submitted;
      case 'under review':
      case 'working on it':
      case 'for replacement':
        return RequestDisplayStatus.underReview;
      case 'needs action':
      case 'on hold':
        return RequestDisplayStatus.needsAction;
      case 'approved':
        return RequestDisplayStatus.approved;
      case 'rejected':
      case 'denied':
      case 'declined':
      case 'not approved':
        return RequestDisplayStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return RequestDisplayStatus.cancelled;
      case '':
        break; // no office word: use the stored status below
      default:
        return RequestDisplayStatus.other;
    }
    return switch (status) {
      RequestStatus.notSent => RequestDisplayStatus.notSent,
      RequestStatus.pending => RequestDisplayStatus.submitted,
      RequestStatus.inProgress => RequestDisplayStatus.underReview,
      RequestStatus.onHold => RequestDisplayStatus.needsAction,
      RequestStatus.approved => RequestDisplayStatus.approved,
      RequestStatus.rejected => RequestDisplayStatus.rejected,
      RequestStatus.completed || RequestStatus.closed =>
        RequestDisplayStatus.other,
    };
  }

  /// The words on the status chip.
  String get displayLabel => displayStatus.label ?? statusLabel;

  /// Active = Submitted, Under review, Needs action (and requests not sent
  /// yet). Completed = Approved, Rejected, Cancelled, and any other word
  /// the office uses for a finished request (Released, Resolved, Closed).
  bool get isActive => switch (displayStatus) {
        RequestDisplayStatus.notSent ||
        RequestDisplayStatus.submitted ||
        RequestDisplayStatus.underReview ||
        RequestDisplayStatus.needsAction =>
          true,
        RequestDisplayStatus.other => status.isActive &&
            status != RequestStatus.approved,
        _ => false,
      };

  /// Medical, Burial, Documents (Senior ID replacement) or Complaints
  /// (Help & complaints).
  RequestCategory get category => switch (kind) {
        RequestKind.medical => RequestCategory.medical,
        RequestKind.burial => RequestCategory.burial,
        RequestKind.idReplacement => RequestCategory.documents,
        RequestKind.help => RequestCategory.complaints,
      };

  /// Sent (or saved) date, for "newest first" and the row date.
  DateTime get sortDate => submittedAt ?? createdAt;

  /// The newest date anything happened.
  DateTime get lastActivity => updatedAt ?? submittedAt ?? createdAt;

  ServiceRequest copyWith({
    String? reference,
    RequestStatus? status,
    String? statusText,
    DateTime? submittedAt,
    DateTime? updatedAt,
    String? latestResponse,
    List<RequestEvent>? history,
    String? Function()? sendError,
  }) {
    return ServiceRequest(
      id: id,
      kind: kind,
      title: title,
      createdAt: createdAt,
      details: details,
      payload: payload,
      attachments: attachments,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latestResponse: latestResponse ?? this.latestResponse,
      history: history ?? this.history,
      sendError: sendError == null ? this.sendError : sendError(),
      certificate: certificate,
    );
  }

  /// Copies what the office knows ([server]) onto this request, keeping
  /// what only the phone has (the entered details and photos).
  ServiceRequest mergeServer(ServiceRequest server) {
    return ServiceRequest(
      id: id,
      kind: kind,
      title: server.title.isNotEmpty ? server.title : title,
      createdAt: createdAt,
      details: server.details.isNotEmpty ? server.details : details,
      payload: payload,
      attachments: attachments,
      reference: server.reference,
      status: server.status,
      statusText: server.statusText,
      submittedAt: server.submittedAt ?? submittedAt,
      updatedAt: server.updatedAt ?? updatedAt,
      latestResponse: server.latestResponse,
      history: server.history.isNotEmpty ? server.history : history,
      certificate: server.certificate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'reference': reference,
        'status': status.name,
        'statusText': statusText,
        'title': title,
        'details': details.map((d) => d.toJson()).toList(),
        'payload': payload,
        'attachments': attachments,
        'createdAt': createdAt.toIso8601String(),
        'submittedAt': submittedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'latestResponse': latestResponse,
        'history': history.map((e) => e.toJson()).toList(),
        'sendError': sendError,
        'certificate': certificate?.toJson(),
      };

  /// Reads both the copy saved on the phone and the backend's answer:
  ///   {"clientId": "...", "reference": "MA-2026-0012", "status": "Pending",
  ///    "title": "Medicine", "submittedAt": "...", "updatedAt": "...",
  ///    "latestResponse": "...", "details": [{"label": "", "value": ""}],
  ///    "history": [{"date": "...", "note": "..."}],
  ///    "certificate": {...} or null (see AssistanceCertificate)}
  factory ServiceRequest.fromJson(
    Map<String, dynamic> json, {
    RequestKind? kind,
  }) {
    final rawStatus = json['status'] as String?;
    final known = RequestStatus.values.any((s) => s.name == rawStatus);
    final rawPayload = json['payload'];
    return ServiceRequest(
      id: json['id'] as String? ??
          json['clientId'] as String? ??
          json['reference'] as String? ??
          '',
      kind: kind ?? RequestKindInfo.parse(json['kind'] as String?),
      reference: json['reference'] as String? ?? '',
      status: RequestStatusInfo.parse(rawStatus),
      // Saved copies keep their own text; server words are shown as-is.
      statusText: json['statusText'] as String? ??
          (known ? '' : (rawStatus ?? '')),
      title: json['title'] as String? ?? '',
      details: _list(json['details'], RequestDetail.fromJson),
      payload: rawPayload is Map
          ? rawPayload.map((k, v) => MapEntry('$k', '$v'))
          : const {},
      attachments: (json['attachments'] as List?)?.whereType<String>().toList() ??
          const [],
      createdAt: parseServerTime(json['createdAt'] as String?) ??
          parseServerTime(json['submittedAt'] as String?) ??
          DateTime.now(),
      submittedAt: parseServerTime(json['submittedAt'] as String?),
      updatedAt: parseServerTime(json['updatedAt'] as String?),
      latestResponse: json['latestResponse'] as String? ?? '',
      history: _list(json['history'], RequestEvent.fromJson),
      sendError: json['sendError'] as String?,
      certificate: AssistanceCertificate.fromJson(json['certificate']),
    );
  }

  static List<T> _list<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => parse(Map<String, dynamic>.from(e)))
        .toList();
  }
}
