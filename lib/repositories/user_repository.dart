import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../storage/local_db.dart';

/// Profile syncing and the seniors a family relative helps (Family mode).
class UserRepository extends ChangeNotifier {
  UserRepository({required ApiClient api, required LocalDb db})
      : _api = api,
        _db = db;

  final ApiClient _api;
  final LocalDb _db;

  static const _kSeniors = 'managed_seniors';

  List<ManagedSenior> _seniors = [];
  bool _loaded = false;

  List<ManagedSenior> get managedSeniors => List.unmodifiable(_seniors);

  Future<void> load() async {
    if (_loaded) return;
    final raw = await _db.read(_kSeniors);
    if (raw is List) {
      _seniors = raw
          .whereType<Map>()
          .map((e) => ManagedSenior.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addSenior(ManagedSenior senior) async {
    _seniors = [..._seniors, senior];
    notifyListeners();
    await _save();
  }

  Future<void> removeSenior(String id) async {
    _seniors = _seniors.where((s) => s.id != id).toList();
    notifyListeners();
    await _save();
  }

  /// Sends profile changes to the server. Returns false when offline; the
  /// change is still saved on the phone by UserProvider.
  Future<bool> syncProfile(UserProfile profile) async {
    try {
      final result = await _api.post('/profile', profile.toJson());
      return result['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Uploads the app-profile photo so staff see it in User Management.
  /// Returns false when offline or the upload failed; the photo is still
  /// kept on this phone by UserProvider.
  Future<bool> uploadPhoto(Uint8List bytes) async {
    try {
      final result = await _api.postBytes(
        '/profile/photo',
        bytes: bytes,
        filename: 'profile.jpg',
      );
      return result['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Tells the server to drop the app-profile photo. Best effort.
  Future<bool> removePhoto() async {
    try {
      final result = await _api.post('/profile/photo/remove', const {});
      return result['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    _seniors = [];
    _loaded = false;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _db.write(_kSeniors, _seniors.map((s) => s.toJson()).toList());
    } catch (_) {
      // Storage full: still correct in memory.
    }
  }
}
