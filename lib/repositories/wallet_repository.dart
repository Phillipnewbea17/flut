import 'package:flutter/widgets.dart';

import '../models/purchase_booklet.dart';
import '../models/senior_id.dart';
import '../services/wallet_service.dart';
import '../storage/local_db.dart';

/// Senior ID (from the server) and the purchase booklet (kept on the phone).
class WalletRepository extends ChangeNotifier {
  WalletRepository({required WalletService service, required LocalDb db})
      : _service = service,
        _db = db;

  final WalletService _service;
  final LocalDb _db;

  static const _kSeniorId = 'senior_id';
  static const _kBooklet = 'purchase_booklet';

  SeniorId? _seniorId;
  List<PurchaseEntry> _entries = [];
  bool _cacheLoaded = false;
  bool _loading = false;

  SeniorId? get seniorId => _seniorId;
  bool get hasSeniorId => _seniorId != null;
  bool get loading => _loading;
  PurchaseBooklet get booklet => PurchaseBooklet(List.unmodifiable(_entries));

  /// The ID photo held by the office (signed in), or null when there is none.
  ImageProvider? get idPhoto {
    final url = _seniorId?.photoUrl ?? '';
    return url.isEmpty ? null : _service.idPhoto(url);
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    if (!_cacheLoaded) await _readCache();
    notifyListeners();
    try {
      _seniorId = await _service.fetchSeniorId();
      await _db.write(_kSeniorId, _seniorId?.toJson());
    } catch (_) {
      // Offline: keep the saved ID.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addPurchase(PurchaseEntry entry) async {
    _entries = [entry, ..._entries]..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveBooklet();
  }

  Future<void> removePurchase(String id) async {
    _entries = _entries.where((e) => e.id != id).toList();
    notifyListeners();
    await _saveBooklet();
  }

  void reset() {
    _seniorId = null;
    _entries = [];
    _cacheLoaded = false;
    notifyListeners();
  }

  Future<void> _readCache() async {
    final rawId = await _db.read(_kSeniorId);
    if (rawId is Map) {
      _seniorId = SeniorId.fromJson(Map<String, dynamic>.from(rawId));
    }
    final rawBooklet = await _db.read(_kBooklet);
    if (rawBooklet is List) {
      _entries = rawBooklet
          .whereType<Map>()
          .map((e) => PurchaseEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    _cacheLoaded = true;
  }

  Future<void> _saveBooklet() async {
    try {
      await _db.write(_kBooklet, _entries.map((e) => e.toJson()).toList());
    } catch (_) {
      // Storage full: still correct in memory.
    }
  }
}
