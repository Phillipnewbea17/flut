import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';

/// Opens the phone's dialer, text messages, maps and email.
/// Every method returns false when the phone could not open the app.
class SosService {
  /// Philippine national emergency hotline.
  static const String nationalEmergency = '911';

  /// Philippine Red Cross hotline.
  static const String redCross = '143';

  Future<bool> call(String number) =>
      _launch(Uri(scheme: 'tel', path: number));

  Future<bool> callContact(EmergencyContact contact) =>
      call(contact.dialNumber);

  /// SOS: starts the call right away (no extra tap in the dialer). Without
  /// the phone permission it opens the dialer with the number instead.
  Future<bool> callNow(String number) async {
    try {
      final started = await _channel
          .invokeMethod<bool>('callNow', {'number': number});
      if (started == true) return true;
    } catch (_) {
      // Fall through to the dialer.
    }
    return call(number);
  }

  /// MainActivity.kt places the call (Android ACTION_CALL).
  static const MethodChannel _channel = MethodChannel('senior_companion/sos');

  Future<bool> textContact(EmergencyContact contact, String message) =>
      textContacts([contact], message);

  /// One text message to everyone in [contacts]. The phone's messages app
  /// opens with the text ready; the senior taps Send.
  Future<bool> textContacts(List<EmergencyContact> contacts, String message) {
    final to = contacts.map((c) => c.dialNumber).join(',');
    // Encoded by hand: some SMS apps show "+" instead of spaces otherwise.
    return _launch(Uri.parse('sms:$to?body=${Uri.encodeComponent(message)}'));
  }

  /// Asks for the phone and location permissions SOS needs, so the SOS
  /// screen itself never stops to ask. Called when contacts are saved.
  Future<void> prepare() async {
    try {
      await Permission.phone.request();
    } catch (_) {
      // SOS falls back to the dialer.
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      // No location on this phone: SOS texts without it.
    }
  }

  /// A Google Maps link to where the phone is, or null when the location
  /// is off or not allowed. Never asks for permission (see [prepare]).
  Future<String?> locationLink() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return null;
      return 'https://maps.google.com/?q='
          '${position.latitude.toStringAsFixed(6)},'
          '${position.longitude.toStringAsFixed(6)}';
    } catch (_) {
      return null;
    }
  }

  /// Directions in Google Maps (or the browser).
  Future<bool> openDirections(double latitude, double longitude) {
    return _launch(Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    }));
  }

  Future<bool> email(String address, {String subject = ''}) {
    return _launch(Uri.parse(
      'mailto:$address?subject=${Uri.encodeComponent(subject)}',
    ));
  }

  Future<bool> openWebsite(String url) => _launch(Uri.parse(url));

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
