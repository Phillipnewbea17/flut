import 'package:flutter/foundation.dart';

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
  Uint8List? _photo;
  List<PurchaseEntry> _entries = [];
  bool _cacheLoaded = false;
  bool _loading = false;

  SeniorId? get seniorId => _seniorId;
  bool get hasSeniorId => _seniorId != null;
  bool get loading => _loading;
  PurchaseBooklet get booklet => PurchaseBooklet(List.unmodifiable(_entries));

  /// The 2x2 photo the office holds (downloaded when the ID loads), or null
  /// when there is none or it could not be downloaded.
  Uint8List? get idPhoto => _photo;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    if (!_cacheLoaded) await _readCache();
    notifyListeners();
    try {
      _seniorId = await _service.fetchSeniorId();
      await _db.write(_kSeniorId, _seniorId?.toJson());
      await _loadPhoto();
    } catch (_) {
      // Offline: keep the saved ID.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Downloads the photo of the ID on screen. A photo that cannot be fetched
  /// is dropped, so the card never shows another senior's photo.
  Future<void> _loadPhoto() async {
    if ((_seniorId?.photoUrl ?? '').isEmpty) {
      _photo = null;
      return;
    }
    try {
      _photo = await _service.fetchPhoto();
    } catch (_) {
      _photo = null;
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
    _photo = null;
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
