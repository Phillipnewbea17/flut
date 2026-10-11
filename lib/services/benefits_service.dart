import '../models/benefit.dart';
import 'api_client.dart';

/// Benefits and announcements. (Store discount reports are Help & complaints
/// requests, see RequestsRepository.)
class BenefitsService {
  BenefitsService(this._api);

  final ApiClient _api;

  Future<List<Benefit>> fetchBenefits() async {
    final data = await _api.get('/benefits');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Benefit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Newest first.
  Future<List<Announcement>> fetchAnnouncements() async {
    final data = await _api.get('/announcements');
    if (data is! List) return const [];
    final list = data
        .whereType<Map>()
        .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
