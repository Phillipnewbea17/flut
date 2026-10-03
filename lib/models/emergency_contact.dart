import 'dart:convert';

import 'user_profile.dart';

class EmergencyContact {
  final String name;
  final String phone; // digits only, no country code

  const EmergencyContact({required this.name, required this.phone});

  String get displayPhone => UserProfile.formatPhone(phone);

  /// Number to dial for the SOS button.
  String get dialNumber => '+63$phone';

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  String encode() => jsonEncode(toJson());

  factory EmergencyContact.decode(String source) =>
      EmergencyContact.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
