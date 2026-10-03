import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Takes or picks a photo and makes it small enough to upload on a slow
/// mobile connection. The phone does the resizing (image_picker's
/// maxWidth/maxHeight/imageQuality), so no extra package is needed.
class ImageCompressor {
  ImageCompressor([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // Papers: big enough to read small print.
  static const double documentMaxSide = 1600;
  static const int documentQuality = 75;

  // Face photo for the ID card.
  static const double photoMaxSide = 900;
  static const int photoQuality = 85;

  /// Photo of a paper. Returns null when the user cancels.
  Future<Uint8List?> pickDocument(ImageSource source) => _pick(
        source: source,
        maxSide: documentMaxSide,
        quality: documentQuality,
        camera: CameraDevice.rear,
      );

  /// Face photo. Uses the front (selfie) camera when taking a new photo.
  Future<Uint8List?> pickIdPhoto(ImageSource source) => _pick(
        source: source,
        maxSide: photoMaxSide,
        quality: photoQuality,
        camera: CameraDevice.front,
      );

  Future<Uint8List?> _pick({
    required ImageSource source,
    required double maxSide,
    required int quality,
    required CameraDevice camera,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
      preferredCameraDevice: camera,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// "340 KB" or "1.2 MB"
  static String describeSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
