import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/document_item.dart';
import '../services/document_service.dart';
import '../storage/document_vault.dart';
import '../storage/local_db.dart';

/// Photos of the user's papers: saved on the phone first, then sent.
/// If sending fails (no signal), the photo stays saved and can be sent again.
class DocumentRepository extends ChangeNotifier {
  DocumentRepository({
    required DocumentService service,
    required DocumentVault vault,
    required LocalDb db,
  })  : _service = service,
        _vault = vault,
        _db = db;

  final DocumentService _service;
  final DocumentVault _vault;
  final LocalDb _db;

  static const _kDocuments = 'documents';

  List<DocumentItem> _items = [];
  bool _loaded = false;

  List<DocumentItem> get documents => List.unmodifiable(_items);

  /// False without a backend address: photos stay on this phone, unsent.
  bool get sendsToOffice => _service.sendsToOffice;

  /// The newest photo of [type], or null.
  DocumentItem? latestOf(DocumentType type) {
    DocumentItem? latest;
    for (final item in _items) {
      if (item.type != type) continue;
      if (latest == null || item.addedAt.isAfter(latest.addedAt)) latest = item;
    }
    return latest;
  }

  /// Every paper is required: the four the OSCA office checks.
  static List<DocumentType> get requiredTypes => DocumentType.values;

  /// True when every required paper was sent.
  bool get hasAllRequired =>
      requiredTypes.every((t) => latestOf(t)?.isUploaded ?? false);

  int get requiredDoneCount =>
      requiredTypes.where((t) => latestOf(t)?.isUploaded ?? false).length;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await _db.read(_kDocuments);
    final items = <DocumentItem>[];
    if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        var item = DocumentItem.tryFromJson(Map<String, dynamic>.from(entry));
        if (item == null) continue; // a paper the office no longer asks for
        if (!await _vault.exists(item.filePath)) continue; // photo is gone
        if (item.status == DocumentStatus.uploading) {
          item = item.copyWith(status: DocumentStatus.failed); // app closed
        }
        items.add(item);
      }
    }
    _items = items;
    _loaded = true;
    notifyListeners();
  }

  /// Saves a new photo of [type] and sends it, replacing the older photo of
  /// the same type.
  Future<DocumentItem> add(DocumentType type, Uint8List bytes) async {
    final now = DateTime.now();
    final id = '${type.name}-${now.millisecondsSinceEpoch}';
    final file = await _vault.save(bytes, fileName: '$id.jpg');
    final item = DocumentItem(
      id: id,
      type: type,
      filePath: file.path,
      sizeBytes: bytes.length,
      addedAt: now,
      status: DocumentStatus.saved,
    );

    final replaced = _items.where((d) => d.type == type).toList();
    final replacedIds = replaced.map((d) => d.id).toSet();
    _items = [..._items.where((d) => !replacedIds.contains(d.id)), item];
    notifyListeners();
    await _save();
    for (final old in replaced) {
      await _vault.delete(old.filePath);
    }

    return upload(item);
  }

  /// Sends (or re-sends) a saved photo.
  Future<DocumentItem> upload(DocumentItem item) async {
    _replace(item.copyWith(status: DocumentStatus.uploading));
    DocumentItem result;
    try {
      await _service.upload(item);
      result = item.copyWith(status: DocumentStatus.uploaded);
    } catch (_) {
      result = item.copyWith(status: DocumentStatus.failed);
    }
    _replace(result);
    await _save();
    return result;
  }

  Future<void> remove(DocumentItem item) async {
    _items = _items.where((d) => d.id != item.id).toList();
    notifyListeners();
    await _save();
    await _vault.delete(item.filePath);
  }

  /// Sends the finished application. Returns the reference number.
  Future<String> submitApplication() {
    final papers = requiredTypes
        .map(latestOf)
        .whereType<DocumentItem>()
        .toList();
    return _service.submitApplication(papers);
  }

  /// Log out: forget the list (the files are wiped by DocumentVault.clear).
  void reset() {
    _items = [];
    _loaded = false;
    notifyListeners();
  }

  void _replace(DocumentItem updated) {
    _items = [
      for (final d in _items) d.id == updated.id ? updated : d,
    ];
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _db.write(_kDocuments, _items.map((d) => d.toJson()).toList());
    } catch (_) {
      // Storage full: the list is still correct in memory.
    }
  }
}
