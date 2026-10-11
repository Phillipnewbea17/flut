import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../models/identity_verification.dart';
import '../models/personal_info.dart';
import 'api_client.dart';

/// How the user gave their information (sent to the backend for its logs).
enum IdentityMethod { qr, idPhoto, manual }

/// Identity verification and account linking. The SCMS backend makes every
/// decision (record found, face matched, account linked); the app only
/// collects the information and shows the answer.
abstract class IdentityService {
  /// True when the app has a backend address.
  bool get isLive;

  /// Looks up the SCMS senior citizen record with [seniorId].
  Future<RecordLookup> lookup(String seniorId);

  /// Sends the confirmed information and a live selfie. The backend matches
  /// the record and the face, and links the account when they match.
  Future<VerificationResult> verify({
    required PersonalInfo info,
    required IdentityMethod method,
    required Uint8List selfie,
    String qrNameHint = '',
  });

  /// The linked record, as the backend has it now. Null when the backend
  /// cannot be asked (offline).
  Future<LinkedProfile?> fetchProfile();

  /// Sends changes to the fields the user may edit themselves.
  Future<void> updateContact(PersonalInfo info);

  /// Asks OSCA to correct an official field.
  Future<CorrectionRequest> requestCorrection({
    required PersonalField field,
    required String currentValue,
    required String requestedValue,
    required String reason,
    String? attachmentPath,
  });

  /// The user's correction requests and OSCA's answers.
  Future<List<CorrectionRequest>> fetchCorrections();

  /// The profile photo, loaded with the sign-in token. Null when there is
  /// none, or when [photoUrl] is not on the SCMS backend (the token is
  /// never sent anywhere else).
  ImageProvider? profilePhoto(String photoUrl);
}

/// Thrown when the backend could not be reached or answered with an error
/// the user cannot fix. [message] is shown as-is.
class IdentityException implements Exception {
  final String message;
  const IdentityException(this.message);

  @override
  String toString() => message;
}

/// The real service: /api/mobile/identity/* and /api/mobile/profile on the
/// SCMS backend.
class ApiIdentityService implements IdentityService {
  ApiIdentityService(this._api);

  final ApiClient _api;

  static const String unavailableMessage =
      'Identity checking is not available yet. Please contact the OSCA '
      'office for help.';

  @override
  bool get isLive => _api.isConnected;

  /// Laravel answers 404 without a "code" when a route does not exist.
  static bool _routeMissing(ApiException e) =>
      e.statusCode == 404 && (e.code == null || e.code!.isEmpty);

  @override
  Future<RecordLookup> lookup(String seniorId) async {
    try {
      final data = await _api.post('/identity/lookup', {'seniorId': seniorId});
      final status = data['status'] as String?;
      if (status == 'already_linked') {
        return RecordLookup(LookupStatus.alreadyLinked,
            message: data['message'] as String?);
      }
      if (status == 'not_found') {
        return RecordLookup(LookupStatus.notFound,
            message: data['message'] as String?);
      }
      final record = data['record'];
      if (status == 'found' && record is Map) {
        final locked = (data['lockedFields'] as List? ?? const [])
            .map((f) => PersonalFieldInfo.tryParse(f?.toString()))
            .whereType<PersonalField>()
            .toSet();
        return RecordLookup(
          LookupStatus.found,
          record: PersonalInfo.fromJson(Map<String, dynamic>.from(record)),
          lockedFields: locked.isEmpty
              ? PersonalFieldInfo.oscaManaged
              : locked,
        );
      }
      throw const IdentityException('Something went wrong. Please try again.');
    } on ApiException catch (e) {
      if (e.code == 'not_found') {
        return RecordLookup(LookupStatus.notFound, message: e.message);
      }
      if (e.code == 'already_linked') {
        return RecordLookup(LookupStatus.alreadyLinked, message: e.message);
      }
      if (_routeMissing(e)) {
        return const RecordLookup(LookupStatus.unavailable,
            message: unavailableMessage);
      }
      throw IdentityException(e.message);
    }
  }

  @override
  Future<VerificationResult> verify({
    required PersonalInfo info,
    required IdentityMethod method,
    required Uint8List selfie,
    String qrNameHint = '',
  }) async {
    try {
      final data = await _api.postBytes(
        '/identity/verify',
        bytes: selfie,
        filename: 'selfie.jpg',
        fields: {
          ...info.toFields(),
          'method': method.name,
          if (qrNameHint.isNotEmpty) 'qrNameHint': qrNameHint,
        },
      );
      return _result(data);
    } on ApiException catch (e) {
      if (_routeMissing(e)) {
        return const VerificationResult(VerificationStatus.unavailable,
            message: unavailableMessage);
      }
      if (e.code != null && e.code!.isNotEmpty) {
        final status = VerificationStatusInfo.parse(e.code);
        if (status != VerificationStatus.unavailable) {
          return VerificationResult(status, message: e.message);
        }
      }
      throw IdentityException(e.message);
    }
  }

  static VerificationResult _result(Map<String, dynamic> data) {
    final profile = data['profile'];
    return VerificationResult(
      VerificationStatusInfo.parse(data['status'] as String?),
      message: data['message'] as String?,
      attemptsLeft: (data['attemptsLeft'] as num?)?.toInt(),
      profile: profile is Map
          ? LinkedProfile.fromJson(Map<String, dynamic>.from(profile))
          : null,
    );
  }

  @override
  Future<LinkedProfile?> fetchProfile() async {
    try {
      final data = await _api.get('/profile');
      if (data is! Map) return null;
      return LinkedProfile.fromJson(Map<String, dynamic>.from(data));
    } on ApiException catch (e) {
      if (_routeMissing(e)) return null;
      rethrow;
    }
  }

  @override
  Future<void> updateContact(PersonalInfo info) async {
    try {
      // Only the fields the user may change. The backend must ignore
      // official fields here for linked accounts.
      final result = await _api.post('/profile', {
        'email': info.email.trim(),
        'purok': info.purok.trim(),
        'addressLine': info.addressLine.trim(),
      });
      if (result['ok'] != true) {
        throw const IdentityException('Your changes were not saved. '
            'Please try again.');
      }
    } on ApiException catch (e) {
      throw IdentityException(e.message);
    }
  }

  @override
  Future<CorrectionRequest> requestCorrection({
    required PersonalField field,
    required String currentValue,
    required String requestedValue,
    required String reason,
    String? attachmentPath,
  }) async {
    try {
      final body = {
        'field': field.name,
        'currentValue': currentValue,
        'requestedValue': requestedValue,
        'reason': reason,
      };
      final data = attachmentPath == null
          ? await _api.post('/profile/corrections', body)
          : await _api.postFile('/profile/corrections',
              filePath: attachmentPath, fields: body);
      final reference = data['reference'] as String?;
      if (data['ok'] != true || reference == null) {
        throw const IdentityException('Your request was not sent. '
            'Please try again.');
      }
      return CorrectionRequest(
        reference: reference,
        field: field,
        currentValue: currentValue,
        requestedValue: requestedValue,
        reason: reason,
        status: CorrectionStatus.pending,
        submittedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      if (_routeMissing(e)) {
        throw const IdentityException('Correction requests are not available '
            'in the app yet. Please visit or call the OSCA office.');
      }
      throw IdentityException(e.message);
    }
  }

  @override
  ImageProvider? profilePhoto(String photoUrl) {
    final token = _api.token;
    if (photoUrl.isEmpty || token == null) return null;
    final base = Uri.parse(_api.baseUrl);
    final url = base.resolve(photoUrl);
    if (url.scheme != base.scheme ||
        url.host != base.host ||
        url.port != base.port) {
      return null;
    }
    return NetworkImage(url.toString(),
        headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<List<CorrectionRequest>> fetchCorrections() async {
    try {
      final data = await _api.get('/profile/corrections');
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => CorrectionRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException catch (e) {
      if (_routeMissing(e)) return const [];
      rethrow;
    }
  }
}
