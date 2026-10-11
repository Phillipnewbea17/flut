import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Why a photo of an ID cannot be read well.
enum ImageQualityIssue { unreadable, tooSmall, tooDark, glare, blurry }

extension ImageQualityIssueText on ImageQualityIssue {
  /// What to tell the user, in plain words.
  String get advice => switch (this) {
        ImageQualityIssue.unreadable =>
          'We could not open the photo. Please take another photo.',
        ImageQualityIssue.tooSmall =>
          'The ID looks too small. Please hold the phone closer so the ID '
              'fills the frame.',
        ImageQualityIssue.tooDark =>
          'The photo is too dark. Please take another photo with better '
              'lighting.',
        ImageQualityIssue.glare =>
          'There is a bright reflection on the ID. Please tilt the ID a '
              'little, or move away from direct light.',
        ImageQualityIssue.blurry =>
          'The photo is blurry. Please hold the phone still and take '
              'another photo.',
      };
}

/// A quick check, done on the phone, that a photo of an ID is good enough
/// to read before trying text recognition on it. It cannot tell whether
/// every corner of the ID is in the photo; the frame on the camera screen
/// and the user's own review cover that.
class ImageQualityChecker {
  ImageQualityChecker._();

  /// The shorter side must be at least this many pixels.
  static const int minShortSide = 480;

  /// Average brightness (0-255) below this is too dark.
  static const double minBrightness = 55;

  /// More than this share of nearly-white pixels means glare.
  static const double maxGlareShare = 0.08;

  /// Sharpness (variance of the Laplacian on a 480-px-wide copy) below
  /// this is blurry.
  static const double minSharpness = 45;

  /// Returns the first problem found, or null when the photo looks fine.
  /// Top-level friendly: can be run with compute().
  static ImageQualityIssue? check(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return ImageQualityIssue.unreadable;
    final oriented = img.bakeOrientation(decoded);
    final shortSide = oriented.width < oriented.height
        ? oriented.width
        : oriented.height;
    if (shortSide < minShortSide) return ImageQualityIssue.tooSmall;

    final small = img.grayscale(img.copyResize(oriented, width: 480));
    final w = small.width, h = small.height;
    final lum = List<double>.filled(w * h, 0);
    var sum = 0.0;
    var bright = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = small.getPixel(x, y).r.toDouble();
        lum[y * w + x] = v;
        sum += v;
        if (v >= 250) bright++;
      }
    }
    final mean = sum / (w * h);
    if (mean < minBrightness) return ImageQualityIssue.tooDark;
    if (bright / (w * h) > maxGlareShare) return ImageQualityIssue.glare;

    // Laplacian: a sharp photo has strong edges, a blurry one does not.
    var lapSum = 0.0, lapSq = 0.0;
    var n = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final lap = lum[i - w] + lum[i + w] + lum[i - 1] + lum[i + 1] - 4 * lum[i];
        lapSum += lap;
        lapSq += lap * lap;
        n++;
      }
    }
    final lapMean = lapSum / n;
    final variance = lapSq / n - lapMean * lapMean;
    if (variance < minSharpness) return ImageQualityIssue.blurry;
    return null;
  }
}
