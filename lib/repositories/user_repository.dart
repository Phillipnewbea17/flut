import 'package:flutter/foundation.dart';

import '../app_state/user_provider.dart';
import '../models/identity_verification.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/profile_photo_store.dart';
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

  /// Sends profile changes to the server. Returns null once the server has
  /// saved them, otherwise why not, in plain words (no connection, or what
  /// the server refused). Nothing is kept to send later, so a screen must
  /// only say "saved" on null.
  Future<String?> syncProfile(UserProfile profile) async {
    try {
      final result = await _api.post('/profile', profile.toJson());
      return result['ok'] == true ? null : _notSaved;
    } on ApiException catch (e) {
      // A server crash has no message meant for the senior.
      if ((e.statusCode ?? 0) >= 500) return _notSaved;
      return e.message;
    } catch (_) {
      return _notSaved;
    }
  }

  static const String _notSaved =
      'Your change was not saved. Please try again.';

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

  /// Tells the server to drop the app-profile photo. Returns false when it
  /// could not be reached.
  Future<bool> removePhoto() async {
    try {
      final result = await _api.post('/profile/photo/remove', const {});
      return result['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Sends a profile photo change that could not reach the server earlier
  /// (see ProfilePhotoStore.markPending). [photoPath] is the photo the
  /// phone shows now. Called when the app opens and when it comes back.
  Future<void> sendPendingPhoto(
    ProfilePhotoStore store,
    String? photoPath,
  ) async {
    final change = await store.pending();
    if (change == null) return;

    final bool sent;
    switch (change) {
      case PendingPhoto.remove:
        sent = await removePhoto();
      case PendingPhoto.upload:
        final bytes = photoPath == null ? null : await store.read(photoPath);
        if (bytes == null) {
          // The photo is gone from this phone: nothing left to send.
          await store.clearPending();
          return;
        }
        sent = await uploadPhoto(bytes);
    }
    if (sent) await store.clearPending();
  }

  /// Makes the app-profile photo on this phone match the server's, once the
  /// server has sent its profile ([server], from GET /profile). Downloads the
  /// photo when the phone has none or another version, and drops the phone's
  /// copy when the server has none. A change still waiting to be sent
  /// (ProfilePhotoStore.pending) is never overwritten. When the download fails
  /// (no connection), the phone keeps the photo it has.
  Future<void> syncPhoto(
    ProfilePhotoStore store,
    UserProvider user,
    LinkedProfile server,
  ) async {
    final shown = user.profile?.photoPath;
    final path = await _photoFor(store, shown, server);
    if (path == shown) return;
    if (user.profile?.photoPath != shown) {
      // The senior picked another photo while this was downloading: theirs
      // stays, and this copy is dropped.
      await store.delete(path);
      return;
    }
    await user.setPhotoPath(path);
  }

  /// The photo path the phone should show after matching [server]: [shown]
  /// when nothing changes, otherwise the new file or null.
  Future<String?> _photoFor(
    ProfilePhotoStore store,
    String? shown,
    LinkedProfile server,
  ) async {
    if (await store.pending() != null) return shown;

    if (!server.hasPhoto) {
      await store.delete(shown);
      await store.saveVersion(null);
      return null;
    }
    if (await store.exists(shown) &&
        await store.savedVersion() == server.photoVersion) {
      return shown;
    }

    final Uint8List? bytes;
    try {
      bytes = await _api.getBytes('/profile/photo');
    } catch (_) {
      return shown; // Not reachable now: keep the photo the phone has.
    }
    if (bytes == null) {
      // The server has no photo after all.
      await store.delete(shown);
      await store.saveVersion(null);
      return null;
    }
    final path = await store.save(bytes);
    if (path == null) return shown; // Not a picture the phone can read.
    await store.delete(shown);
    await store.saveVersion(server.photoVersion);
    return path;
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
