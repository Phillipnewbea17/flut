import '../models/senior_id.dart';
import 'api_client.dart';

class WalletService {
  WalletService(this._api);

  final ApiClient _api;

  /// The digital Senior Citizen ID, or null if it is not issued yet.
  Future<SeniorId?> fetchSeniorId() async {
    final data = await _api.get('/wallet');
    if (data is! Map) return null;
    final raw = data['seniorId'];
    if (raw is! Map) return null;
    return SeniorId.fromJson(Map<String, dynamic>.from(raw));
  }
}
