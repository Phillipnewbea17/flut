import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// A profile photo change that has not reached the OSCA office yet.
enum PendingPhoto { upload, remove }

/// The app-profile photo on this phone. A copy is sent to the OSCA office so
/// staff see it in User Management (UserRepository); when that fails, the
/// change is remembered here ([markPending]) and sent the next time the app
/// opens. The office's copy is downloaded again after signing in, since
/// logging out removes this one (UserRepository.syncPhoto). It is separate
/// from the Senior ID photo of Upload Documents.
class ProfilePhotoStore {
  static const String _folder = 'profile_photo';
  static const String _pendingFile = 'pending_sync';
  static const String _versionFile = 'photo_version';
  static const int _size = 512;

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Crops [bytes] to a centered square (shown as a circle), saves it and
  /// returns its path. A new file name each time, so the new photo shows
  /// right away instead of an old cached one. Returns null when the image
  /// cannot be read or saved.
  Future<String?> save(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final oriented = img.bakeOrientation(decoded);
      final side = oriented.width < oriented.height
          ? oriented.width
          : oriented.height;
      final square = img.copyCrop(
        oriented,
        x: (oriented.width - side) ~/ 2,
        y: (oriented.height - side) ~/ 2,
        width: side,
        height: side,
      );
      final small = img.copyResize(square, width: _size, height: _size);

      final dir = await _dir();
      final file = File(
          '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(img.encodeJpg(small, quality: 88), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// The saved photo at [path], or null when it is gone.
  Future<Uint8List?> read(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// True when a photo file is still saved at [path].
  Future<bool> exists(String? path) async {
    if (path == null) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  /// The server's photoVersion of the saved photo (set when it was
  /// downloaded), or null when unknown.
  Future<String?> savedVersion() async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$_versionFile');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Remembers which server photo version the saved photo is. Null forgets it.
  Future<void> saveVersion(String? version) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$_versionFile');
      if (version == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      await file.writeAsString(version, flush: true);
    } catch (_) {}
  }

  /// Remembers that [change] has not reached the OSCA office yet. A later
  /// change replaces an earlier one.
  Future<void> markPending(PendingPhoto change) async {
    try {
      final dir = await _dir();
      await File('${dir.path}/$_pendingFile')
          .writeAsString(change.name, flush: true);
    } catch (_) {}
  }

  /// The change still waiting to be sent, or null.
  Future<PendingPhoto?> pending() async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$_pendingFile');
      if (!await file.exists()) return null;
      final name = (await file.readAsString()).trim();
      for (final change in PendingPhoto.values) {
        if (change.name == name) return change;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearPending() async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$_pendingFile');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Log out: remove every saved profile photo (and any change still
  /// waiting to be sent).
  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
