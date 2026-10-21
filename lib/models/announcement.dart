import '../utils/manila_time.dart';

/// News from the OSCA or the town ("Latest announcement" on Home).
class Announcement {
  final String id;
  final String title;
  final String body;

  /// The date the announcement is about, with its time of day.
  final DateTime date;

  /// When it was posted. Falls back to [date] when the server does not say.
  final DateTime postedAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    DateTime? postedAt,
  }) : postedAt = postedAt ?? date;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final date = parseServerTime(json['date'] as String?) ?? DateTime.now();
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      date: date,
      postedAt: parseServerTime(json['postedAt'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
        'postedAt': postedAt.toIso8601String(),
      };
}
