import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Keeps photos of the user's papers in the app's private folder. Other apps
/// and the phone's gallery cannot see them, and they are deleted on log out.
class DocumentVault {
  final Directory _dir;

  DocumentVault._(this._dir);

  static Future<DocumentVault> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/document_vault');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return DocumentVault._(dir);
  }

  /// Saves the photo and returns the file. [fileName] like "idPhoto-123.jpg".
  Future<File> save(Uint8List bytes, {required String fileName}) async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
    final file = File('${_dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<void> delete(String path) async {
    final file = File(path);
    // Only delete files that really are inside the vault.
    if (!file.path.startsWith(_dir.path)) return;
    if (await file.exists()) await file.delete();
  }

  Future<void> clear() async {
    if (await _dir.exists()) {
      await for (final entity in _dir.list()) {
        await entity.delete(recursive: true);
      }
    }
  }
}
