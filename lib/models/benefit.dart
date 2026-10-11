enum BenefitCategory { discount, health, pension, assistance }

extension BenefitCategoryInfo on BenefitCategory {
  String get label {
    switch (this) {
      case BenefitCategory.discount:
        return 'Discounts';
      case BenefitCategory.health:
        return 'Health';
      case BenefitCategory.pension:
        return 'Pension';
      case BenefitCategory.assistance:
        return 'Other help';
    }
  }

  static BenefitCategory parse(String? name) =>
      tryParse(name) ?? BenefitCategory.assistance;

  static BenefitCategory? tryParse(String? name) {
    for (final c in BenefitCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// One benefit in "Benefits & services".
class Benefit {
  final String id;
  final String title;
  final BenefitCategory category;
  final String summary;
  final String details;
  final List<String> howToGet;

  const Benefit({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.details,
    this.howToGet = const [],
  });

  factory Benefit.fromJson(Map<String, dynamic> json) {
    final steps = json['howToGet'];
    return Benefit(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: BenefitCategoryInfo.parse(json['category'] as String?),
      summary: json['summary'] as String? ?? '',
      details: json['details'] as String? ?? '',
      howToGet: steps is List ? steps.whereType<String>().toList() : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'summary': summary,
        'details': details,
        'howToGet': howToGet,
      };
}

/// News from the OSCA or the town ("Latest announcements" on Home).
/// Kept here because announcements usually tell seniors about benefits.
class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime date;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
      };
}
