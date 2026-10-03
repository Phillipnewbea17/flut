import '../models/place.dart';
import 'api_client.dart';

class PlacesService {
  PlacesService(this._api);

  final ApiClient _api;

  Future<List<Place>> fetchPlaces() async {
    final data = await _api.get('/places');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Place.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
