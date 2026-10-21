import 'dart:typed_data';

import '../models/senior_id.dart';
import 'api_client.dart';

class WalletService {
  WalletService(this._api);

  final ApiClient _api;

  /// The OSCA ID an administrator issued on the web, or null when the office
  /// has not issued one yet (the backend answers has_id: false).
  Future<SeniorId?> fetchSeniorId() async {
    final data = await _api.get('/my-senior-id');
    if (data is! Map) return null;
    if (data['has_id'] == false) return null;
    final raw = data['seniorId'];
    if (raw is! Map) return null;
    return SeniorId.fromJson(Map<String, dynamic>.from(raw));
  }

  /// The 2x2 photo the senior submitted with the application, as bytes (sent
  /// with the sign-in token). Null when the office has none.
  Future<Uint8List?> fetchPhoto() => _api.getBytes('/my-senior-id/photo');
}
