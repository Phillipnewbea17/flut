import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/identity_verification.dart';
import '../models/personal_info.dart';
import '../services/identity_service.dart';
import '../storage/local_db.dart';
import '../utils/id_text_parser.dart';
import '../utils/personal_info_validator.dart';
import '../utils/senior_id_qr.dart';

/// First-time identity setup and the linked senior citizen profile.
///
/// Setup:  information (scan / photo / manual) -> review -> confirm ->
///         live selfie -> the backend checks and links the account.
///
/// The form is only a draft until the backend answers. Information read
/// from a QR code or a photo is never treated as official: it fills the
/// form, the user checks it, and the backend compares it with SCMS.
class IdentityRepository extends ChangeNotifier {
  IdentityRepository({required IdentityService service, required LocalDb db})
      : _service = service,
        _db = db;

  final IdentityService _service;
  final LocalDb _db;

  /// Failed selfies allowed before the user is asked to contact OSCA. The
  /// backend should have its own limit; this one stops the app from
  /// looping the user through retries.
  static const int maxSelfieAttempts = 3;

  static const _kProfile = 'linked_profile';
  static const _kAttempts = 'selfie_attempts';
  static const _kCorrections = 'profile_corrections';

  // Setup draft
  PersonalInfo _draft = PersonalInfo.empty;
  InfoSource _source = InfoSource.manual;
  IdentityMethod _method = IdentityMethod.manual;
  Set<PersonalField> _locked = const {};
  String _qrNameHint = '';
  bool _confirmed = false;
  int _failedAttempts = 0;
  VerificationResult? _lastResult;

  // Linked profile
  LinkedProfile? _profile;
  List<CorrectionRequest> _corrections = [];
  bool _loaded = false;

  /// True when the app has a backend address.
  bool get isLive => _service.isLive;

  PersonalInfo get draft => _draft;
  InfoSource get source => _source;
  IdentityMethod get method => _method;

  /// Fields that came from the SCMS record and cannot be edited here.
  Set<PersonalField> get lockedFields => _locked;
  bool get confirmed => _confirmed;
  int get failedAttempts => _failedAttempts;
  int get attemptsLeft => maxSelfieAttempts - _failedAttempts;
  bool get outOfAttempts => _failedAttempts >= maxSelfieAttempts;
  VerificationResult? get lastResult => _lastResult;

  LinkedProfile? get profile => _profile;

  /// The linked record's photo (from the backend, signed in), or null.
  ImageProvider? get profilePhoto {
    final url = _profile?.photoUrl ?? '';
    return url.isEmpty ? null : _service.profilePhoto(url);
  }
  List<CorrectionRequest> get corrections => List.unmodifiable(_corrections);

  // ---------------------------------------------------------------------------
  // Setup: getting the information
  // ---------------------------------------------------------------------------

  /// Starts (or restarts) setup for the account signed in with [phone].
  Future<void> begin(String phone) async {
    if (!_loaded) await _readCache();
    _draft = PersonalInfo(mobile: phone);
    _source = InfoSource.manual;
    _method = IdentityMethod.manual;
    _locked = const {};
    _qrNameHint = '';
    _confirmed = false;
    _lastResult = null;
    notifyListeners();
  }

  /// Manual entry: keeps what is already on the form.
  void useManualEntry() {
    _method = IdentityMethod.manual;
    if (_source != InfoSource.record) _source = InfoSource.manual;
    _confirmed = false;
    notifyListeners();
  }

  /// A QR code was read: look the ID up in SCMS. The form is filled only
  /// from the record the backend returns. When the lookup cannot be done
  /// (no connection), only the ID number is put on the form.
  Future<RecordLookup> lookupScannedId(ScannedSeniorId scanned) async {
    final result = await _service.lookup(scanned.seniorId);
    _method = IdentityMethod.qr;
    _qrNameHint = scanned.nameHint;
    switch (result.status) {
      case LookupStatus.found:
        _useRecord(result);
      case LookupStatus.unavailable:
        _draft = PersonalInfo(mobile: _draft.mobile, seniorId: scanned.seniorId)
            .fillBlanksFrom(_draft);
        _source = InfoSource.qr;
        _locked = const {};
        _confirmed = false;
        notifyListeners();
      case LookupStatus.notFound:
      case LookupStatus.alreadyLinked:
        break;
    }
    return result;
  }

  /// Text was read from a photo of the ID. It goes on the form; when it
  /// has an ID number, the record is looked up and its official fields
  /// replace what was read. Returns the lookup, or null when no ID number
  /// was read.
  Future<RecordLookup?> applyExtraction(IdExtraction extraction) async {
    _method = IdentityMethod.idPhoto;
    _qrNameHint = '';
    _draft = extraction.info.copyWith(mobile: _draft.mobile);
    _source = InfoSource.idPhoto;
    _locked = const {};
    _confirmed = false;
    notifyListeners();

    final id = extraction.info.seniorId;
    if (id.isEmpty) return null;
    final result = await _service.lookup(id);
    if (result.found) _useRecord(result, keep: _draft);
    return result;
  }

  void _useRecord(RecordLookup result, {PersonalInfo? keep}) {
    final record = result.record!;
    final base = (keep ?? PersonalInfo.empty).copyWith(mobile: _draft.mobile);
    _draft = base.overrideWith(record, result.lockedFields).fillBlanksFrom(record);
    _source = InfoSource.record;
    _locked = result.lockedFields;
    _confirmed = false;
    notifyListeners();
  }

  /// The user changed the form. Fields from the SCMS record stay as they
  /// were, whatever the screen sends.
  void updateDraft(PersonalInfo info) {
    var next = info.copyWith(mobile: _draft.mobile);
    if (_locked.isNotEmpty) next = next.overrideWith(_draft, _locked);
    _draft = next;
    _confirmed = false;
    notifyListeners();
  }

  /// "Confirm information". Returns the problems, or an empty map when the
  /// draft was confirmed.
  Map<PersonalField, String> confirmDraft() {
    final errors = PersonalInfoValidator.validate(_draft);
    _confirmed = errors.isEmpty;
    notifyListeners();
    return errors;
  }

  // ---------------------------------------------------------------------------
  // Setup: selfie and the backend's decision
  // ---------------------------------------------------------------------------

  /// Sends the confirmed information and the live selfie. Throws
  /// [IdentityException] when the backend could not be reached (that does
  /// not count as a failed try).
  Future<VerificationResult> verifySelfie(Uint8List selfie) async {
    if (!_confirmed) {
      throw StateError('Confirm the information before the selfie.');
    }
    if (outOfAttempts) {
      return _finish(const VerificationResult(VerificationStatus.tooManyAttempts));
    }

    var result = await _service.verify(
      info: _draft,
      method: _method,
      selfie: selfie,
      qrNameHint: _qrNameHint,
    );

    if (result.status == VerificationStatus.faceMismatch) {
      _failedAttempts++;
      final serverLeft = result.attemptsLeft;
      if (outOfAttempts || (serverLeft != null && serverLeft <= 0)) {
        result = VerificationResult(VerificationStatus.tooManyAttempts,
            message: result.message);
      }
      await _saveAttempts();
    } else if (result.status == VerificationStatus.tooManyAttempts) {
      _failedAttempts = maxSelfieAttempts;
      await _saveAttempts();
    }

    if (result.status.letsUserContinue) {
      final linked = result.profile ??
          LinkedProfile(
            info: _draft,
            state: switch (result.status) {
              VerificationStatus.verified => IdentityState.verified,
              _ => IdentityState.pendingReview,
            },
          );
      _profile = linked;
      _failedAttempts = 0;
      await _saveAttempts();
      await _saveProfile();
    }
    return _finish(result);
  }

  VerificationResult _finish(VerificationResult result) {
    _lastResult = result;
    notifyListeners();
    return result;
  }

  // ---------------------------------------------------------------------------
  // The linked profile (returning users, Account > Personal information)
  // ---------------------------------------------------------------------------

  /// Shows the saved profile, then asks the backend for the latest. Returns
  /// true only when the backend says this account must verify (again).
  Future<bool> load() async {
    if (!_loaded) await _readCache();
    notifyListeners();
    final fresh = await refreshFromServer();
    return fresh != null && fresh.state == IdentityState.unverified;
  }

  /// The record from the backend, or null when it cannot be asked.
  Future<LinkedProfile?> refreshFromServer() async {
    if (!_loaded) await _readCache();
    if (!_service.isLive) return null;
    try {
      final fresh = await _service.fetchProfile();
      if (fresh == null) return null;
      _profile = fresh;
      await _saveProfile();
      notifyListeners();
      return fresh;
    } catch (_) {
      return null; // Offline: keep the saved copy.
    }
  }

  /// Saves the fields the user may change (email, purok, house/street).
  Future<void> updateContact({
    required String email,
    required String purok,
    required String addressLine,
  }) async {
    final current = _profile;
    if (current == null) return;
    final info = current.info.copyWith(
      email: email.trim(),
      purok: purok.trim(),
      addressLine: addressLine.trim(),
    );
    await _service.updateContact(info);
    _profile = current.copyWith(info: info);
    await _saveProfile();
    notifyListeners();
  }

  Future<CorrectionRequest> requestCorrection({
    required PersonalField field,
    required String requestedValue,
    required String reason,
    String? attachmentPath,
  }) async {
    final current = _profile?.info.valueOf(field) ?? '';
    final request = await _service.requestCorrection(
      field: field,
      currentValue: current,
      requestedValue: requestedValue.trim(),
      reason: reason.trim(),
      attachmentPath: attachmentPath,
    );
    _corrections = [request, ..._corrections];
    await _saveCorrections();
    notifyListeners();
    return request;
  }

  Future<void> loadCorrections() async {
    if (!_loaded) await _readCache();
    if (!_service.isLive) {
      notifyListeners();
      return;
    }
    try {
      final fresh = await _service.fetchCorrections();
      _corrections = fresh;
      await _saveCorrections();
    } catch (_) {
      // Offline: keep the saved list.
    }
    notifyListeners();
  }

  /// Log out.
  void reset() {
    _draft = PersonalInfo.empty;
    _source = InfoSource.manual;
    _method = IdentityMethod.manual;
    _locked = const {};
    _qrNameHint = '';
    _confirmed = false;
    _failedAttempts = 0;
    _lastResult = null;
    _profile = null;
    _corrections = [];
    _loaded = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Saving on the phone
  // ---------------------------------------------------------------------------

  Future<void> _readCache() async {
    try {
      final raw = await _db.read(_kProfile);
      if (raw is Map) {
        _profile = LinkedProfile.fromJson(Map<String, dynamic>.from(raw));
      }
      final attempts = await _db.read(_kAttempts);
      if (attempts is int) _failedAttempts = attempts;
      final list = await _db.read(_kCorrections);
      if (list is List) {
        _corrections = list
            .whereType<Map>()
            .map((e) => CorrectionRequest.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      // Unreadable copy: start empty.
    }
    _loaded = true;
  }

  Future<void> _saveProfile() async {
    try {
      await _db.write(_kProfile, _profile?.toJson());
    } catch (_) {}
  }

  Future<void> _saveAttempts() async {
    try {
      await _db.write(_kAttempts, _failedAttempts);
    } catch (_) {}
  }

  Future<void> _saveCorrections() async {
    try {
      await _db.write(
          _kCorrections, _corrections.map((c) => c.toJson()).toList());
    } catch (_) {}
  }
}
