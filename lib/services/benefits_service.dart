import '../models/benefit.dart';
import 'api_client.dart';

/// Benefits, announcements and discount violation reports.
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

  /// Sends a report about a store that refused the senior discount.
  /// Returns the reference number.
  Future<String> reportViolation({
    required String store,
    required String location,
    required DateTime date,
    required String issue,
    required String details,
    required String reporterPhone,
  }) async {
    final result = await _api.post('/violations', {
      'store': store,
      'location': location,
      'date': date.toIso8601String(),
      'issue': issue,
      'details': details,
      'reporterPhone': reporterPhone,
    });
    if (result['ok'] != true) {
      throw const ApiException('The report was not sent. Please try again.');
    }
    return result['reference'] as String? ?? ApiClient.newReference();
  }
}
