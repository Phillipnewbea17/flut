import '../models/place.dart';
import '../services/places_service.dart';
import '../storage/local_db.dart';

/// Places for the Local Guide. Uses the saved list when offline.
class PlacesRepository {
  PlacesRepository({required PlacesService service, required LocalDb db})
      : _service = service,
        _db = db;

  final PlacesService _service;
  final LocalDb _db;

  static const _kPlaces = 'places';

  /// Throws only when there is no internet AND nothing was saved before.
  Future<List<Place>> loadPlaces() async {
    try {
      final places = await _service.fetchPlaces();
      await _db.write(_kPlaces, places.map((p) => p.toJson()).toList());
      return places;
    } catch (_) {
      final saved = await _db.read(_kPlaces);
      if (saved is List && saved.isNotEmpty) {
        return saved
            .whereType<Map>()
            .map((e) => Place.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      rethrow;
    }
  }
}
