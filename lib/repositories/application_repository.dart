import 'package:flutter/foundation.dart';

import '../models/application_status.dart';
import '../services/api_client.dart';
import '../storage/local_db.dart';

/// The user's Senior Citizen ID application + the bell notifications.
///
/// The status is the OSCA office's: [load] reads it from the SCMS backend
/// (Document Verification on the web), together with the notifications.
/// Nothing moves forward on the phone by itself. The copy saved on the
/// phone is only shown while there is no internet.
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

  static const _kStatus = 'application_status';
  static const _kNotifications = 'notifications';
  static const _kHidden = 'notifications_hidden';

  /// Values from the old sample data, removed from phones that saved them.
  static const _oldSampleApplicationNo = 'SC-2026-001284';
  static const _oldSampleNotificationId = 'n-1001';

  ApplicationStatus _status = ApplicationStatus.empty();
  List<AppNotification> _notifications = [];
  bool _cacheLoaded = false;
  bool _loading = false;
  String? _error;

  ApplicationStatus get status => _status;
  /// Ids deleted by the user (soft delete: kept, only not shown).
  Set<String> _hidden = {};

  /// The messages to show, newest first (deleted ones left out).
  List<AppNotification> get notifications => List.unmodifiable(
      _notifications.where((n) => !_hidden.contains(n.id)).toList()
        ..sort((a, b) => b.date.compareTo(a.date)));

  /// For the bell badge: unread messages that are shown.
  int get unreadCount => _notifications
      .where((n) => !n.read && !_hidden.contains(n.id))
      .length;
  bool get loading => _loading;

  /// Set when the last refresh failed (the saved copy is still shown).
  String? get error => _error;

  /// Shows the saved status right away, then refreshes it and the
  /// notifications from the backend.
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
      await _refreshStatus();
      _error = null;
    } on ApiException catch (e) {
      _error = e.statusCode == null
          ? 'No internet. Showing the information saved on this phone.'
          : 'Could not load the latest information. Pull down to try again.';
    } catch (_) {
      _error = 'Could not load the latest information. Pull down to try again.';
    }

    await _saveCache();
    _loading = false;
    notifyListeners();
  }

  /// Called after the backend accepted the application and gave its
  /// reference number (Upload documents).
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
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();
    await _saveCache();
  }

  /// The user opened one message: its NEW mark goes away.
  Future<void> markRead(String id) async {
    final i = _notifications.indexWhere((n) => n.id == id && !n.read);
    if (i < 0) return;
    _notifications = List.of(_notifications)
      ..[i] = _notifications[i].copyWith(read: true);
    notifyListeners();
    await _saveCache();
  }

  /// Swipe to delete: hidden from the list (and the bell count), not
  /// erased, so [unhide] can bring it back and the server cannot send it
  /// again as new.
  Future<void> hide(String id) => _setHidden({..._hidden, id});

  /// "Undo" after a delete.
  Future<void> unhide(String id) => _setHidden({..._hidden}..remove(id));

  /// "Clear all": hides every message shown now.
  Future<void> hideAll() =>
      _setHidden({..._hidden, ..._notifications.map((n) => n.id)});

  Future<void> _setHidden(Set<String> hidden) async {
    _hidden = hidden;
    notifyListeners();
    await _saveCache();
  }

  /// Log out: forget everything in memory.
  void reset() {
    _status = ApplicationStatus.empty();
    _notifications = [];
    _hidden = {};
    _cacheLoaded = false;
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Status from the server (the OSCA office's decision)
  // ---------------------------------------------------------------------------

  Future<void> _refreshStatus() async {
    final data = await _api.get('/application');
    if (data is! Map) return;
    _status = ApplicationStatus.fromJson(Map<String, dynamic>.from(data));
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

  /// Keeps "read" marks and the "Application sent" message made on this
  /// phone after the backend accepted the application.
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
    final rawHidden = await _db.read(_kHidden);
    if (rawHidden is List) _hidden = rawHidden.whereType<String>().toSet();
    _cacheLoaded = true;
  }

  Future<void> _saveCache() async {
    try {
      await _db.write(_kStatus, _status.toJson());
      await _db.write(
        _kNotifications,
        _notifications.map((n) => n.toJson()).toList(),
      );
      await _db.write(_kHidden, _hidden.toList());
    } catch (_) {
      // Saving the offline copy failed (phone storage full). The app still
      // works; it just will not remember this until next time.
    }
  }
}
