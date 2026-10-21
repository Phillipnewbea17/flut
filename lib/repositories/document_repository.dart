import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/application_status.dart';
import '../models/document_item.dart';
import '../services/api_client.dart';
import '../services/document_service.dart';
import '../storage/document_vault.dart';
import '../storage/local_db.dart';
import '../utils/manila_time.dart';

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

  /// The papers the application needs now: the ones the office asked to be
  /// sent again, or all four for a first submission.
  static List<DocumentType> requiredFor(ApplicationStatus status) =>
      status.reuploadTypes.isEmpty ? requiredTypes : status.reuploadTypes;

  /// How many of the four papers are done: the ones the office has on the
  /// server, plus the ones sent from this phone that it does not have yet.
  int sentCount(ApplicationStatus status) => requiredTypes.where((t) {
        final sentHere = latestOf(t)?.isUploaded ?? false;
        return status.reviewOf(t) != null || sentHere;
      }).length;

  /// True when every paper the application needs is sent from this phone,
  /// and each newest copy is later than the office's review of that paper.
  bool readyToSubmit(ApplicationStatus status) =>
      requiredFor(status).every((t) {
        final item = latestOf(t);
        if (item == null || !item.isUploaded) return false;
        final reviewedAt = status.reviewOf(t)?.reviewedAt;
        return reviewedAt == null ||
            toPhilippineTime(item.addedAt).isAfter(reviewedAt);
      });

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

  /// Sends (or re-sends) a saved photo. The office refusing it (422: not
  /// allowed now, or a paper it did not ask for) throws the office's own
  /// message as an ApiException; the photo stays saved on the phone.
  Future<DocumentItem> upload(DocumentItem item) async {
    _replace(item.copyWith(status: DocumentStatus.uploading));
    DocumentItem result;
    ApiException? refusal;
    try {
      await _service.upload(item);
      result = item.copyWith(status: DocumentStatus.uploaded);
    } on ApiException catch (e) {
      result = item.copyWith(status: DocumentStatus.failed);
      if (e.statusCode == 422) refusal = e;
    } catch (_) {
      result = item.copyWith(status: DocumentStatus.failed);
    }
    _replace(result);
    await _save();
    if (refusal != null) throw refusal;
    return result;
  }

  Future<void> remove(DocumentItem item) async {
    _items = _items.where((d) => d.id != item.id).toList();
    notifyListeners();
    await _save();
    await _vault.delete(item.filePath);
  }

  /// Sends the finished application (the papers it needs, see requiredFor).
  /// Returns the reference number.
  Future<String> submitApplication(ApplicationStatus status) {
    final papers = requiredFor(status)
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
