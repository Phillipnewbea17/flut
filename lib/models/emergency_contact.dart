import 'dart:convert';

import 'user_profile.dart';

class EmergencyContact {
  final String name;
  final String phone; // digits only, no country code

  /// "Daughter", "Son", "Neighbor", ... (optional).
  final String relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship = '',
  });

  String get displayPhone => UserProfile.formatPhone(phone);

  /// Number to dial for the SOS button.
  String get dialNumber => '+63$phone';

  /// "Maria" from "Maria Dela Cruz", for the short "If no answer" chips.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() =>
      {'name': name, 'phone': phone, 'relationship': relationship};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
    );
  }

  String encode() => jsonEncode(toJson());

  factory EmergencyContact.decode(String source) =>
      EmergencyContact.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// The SOS call order, first to last.
  static String encodeList(List<EmergencyContact> contacts) =>
      jsonEncode([for (final c in contacts) c.toJson()]);

  static List<EmergencyContact> decodeList(String source) => [
        for (final item in jsonDecode(source) as List)
          EmergencyContact.fromJson(item as Map<String, dynamic>),
      ];
}
