import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';

/// Opens the phone's dialer, text messages, maps and email.
/// Every method returns false when the phone could not open the app.
class SosService {
  /// Philippine national emergency hotline.
  static const String nationalEmergency = '911';

  Future<bool> call(String number) =>
      _launch(Uri(scheme: 'tel', path: number));

  Future<bool> callContact(EmergencyContact contact) =>
      call(contact.dialNumber);

  Future<bool> textContact(EmergencyContact contact, String message) {
    // Encoded by hand: some SMS apps show "+" instead of spaces otherwise.
    return _launch(Uri.parse(
      'sms:${contact.dialNumber}?body=${Uri.encodeComponent(message)}',
    ));
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
