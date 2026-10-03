enum PlaceCategory { health, pharmacy, government, discount }

extension PlaceCategoryInfo on PlaceCategory {
  /// Key in lib/l10n/app_*.arb.
  String get labelKey {
    switch (this) {
      case PlaceCategory.health:
        return 'guideHealth';
      case PlaceCategory.pharmacy:
        return 'guidePharmacy';
      case PlaceCategory.government:
        return 'guideGovernment';
      case PlaceCategory.discount:
        return 'guideDiscounts';
    }
  }

  static PlaceCategory parse(String? name) {
    return PlaceCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => PlaceCategory.government,
    );
  }
}

/// A clinic, pharmacy, office or store in the Local Guide.
class Place {
  final String id;
  final String name;
  final PlaceCategory category;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final String hours;
  final String note;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone = '',
    this.hours = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'hours': hours,
        'note': note,
      };

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: PlaceCategoryInfo.parse(json['category'] as String?),
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      phone: json['phone'] as String? ?? '',
      hours: json['hours'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}
