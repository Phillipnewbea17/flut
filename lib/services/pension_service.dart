import '../models/pension_record.dart';
import 'api_client.dart';

/// The signed-in senior's own pension releases.
///
/// SCMS backend route (linked accounts only):
///   GET /api/mobile/pension -> [{"period": "...", "status": "Released",
///        "releaseDate": "2026-09-30", "reference": "PEN-2026-0091"}, ...]
/// It must only return releases linked to the signed-in account.
class PensionService {
  PensionService(this._api);

  final ApiClient _api;

  static const _path = '/pension';

  /// False without a backend address.
  bool get isAvailable => _api.isLive(_path);

  /// Newest first. Empty when [isAvailable] is false.
  Future<List<PensionRecord>> fetchMine() async {
    if (!isAvailable) return const [];
    final data = await _api.get(_path);
    if (data is! List) return const [];
    final list = data
        .whereType<Map>()
        .map((e) => PensionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => (b.releaseDate ?? DateTime(1900))
        .compareTo(a.releaseDate ?? DateTime(1900)));
    return list;
  }
}
