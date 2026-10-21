import '../models/announcement.dart';
import 'api_client.dart';

/// News from the OSCA office (Home and Announcements).
class AnnouncementsService {
  AnnouncementsService(this._api);

  final ApiClient _api;

  /// Newest posted first.
  Future<List<Announcement>> fetchAnnouncements() async {
    final data = await _api.get('/announcements');
    if (data is! List) return const [];
    final list = data
        .whereType<Map>()
        .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return list;
  }
}
