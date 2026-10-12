import 'package:flutter/widgets.dart';

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

  /// The ID photo from the office. It needs the sign-in token, so it is sent
  /// as a header; anything not on the SCMS backend is refused.
  ImageProvider? idPhoto(String photoUrl) {
    final token = _api.token;
    if (photoUrl.isEmpty || token == null || !_api.isConnected) return null;

    final base = Uri.parse(_api.baseUrl);
    final url = base.resolve(photoUrl);
    if (url.scheme != base.scheme ||
        url.host != base.host ||
        url.port != base.port) {
      return null;
    }

    return NetworkImage(url.toString(),
        headers: {'Authorization': 'Bearer $token'});
  }
}
