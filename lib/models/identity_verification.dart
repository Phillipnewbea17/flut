import '../utils/manila_time.dart';
import 'personal_info.dart';

/// Answer to "is there an SCMS senior citizen record with this ID?".
enum LookupStatus {
  /// A record exists and is free to link. [RecordLookup.record] has the
  /// information the backend allows the app to show.
  found,

  /// No record has this ID.
  notFound,

  /// The record is already linked to another account.
  alreadyLinked,

  /// The lookup could not be done (no connection, or the backend does not have
  /// the route yet). Nothing is known about the record.
  unavailable,
}

class RecordLookup {
  final LookupStatus status;

  /// Only for [LookupStatus.found].
  final PersonalInfo? record;

  /// Fields of [record] that are official and cannot be edited in the app.
  final Set<PersonalField> lockedFields;

  /// The backend's own words, when it sent any.
  final String? message;

  const RecordLookup(
    this.status, {
    this.record,
    this.lockedFields = const {},
    this.message,
  });

  bool get found => status == LookupStatus.found && record != null;
}

/// The backend's answer after the selfie and the information were checked.
enum VerificationStatus {
  /// Face matched and the account is now linked to the SCMS record.
  verified,

  /// The ID number, name and birthday match the record; OSCA staff must
  /// still check the selfie before the account is linked.
  pendingReview,

  /// The selfie did not match the record's photo.
  faceMismatch,

  /// The information did not match the record (for example the birthday
  /// is different from the one in SCMS).
  infoMismatch,

  /// No SCMS record matches the information.
  notFound,

  /// The record is already linked to another account.
  alreadyLinked,

  /// Too many failed tries. Only OSCA can help now.
  tooManyAttempts,

  /// The backend does not offer identity verification yet.
  unavailable,
}

extension VerificationStatusInfo on VerificationStatus {
  static VerificationStatus parse(String? value) => switch (value) {
        'verified' => VerificationStatus.verified,
        'pending' || 'pending_review' => VerificationStatus.pendingReview,
        'face_mismatch' => VerificationStatus.faceMismatch,
        'info_mismatch' || 'mismatch' => VerificationStatus.infoMismatch,
        'not_found' => VerificationStatus.notFound,
        'already_linked' => VerificationStatus.alreadyLinked,
        'too_many_attempts' || 'locked' => VerificationStatus.tooManyAttempts,
        _ => VerificationStatus.unavailable,
      };

  /// The account may go on to the app. Only the backend's own decisions
  /// count. While OSCA checks the selfie (pending) the app opens, but the
  /// services that need the linked record stay closed until it is linked.
  bool get letsUserContinue =>
      this == VerificationStatus.verified ||
      this == VerificationStatus.pendingReview;

  /// Trying the selfie again may help.
  bool get canRetry =>
      this == VerificationStatus.faceMismatch;
}

class VerificationResult {
  final VerificationStatus status;
  final String? message;

  /// The linked SCMS record (verified) or what was sent (pending review).
  final LinkedProfile? profile;

  /// Tries left, when the backend says.
  final int? attemptsLeft;

  const VerificationResult(
    this.status, {
    this.message,
    this.profile,
    this.attemptsLeft,
  });
}

/// How far the account is with identity verification, as the backend
/// sees it.
enum IdentityState {
  /// Not done yet (or the backend asks for it again).
  unverified,

  /// Sent; OSCA staff will check it.
  pendingReview,

  /// Linked to an SCMS senior citizen record.
  verified,
}

extension IdentityStateInfo on IdentityState {
  static IdentityState parse(String? value) => switch (value) {
        'verified' => IdentityState.verified,
        'pending' || 'pending_review' => IdentityState.pendingReview,
        _ => IdentityState.unverified,
      };

  String get label => switch (this) {
        IdentityState.verified => 'Verified Senior Citizen',
        IdentityState.pendingReview => 'Waiting for OSCA to check',
        IdentityState.unverified => 'Not verified yet',
      };

  /// The setup screens are finished for this account.
  bool get setupDone => this != IdentityState.unverified;
}

/// The account's senior citizen profile: the SCMS record it is linked to.
class LinkedProfile {
  final PersonalInfo info;
  final IdentityState state;

  /// The web's registration status ("Active", "Pending"...), as-is.
  final String registrationStatus;

  /// Profile photo address on the backend (needs the sign-in token). Never
  /// a path on the phone.
  final String photoUrl;

  /// The app-profile photo (Account) is on the server.
  final bool hasPhoto;

  /// Changes with every upload of the app-profile photo; "" without one.
  /// The phone compares it with the version it saved (UserRepository.syncPhoto).
  final String photoVersion;

  const LinkedProfile({
    required this.info,
    required this.state,
    this.registrationStatus = '',
    this.photoUrl = '',
    this.hasPhoto = false,
    this.photoVersion = '',
  });

  bool get isVerified => state == IdentityState.verified;

  LinkedProfile copyWith({PersonalInfo? info, IdentityState? state}) =>
      LinkedProfile(
        info: info ?? this.info,
        state: state ?? this.state,
        registrationStatus: registrationStatus,
        photoUrl: photoUrl,
        hasPhoto: hasPhoto,
        photoVersion: photoVersion,
      );

  Map<String, dynamic> toJson() => {
        ...info.toJson(),
        'identityStatus': switch (state) {
          IdentityState.verified => 'verified',
          IdentityState.pendingReview => 'pending',
          IdentityState.unverified => 'unverified',
        },
        'registrationStatus': registrationStatus,
        'photoUrl': photoUrl,
        'hasPhoto': hasPhoto,
        'photoVersion': photoVersion,
      };

  factory LinkedProfile.fromJson(Map<String, dynamic> json) => LinkedProfile(
        info: PersonalInfo.fromJson(json),
        state: IdentityStateInfo.parse(json['identityStatus'] as String?),
        registrationStatus: json['registrationStatus'] as String? ?? '',
        photoUrl: json['photoUrl'] as String? ?? '',
        hasPhoto: json['hasPhoto'] as bool? ?? false,
        photoVersion: json['photoVersion'] as String? ?? '',
      );
}

/// A request to OSCA to fix an official field.
enum CorrectionStatus { pending, approved, rejected }

class CorrectionRequest {
  final String reference;
  final PersonalField field;
  final String currentValue;
  final String requestedValue;
  final String reason;
  final CorrectionStatus status;
  final String officeNote;
  final DateTime submittedAt;

  /// True when it only exists on this phone (it was not sent).
  final bool localOnly;

  const CorrectionRequest({
    required this.reference,
    required this.field,
    required this.currentValue,
    required this.requestedValue,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.officeNote = '',
    this.localOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'field': field.name,
        'currentValue': currentValue,
        'requestedValue': requestedValue,
        'reason': reason,
        'status': status.name,
        'officeNote': officeNote,
        'submittedAt': submittedAt.toIso8601String(),
        'localOnly': localOnly,
      };

  factory CorrectionRequest.fromJson(Map<String, dynamic> json) =>
      CorrectionRequest(
        reference: json['reference'] as String? ?? '',
        field: PersonalFieldInfo.tryParse(json['field'] as String?) ??
            PersonalField.firstName,
        currentValue: json['currentValue'] as String? ?? '',
        requestedValue: json['requestedValue'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        status: CorrectionStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String? ?? '').toLowerCase(),
          orElse: () => CorrectionStatus.pending,
        ),
        officeNote: json['officeNote'] as String? ?? '',
        submittedAt: parseServerTime(json['submittedAt'] as String?) ??
            DateTime.now(),
        localOnly: json['localOnly'] as bool? ?? false,
      );
}
