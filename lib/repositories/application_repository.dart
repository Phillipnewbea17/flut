import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/application_status.dart';
import '../services/api_client.dart';
import '../storage/local_db.dart';

/// The user's Senior Citizen ID application + the bell notifications.
///
/// The status follows what the user really does:
///   Not started -> (user sends papers) Submitted -> Under review -> Approved
///
/// After the papers are sent, the status stays at "Submitted" until the
/// OSCA office changes it. When the backend is connected, [load] asks the
/// server (your SCMS admin app) for the latest status.
///
/// For testing only, [simulateOscaReview] can be set to true. The app then
/// pretends to be the OSCA office and moves the application forward by
/// itself after the waiting times below.
class ApplicationRepository extends ChangeNotifier {
  ApplicationRepository({
    required ApiClient api,
    required LocalDb db,
    DateTime Function()? clock,
  })  : _api = api,
        _db = db,
        _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final LocalDb _db;
  final DateTime Function() _clock;

  /// false = the status only changes when the OSCA office updates it.
  /// true  = testing: the app moves it forward by itself (see below).
  static const bool simulateOscaReview = false;

  /// Waiting times used only when [simulateOscaReview] is true.
  static const Duration reviewStartsAfter = Duration(minutes: 1);
  static const Duration approvedAfter = Duration(minutes: 3);

  static const _kStatus = 'application_status';
  static const _kNotifications = 'notifications';

  /// Texts written by the test mode. When the test mode is off, steps with
  /// these notes are removed again (they did not come from the OSCA office).
  static const _simReviewNote = 'The OSCA office started checking your papers.';
  static const _simApprovedNote = 'The OSCA office approved your application.';
  static const _simTitles = {'Application under review', 'Application approved'};

  /// Values from the old sample data, removed from phones that saved them.
  static const _oldSampleApplicationNo = 'SC-2026-001284';
  static const _oldSampleNotificationId = 'n-1001';

  ApplicationStatus _status = ApplicationStatus.empty();
  List<AppNotification> _notifications = [];
  bool _cacheLoaded = false;
  bool _loading = false;
  String? _error;
  Timer? _timer;

  ApplicationStatus get status => _status;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;
  bool get loading => _loading;

  /// The backend has no "cancel", so only offline applications can be
  /// taken back from the app.
  bool get canCancel =>
      !_api.isConnected && _status.stage == ApplicationStage.submitted;

  /// Set when the last refresh failed (the saved copy is still shown).
  String? get error => _error;

  /// Shows the saved status right away, then refreshes the notifications
  /// and moves the application forward if it is time.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    if (!_cacheLoaded) await _readCache();
    notifyListeners();

    try {
      final listData = await _api.get('/notifications');
      if (listData is List) {
        _notifications = _merge(
          listData
              .whereType<Map>()
              .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }
      if (_api.isConnected) await _refreshStatus();
      _error = null;
    } catch (_) {
      _error = 'No internet. Showing the information saved on this phone.';
    }

    _advanceIfDue();
    await _saveCache();
    _loading = false;
    notifyListeners();
    _syncTimer();
  }

  /// Called after the papers were sent from Upload documents.
  Future<void> markSubmitted(String reference) async {
    final now = _clock();
    _status = ApplicationStatus(
      applicationNo: reference,
      stage: ApplicationStage.submitted,
      message: 'We received your papers. The OSCA office will check them soon.',
      updatedAt: now,
      history: [
        ..._status.history,
        StatusEvent(
          stage: ApplicationStage.submitted,
          date: now,
          note: 'Application sent from the app.',
        ),
      ],
    );
    _addNotification(
      'Application sent',
      'Your reference number is $reference. We will tell you when the OSCA '
          'office starts checking it.',
      now,
    );
    notifyListeners();
    await _saveCache();
    _syncTimer();
  }

  /// The user takes back an application that the OSCA office has not
  /// started checking yet. The status goes back to "Not started".
  Future<void> cancelApplication() async {
    if (_status.stage != ApplicationStage.submitted) return;
    final now = _clock();
    _status = ApplicationStatus.empty();
    _addNotification(
      'Application cancelled',
      'You cancelled your application. You can send it again any time.',
      now,
    );
    notifyListeners();
    await _saveCache();
    _syncTimer();
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();
    await _saveCache();
  }

  /// Log out: forget everything in memory.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _status = ApplicationStatus.empty();
    _notifications = [];
    _cacheLoaded = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Status from the server (the OSCA office's decision)
  // ---------------------------------------------------------------------------

  static const _stageNotices = {
    ApplicationStage.approved: (
      'Application approved',
      'Congratulations! Your Senior Citizen ID application was approved.',
    ),
    ApplicationStage.needsAction: (
      'Please fix your papers',
      'The OSCA office needs you to send some papers again. Open your '
          'application to see what to do.',
    ),
  };

  Future<void> _refreshStatus() async {
    final data = await _api.get('/application');
    if (data is! Map) return;
    final fresh = ApplicationStatus.fromJson(Map<String, dynamic>.from(data));
    final previous = _status.stage;
    _status = fresh;
    final notice = _stageNotices[fresh.stage];
    if (notice != null && fresh.stage != previous) {
      _addNotification(notice.$1, notice.$2, fresh.updatedAt ?? _clock());
    }
  }

  // ---------------------------------------------------------------------------
  // Moving the application forward (stands in for the OSCA office)
  // ---------------------------------------------------------------------------

  /// Returns true when the status changed.
  bool _advanceIfDue() {
    if (!simulateOscaReview) return false;
    final now = _clock();
    var changed = false;

    final submittedAt = _dateOf(ApplicationStage.submitted);
    if (_status.stage == ApplicationStage.submitted &&
        submittedAt != null &&
        now.difference(submittedAt) >= reviewStartsAfter) {
      _moveTo(
        ApplicationStage.review,
        at: submittedAt.add(reviewStartsAfter),
        message: 'We are checking your documents. You will get a '
            'notification when it is done.',
        note: _simReviewNote,
        title: 'Application under review',
        body: 'The OSCA office is now checking your papers.',
      );
      changed = true;
    }

    final reviewAt = _dateOf(ApplicationStage.review);
    if (_status.stage == ApplicationStage.review &&
        reviewAt != null &&
        now.difference(reviewAt) >= approvedAfter) {
      _moveTo(
        ApplicationStage.approved,
        at: reviewAt.add(approvedAfter),
        message: 'Your application is approved. Your Senior Citizen ID is '
            'being prepared.',
        note: _simApprovedNote,
        title: 'Application approved',
        body: 'Congratulations! Your Senior Citizen ID application was '
            'approved.',
      );
      changed = true;
    }
    return changed;
  }

  void _moveTo(
      ApplicationStage stage, {
        required DateTime at,
        required String message,
        required String note,
        required String title,
        required String body,
      }) {
    _status = _status.copyWith(
      stage: stage,
      message: message,
      updatedAt: at,
      history: [
        ..._status.history,
        StatusEvent(stage: stage, date: at, note: note),
      ],
    );
    _addNotification(title, body, at);
  }

  /// When the application reached [stage], or null.
  DateTime? _dateOf(ApplicationStage stage) {
    DateTime? date;
    for (final event in _status.history) {
      if (event.stage == stage) date = event.date;
    }
    return date;
  }

  /// While the application is waiting, check every 15 seconds so the Home
  /// screen updates by itself.
  void _syncTimer() {
    final waiting = simulateOscaReview &&
        (_status.stage == ApplicationStage.submitted ||
            _status.stage == ApplicationStage.review);
    if (!waiting) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_advanceIfDue()) {
        notifyListeners();
        await _saveCache();
      }
      _syncTimer();
    });
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  void _addNotification(String title, String body, DateTime date) {
    _notifications = [
      AppNotification(
        id: 'local-${date.microsecondsSinceEpoch}',
        title: title,
        body: body,
        date: date,
      ),
      ..._notifications,
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Keeps "read" marks and the messages made on this phone.
  List<AppNotification> _merge(List<AppNotification> fresh) {
    final readIds = _notifications.where((n) => n.read).map((n) => n.id).toSet();
    final freshIds = fresh.map((n) => n.id).toSet();
    final local = _notifications
        .where((n) => n.id.startsWith('local-') && !freshIds.contains(n.id));
    final merged = [
      ...fresh.map((n) => readIds.contains(n.id) ? n.copyWith(read: true) : n),
      ...local,
    ];
    merged.sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }

  // ---------------------------------------------------------------------------
  // Saving on the phone
  // ---------------------------------------------------------------------------

  Future<void> _readCache() async {
    final rawStatus = await _db.read(_kStatus);
    if (rawStatus is Map) {
      final saved = ApplicationStatus.fromJson(Map<String, dynamic>.from(rawStatus));
      // Ignore the old sample status ("Under review") saved by earlier builds.
      if (saved.applicationNo != _oldSampleApplicationNo) _status = saved;
    }
    final rawList = await _db.read(_kNotifications);
    if (rawList is List) {
      _notifications = rawList
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .where((n) => n.id != _oldSampleNotificationId)
          .toList();
    }
    if (!simulateOscaReview) _undoTestModeSteps();
    _cacheLoaded = true;
  }

  /// Removes "Under review" / "Approved" steps that the test mode added, and
  /// puts the application back on the last real step (normally Submitted).
  void _undoTestModeSteps() {
    final realHistory = _status.history
        .where((e) => e.note != _simReviewNote && e.note != _simApprovedNote)
        .toList();
    if (realHistory.length != _status.history.length) {
      final last = realHistory.isEmpty ? null : realHistory.last;
      _status = ApplicationStatus(
        applicationNo: _status.applicationNo,
        stage: last?.stage ?? ApplicationStage.notStarted,
        message: last == null
            ? ApplicationStatus.empty().message
            : 'We received your papers. The OSCA office will check them soon.',
        updatedAt: last?.date,
        history: realHistory,
      );
    }
    _notifications = _notifications
        .where((n) => !(n.id.startsWith('local-') && _simTitles.contains(n.title)))
        .toList();
  }

  Future<void> _saveCache() async {
    try {
      await _db.write(_kStatus, _status.toJson());
      await _db.write(
        _kNotifications,
        _notifications.map((n) => n.toJson()).toList(),
      );
    } catch (_) {
      // Saving the offline copy failed (phone storage full). The app still
      // works; it just will not remember this until next time.
    }
  }
}