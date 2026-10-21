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
///
/// Read marks and deletes show at once, then go to the server
/// (POST /notifications/read, /dismiss, /restore), which keeps them for the
/// account: logging out wipes this phone's copy, and the next login gets
/// them back from GET /notifications. A mark made with no connection stays
/// on the phone and is sent again by the next [load] that works.
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
  static const _kUnsentRestores = 'notifications_unsent_restores';

  /// Most ids the server takes in one request.
  static const _maxIdsPerRequest = 200;

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

  /// "Undo" taps the server has not heard yet (no connection then). Sent
  /// before the next refresh, so the server lists those messages again.
  Set<String> _unsentRestores = {};

  /// Marks go to the server one after another, in the order they were
  /// made, so an "Undo" never arrives before its delete.
  Future<void> _outbox = Future<void>.value();

  /// Changes at log out, so marks still waiting for the account that left
  /// are never sent for the next one.
  int _generation = 0;

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

    var unsentReads = <String>[];
    var unsentDeletes = <String>[];
    try {
      // An "Undo" made with no connection goes first, so the list below
      // has that message again.
      await _sendUnsentRestores();
      final listData = await _api.get('/notifications');
      if (listData is List) {
        final fresh = listData
            .whereType<Map>()
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        // Marks made here that the server has not heard yet (no
        // connection then): it still lists them as new, or not deleted.
        final readHere =
            _notifications.where((n) => n.read).map((n) => n.id).toSet();
        unsentReads = [
          for (final n in fresh)
            if (!n.read && readHere.contains(n.id)) n.id,
        ];
        unsentDeletes = [
          for (final n in fresh)
            if (_hidden.contains(n.id)) n.id,
        ];
        _notifications = _merge(fresh);
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

    await _send('/notifications/read', unsentReads);
    await _send('/notifications/dismiss', unsentDeletes);
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
      documents: _status.documents,
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
    final ids = [
      for (final n in _notifications)
        if (!n.read) n.id,
    ];
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();
    await _saveCache();
    await _send('/notifications/read', ids);
  }

  /// The user opened one message: its NEW mark goes away.
  Future<void> markRead(String id) async {
    final i = _notifications.indexWhere((n) => n.id == id && !n.read);
    if (i < 0) return;
    _notifications = List.of(_notifications)
      ..[i] = _notifications[i].copyWith(read: true);
    notifyListeners();
    await _saveCache();
    await _send('/notifications/read', [id]);
  }

  /// Swipe to delete: hidden from the list (and the bell count), not
  /// erased, so [unhide] can bring it back. The server is told too, so it
  /// stops listing it, also after the next login.
  Future<void> hide(String id) async {
    _unsentRestores.remove(id);
    await _setHidden({..._hidden, id});
    await _send('/notifications/dismiss', [id]);
  }

  /// "Undo" after a delete.
  Future<void> unhide(String id) async {
    final generation = _generation;
    await _setHidden({..._hidden}..remove(id));
    if (!await _send('/notifications/restore', [id]) &&
        generation == _generation) {
      // No connection: the next refresh sends it before asking for the
      // list, or the server would leave this message out.
      _unsentRestores.add(id);
      await _saveCache();
    }
  }

  /// "Clear all": hides every message shown now.
  Future<void> hideAll() async {
    final ids = [
      for (final n in _notifications)
        if (!_hidden.contains(n.id)) n.id,
    ];
    _unsentRestores.removeAll(ids);
    await _setHidden({..._hidden, ...ids});
    await _send('/notifications/dismiss', ids);
  }

  Future<void> _setHidden(Set<String> hidden) async {
    _hidden = hidden;
    notifyListeners();
    await _saveCache();
  }

  /// Log out: forget everything in memory.
  void reset() {
    _generation++;
    _status = ApplicationStatus.empty();
    _notifications = [];
    _hidden = {};
    _unsentRestores = {};
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

  /// Tells the server about read or delete marks: POST [path] with
  /// {"ids": [...]}. Messages made on this phone ("local-") are left out:
  /// the server never had them. False when the server could not be told;
  /// the mark stays on this phone, and [load] sends it again.
  Future<bool> _send(String path, Iterable<String> ids) {
    final serverIds = ids.where((id) => !id.startsWith('local-')).toList();
    if (serverIds.isEmpty) return Future.value(true);
    final generation = _generation;
    final sent = _outbox.then((_) async {
      if (generation != _generation) return false; // logged out meanwhile
      try {
        for (var i = 0; i < serverIds.length; i += _maxIdsPerRequest) {
          final end = (i + _maxIdsPerRequest).clamp(0, serverIds.length);
          final result =
              await _api.post(path, {'ids': serverIds.sublist(i, end)});
          if (result['ok'] != true) return false;
        }
        return true;
      } catch (_) {
        return false;
      }
    });
    _outbox = sent;
    return sent;
  }

  Future<void> _sendUnsentRestores() async {
    if (_unsentRestores.isEmpty) return;
    final ids = _unsentRestores.toList();
    if (await _send('/notifications/restore', ids)) {
      _unsentRestores.removeAll(ids);
    }
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
    final rawRestores = await _db.read(_kUnsentRestores);
    if (rawRestores is List) {
      _unsentRestores = rawRestores.whereType<String>().toSet();
    }
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
      await _db.write(_kUnsentRestores, _unsentRestores.toList());
    } catch (_) {
      // Saving the offline copy failed (phone storage full). The app still
      // works; it just will not remember this until next time.
    }
  }
}
