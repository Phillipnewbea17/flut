import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// The app-profile photo, kept on this phone only (never uploaded). It is
/// separate from the Senior ID photo of Upload Documents.
class ProfilePhotoStore {
  static const String _folder = 'profile_photo';
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
  /// cannot be read.
  Future<String?> save(Uint8List bytes) async {
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
    final file =
        File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(img.encodeJpg(small, quality: 88), flush: true);
    return file.path;
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Log out: remove every saved profile photo.
  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
