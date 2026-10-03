import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A tiny offline database: each "table" is one JSON file in the app's
/// private folder. Repositories keep their last known data here, so the app
/// still shows information when there is no internet.
class LocalDb {
  final Directory _dir;
  final Map<String, Object?> _cache = {};

  LocalDb._(this._dir);

  static Future<LocalDb> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/local_db');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return LocalDb._(dir);
  }

  File _file(String name) => File('${_dir.path}/$name.json');

  /// Returns the saved value (a Map, List, String, number or bool), or null.
  Future<Object?> read(String name) async {
    if (_cache.containsKey(name)) return _cache[name];
    final file = _file(name);
    Object? value;
    if (await file.exists()) {
      try {
        value = jsonDecode(await file.readAsString());
      } catch (_) {
        value = null; // broken file: behave as if it was empty
      }
    }
    _cache[name] = value;
    return value;
  }

  /// Saves [value]. It must be something jsonEncode understands.
  Future<void> write(String name, Object? value) async {
    _cache[name] = value;
    final file = _file(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path); // replace in one step, never half-written
  }

  Future<void> delete(String name) async {
    _cache.remove(name);
    final file = _file(name);
    if (await file.exists()) await file.delete();
  }

  /// Log out: remove every table.
  Future<void> clear() async {
    _cache.clear();
    if (await _dir.exists()) {
      await for (final entity in _dir.list()) {
        await entity.delete(recursive: true);
      }
    }
  }
}
