import 'package:permission_handler/permission_handler.dart';

enum CameraPermission { granted, denied, blocked }

/// Asks for the camera only when a screen needs it (never at start-up).
abstract class CameraAccess {
  /// Asks the user if needed, and returns the answer.
  Future<CameraPermission> request();

  /// Opens this app's page in the phone settings.
  Future<bool> openSettings();
}

class DeviceCameraAccess implements CameraAccess {
  @override
  Future<CameraPermission> request() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return CameraPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermission.blocked;
    }
    return CameraPermission.denied;
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
