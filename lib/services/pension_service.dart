import '../models/pension_record.dart';
import 'api_client.dart';

/// The signed-in senior's own pension releases, as the OSCA office recorded
/// them.
///
/// SCMS backend route (linked accounts only):
///   GET /api/mobile/pension -> [{"period": "...", "status": "Released",
///        "releaseDate": "2026-09-30", "reference": "PEN-2026-0091",
///        "receivedBy": "Senior", "remarks": "", "recordedAt": null}, ...]
/// It must only return releases linked to the signed-in account.
class PensionService {
  PensionService(this._api);

  final ApiClient _api;

  static const _path = '/pension';

  /// Newest first. Throws the ApiException when the office cannot answer (no
  /// connection, account not linked yet, server error), so the screen never
  /// shows an empty list that looks like "no releases".
  Future<List<PensionRecord>> fetchMine() async {
    final data = await _api.get(_path);
    if (data is! List) {
      throw const ApiException('Could not load your pension records.');
    }
    final list = data
        .whereType<Map>()
        .map((e) => PensionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => (b.releaseDate ?? DateTime(1900))
        .compareTo(a.releaseDate ?? DateTime(1900)));
    return list;
  }
}
