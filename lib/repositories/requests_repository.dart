import 'package:flutter/foundation.dart';

import '../models/service_request.dart';
import '../services/api_client.dart';
import '../services/requests_service.dart';
import '../storage/document_vault.dart';
import '../storage/local_db.dart';

/// Medical, burial, help and ID replacement requests.
///
/// A request is saved on the phone first. It is only shown as sent when the
/// backend answered with a reference number; otherwise it stays
/// "Not sent yet" and can be sent again later.
class RequestsRepository extends ChangeNotifier {
  RequestsRepository({
    required RequestsService service,
    required DocumentVault vault,
    required LocalDb db,
    DateTime Function()? clock,
  })  : _service = service,
        _vault = vault,
        _db = db,
        _clock = clock ?? DateTime.now;

  final RequestsService _service;
  final DocumentVault _vault;
  final LocalDb _db;
  final DateTime Function() _clock;

  static const _kRequests = 'service_requests';

  List<ServiceRequest> _items = [];
  bool _cacheLoaded = false;
  bool _loading = false;
  String? _error;

  /// Newest first.
  List<ServiceRequest> get all => List.unmodifiable(_items);
  bool get loading => _loading;

  /// Set when the last refresh failed (the saved copy is still shown).
  String? get error => _error;

  bool isAvailable(RequestKind kind) => _service.isAvailable(kind);

  List<ServiceRequest> ofKind(RequestKind kind) =>
      _items.where((r) => r.kind == kind).toList();

  List<ServiceRequest> current(RequestKind kind) =>
      ofKind(kind).where((r) => r.isActive).toList();

  List<ServiceRequest> previous(RequestKind kind) =>
      ofKind(kind).where((r) => !r.isActive).toList();

  /// Every request, newest first, optionally only the active (or only the
  /// completed) ones and one category. For Applications and My requests.
  List<ServiceRequest> overview({bool? active, RequestCategory? category}) =>
      _items
          .where((r) => active == null || r.isActive == active)
          .where((r) => category == null || r.category == category)
          .toList()
        ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

  /// The newest request of [kind] that is still open, or null.
  ServiceRequest? latestActive(RequestKind kind) {
    final list = current(kind);
    return list.isEmpty ? null : list.first;
  }

  ServiceRequest? find(String id) {
    for (final r in _items) {
      if (r.id == id || (r.reference.isNotEmpty && r.reference == id)) {
        return r;
      }
    }
    return null;
  }

  /// Shows the saved requests, then asks the office for their status.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    if (!_cacheLoaded) await _readCache();
    notifyListeners();

    try {
      for (final kind in RequestKind.values) {
        if (!_service.isAvailable(kind)) continue;
        _mergeServer(kind, await _service.fetch(kind));
      }
      _error = null;
    } catch (_) {
      _error = 'No internet. Showing the requests saved on this phone.';
    }

    _sort();
    await _save();
    _loading = false;
    notifyListeners();
  }

  /// Saves a new request (and its photos) on the phone, then tries to send
  /// it. Always returns the request; check [ServiceRequest.isSent].
  Future<ServiceRequest> create({
    required RequestKind kind,
    required String title,
    required List<RequestDetail> details,
    required Map<String, String> payload,
    List<Uint8List> photos = const [],
  }) async {
    final now = _clock();
    final id = '${kind.name}-${now.microsecondsSinceEpoch}';
    final attachments = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final file = await _vault.save(photos[i], fileName: '$id-$i.jpg');
      attachments.add(file.path);
    }
    final request = ServiceRequest(
      id: id,
      kind: kind,
      title: title,
      details: details,
      payload: payload,
      attachments: attachments,
      createdAt: now,
    );
    _items = [request, ..._items];
    notifyListeners();
    await _save();
    return send(request);
  }

  /// Sends (or re-sends) a request that is not sent yet.
  Future<ServiceRequest> send(ServiceRequest request) async {
    if (request.isSent) return request;
    ServiceRequest result;
    try {
      result = await _service.submit(request, _clock());
    } on NotConnectedException catch (e) {
      result = request.copyWith(sendError: () => e.toString());
    } on ApiException catch (e) {
      result = request.copyWith(sendError: () => e.message);
    } catch (_) {
      result = request.copyWith(
        sendError: () => 'The request was not sent. Please try again.',
      );
    }
    _replace(result);
    await _save();
    return result;
  }

  /// Deletes a request that never reached the office.
  Future<void> removeDraft(ServiceRequest request) async {
    if (request.isSent) return;
    _items = _items.where((r) => r.id != request.id).toList();
    notifyListeners();
    await _save();
    for (final path in request.attachments) {
      await _vault.delete(path);
    }
  }

  /// Log out: forget the list (the photos are wiped by DocumentVault.clear).
  void reset() {
    _items = [];
    _cacheLoaded = false;
    _error = null;
    notifyListeners();
  }

  /// The office's list is the truth for sent requests of [kind]; requests
  /// not sent yet stay as they are.
  void _mergeServer(RequestKind kind, List<ServiceRequest> fresh) {
    final saved = {
      for (final r in _items)
        if (r.kind == kind && r.isSent) r.reference: r,
    };
    _items = [
      for (final r in _items)
        if (r.kind != kind || !r.isSent) r,
      for (final s in fresh) saved[s.reference]?.mergeServer(s) ?? s,
    ];
  }

  void _replace(ServiceRequest updated) {
    _items = [for (final r in _items) r.id == updated.id ? updated : r];
    notifyListeners();
  }

  void _sort() =>
      _items.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

  Future<void> _readCache() async {
    final raw = await _db.read(_kRequests);
    if (raw is List) {
      _items = raw
          .whereType<Map>()
          .map((e) => ServiceRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _sort();
    }
    _cacheLoaded = true;
  }

  Future<void> _save() async {
    try {
      await _db.write(_kRequests, _items.map((r) => r.toJson()).toList());
    } catch (_) {
      // Storage full: the list is still correct in memory.
    }
  }
}
