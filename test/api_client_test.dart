import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:my_senior_app/app_state/user_provider.dart';
import 'package:my_senior_app/models/identity_verification.dart';
import 'package:my_senior_app/models/personal_info.dart';
import 'package:my_senior_app/repositories/user_repository.dart';
import 'package:my_senior_app/services/announcements_service.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/profile_photo_store.dart';
import 'package:my_senior_app/storage/local_db.dart';
import 'package:my_senior_app/storage/preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves a fixed seed file instead of the real assets.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw Exception('No asset $key');
    return ByteData.sublistView(utf8.encode(text));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final text = files[key];
    if (text == null) throw Exception('No asset $key');
    return text;
  }
}

void main() {
  final bundle = _FakeBundle({
    'assets/data/announcements.json': '[{"id":"seed","title":"From seed"}]',
  });

  test('announcements come from the backend when baseUrl is set', () async {
    Uri? called;
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((request) async {
        called = request.url;
        return http.Response('[{"id":"1","title":"From server"}]', 200);
      }),
    );

    final data = await api.get('/announcements');

    expect(called.toString(), 'http://backend:8000/api/mobile/announcements');
    expect((data as List).first['title'], 'From server');
  });

  test('without a backend address user data is never made up', () async {
    final api = ApiClient(
      bundle: bundle,
      baseUrl: '',
      latency: Duration.zero,
      client: MockClient((_) async => fail('should not call the backend')),
    );

    for (final path in ['/announcements', '/notifications', '/wallet', '/application']) {
      await expectLater(api.get(path), throwsA(isA<ApiException>()), reason: path);
    }
    await expectLater(
        api.post('/application/submit', {}), throwsA(isA<ApiException>()));
  });

  test('a photo is downloaded as bytes, with the sign-in token', () async {
    late http.Request sent;
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((request) async {
        sent = request;
        return http.Response.bytes([0xFF, 0xD8, 0xFF], 200,
            headers: {'content-type': 'image/jpeg'});
      }),
    )..token = 'abc';

    final photo = await api.getBytes('/profile/photo');

    expect(sent.url.path, '/api/mobile/profile/photo');
    expect(sent.headers['Authorization'], 'Bearer abc');
    expect(photo, [0xFF, 0xD8, 0xFF]);
  });

  test('no photo on the server is null; other failures stay errors', () async {
    final none = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient(
          (_) async => http.Response('{"message":"No photo."}', 404)),
    );
    expect(await none.getBytes('/profile/photo'), isNull);

    final broken = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((_) async => http.Response('oops', 500)),
    );
    await expectLater(
        broken.getBytes('/profile/photo'), throwsA(isA<ApiException>()));

    final offline = ApiClient(
      bundle: bundle,
      baseUrl: '',
      latency: Duration.zero,
      client: MockClient((_) async => fail('should not call the backend')),
    );
    await expectLater(
        offline.getBytes('/profile/photo'), throwsA(isA<ApiException>()));
  });

  test('announcements show the time of day and when they were posted',
      () async {
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((_) async => http.Response(
            '[{"id":"old","title":"Old","date":"2026-10-18T08:00:00+08:00"},'
            '{"id":"new","title":"New","date":"2026-10-20T21:15:00+08:00",'
            '"postedAt":"2026-10-20T21:15:00+08:00"}]',
            200,
          )),
    );

    final list = await AnnouncementsService(api).fetchAnnouncements();

    expect(list.map((a) => a.id), ['new', 'old']);
    expect(DateFormat('MMMM d, y · h:mm a').format(list.first.postedAt),
        'October 20, 2026 · 9:15 PM');
    // Without postedAt, the date is when it was posted.
    expect(list.last.postedAt, list.last.date);
  });

  test('the places guide still ships with the app', () async {
    final api = ApiClient(
      bundle: _FakeBundle({'assets/data/places.json': '[{"id":"p1"}]'}),
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((_) async => fail('should not call the backend')),
    );

    expect((await api.get('/places') as List).first['id'], 'p1');
  });

  test('a server error becomes an ApiException', () async {
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((_) async => http.Response('oops', 500)),
    );

    expect(api.get('/announcements'), throwsA(isA<ApiException>()));
  });

  test('posts JSON with the sign-in token', () async {
    late http.Request sent;
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      client: MockClient((request) async {
        sent = request;
        return http.Response('{"ok":true,"reference":"APP-2026-0001"}', 201);
      }),
    )..token = 'abc';

    final result = await api.post('/application/submit', {
      'documents': ['a'],
    });

    expect(sent.url.path, '/api/mobile/application/submit');
    expect(sent.headers['Authorization'], 'Bearer abc');
    expect(jsonDecode(sent.body), {
      'documents': ['a'],
    });
    expect(result['reference'], 'APP-2026-0001');
    // Not an ngrok address: no ngrok header.
    expect(sent.headers.containsKey('ngrok-skip-browser-warning'), isFalse);
  });

  test('asks ngrok for the backend, not its warning page', () async {
    final hosts = <String, String?>{};
    for (final base in [
      ApiClient.permanentBaseUrl, // .ngrok-free.dev
      'https://example.ngrok-free.app',
    ]) {
      final api = ApiClient(
        bundle: bundle,
        baseUrl: base,
        client: MockClient((request) async {
          hosts[request.url.host] =
              request.headers['ngrok-skip-browser-warning'];
          return http.Response('[]', 200);
        }),
      );
      await api.get('/announcements');
    }

    expect(hosts.values, everyElement('true'));
    expect(hosts.length, 2);
  });

  test("the server's message and code reach the app", () async {
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      client: MockClient((_) async => http.Response(
            '{"message":"Wrong code. Please check and try again.","code":"wrong_code"}',
            422,
          )),
    );

    expect(
      api.post('/auth/verify', {}),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', startsWith('Wrong code'))
          .having((e) => e.code, 'code', 'wrong_code')
          .having((e) => e.statusCode, 'statusCode', 422)),
    );
  });

  test('help requests go to the backend', () async {
    late http.Request sent;
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      client: MockClient((request) async {
        sent = request;
        return http.Response('{"ok":true,"reference":"HLP-2026-0001"}', 201);
      }),
    );

    final result = await api.post('/help-requests', {'description': 'X'});

    expect(sent.url.path, '/api/mobile/help-requests');
    expect(result['reference'], 'HLP-2026-0001');
  });

  test('a missing photo file becomes an ApiException', () async {
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      client: MockClient((_) async => fail('should not call the backend')),
    );

    expect(
      api.postFile('/documents', filePath: 'does/not/exist.jpg'),
      throwsA(isA<ApiException>()),
    );
  });

  test('no connection becomes an ApiException', () async {
    final api = ApiClient(
      bundle: bundle,
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((_) async => throw http.ClientException('down')),
    );

    expect(api.get('/announcements'), throwsA(isA<ApiException>()));
  });

  group('the app-profile photo follows the server', () {
    late Directory temp;
    final jpeg =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('scms_photo');
      PathProviderPlatform.instance = _TempPaths(temp);
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() => temp.delete(recursive: true));

    /// The phone after sign-in: the account's email, and the photo tools.
    Future<(UserRepository, UserProvider, ProfilePhotoStore)> phone(
        MockClient client) async {
      final api = ApiClient(
        baseUrl: 'http://backend:8000',
        latency: Duration.zero,
        client: client,
      );
      final user = UserProvider(await Preferences.load());
      await user.confirmEmail('ana@example.com');
      return (
        UserRepository(api: api, db: await LocalDb.open()),
        user,
        ProfilePhotoStore(),
      );
    }

    LinkedProfile serverSays({required bool hasPhoto, String version = 'v1'}) =>
        LinkedProfile(
          info: PersonalInfo.empty,
          state: IdentityState.verified,
          hasPhoto: hasPhoto,
          photoVersion: version,
        );

    test('a new phone downloads the server photo once, then keeps it',
        () async {
      var downloads = 0;
      final (users, user, store) = await phone(MockClient((request) async {
        downloads++;
        return http.Response.bytes(jpeg, 200);
      }));

      await users.syncPhoto(store, user, serverSays(hasPhoto: true));
      final shown = user.profile!.photoPath!;
      expect(await File(shown).exists(), isTrue);
      expect(await store.savedVersion(), 'v1');
      expect(downloads, 1);

      // Same version on the server and the photo is still here: no download.
      await users.syncPhoto(store, user, serverSays(hasPhoto: true));
      expect(downloads, 1);
      expect(user.profile!.photoPath, shown);
    });

    test('a new version is downloaded, and a removed photo is removed here',
        () async {
      var downloads = 0;
      final (users, user, store) = await phone(MockClient((request) async {
        downloads++;
        return http.Response.bytes(jpeg, 200);
      }));

      await users.syncPhoto(store, user, serverSays(hasPhoto: true));
      final first = user.profile!.photoPath!;
      await users.syncPhoto(
          store, user, serverSays(hasPhoto: true, version: 'v2'));
      expect(downloads, 2);
      expect(await store.savedVersion(), 'v2');
      expect(await File(first).exists(), isFalse);

      await users.syncPhoto(store, user, serverSays(hasPhoto: false));
      expect(user.profile!.photoPath, isNull);
      expect(await store.savedVersion(), isNull);
    });

    test('a photo still waiting to upload is never overwritten', () async {
      final (users, user, store) = await phone(
          MockClient((_) async => fail('should not download anything')));
      // Taken offline: the upload has not gone through yet.
      final local = await store.save(jpeg);
      await user.setPhotoPath(local);
      await store.markPending(PendingPhoto.upload);

      await users.syncPhoto(store, user, serverSays(hasPhoto: false));
      expect(user.profile!.photoPath, local);
      expect(await File(local!).exists(), isTrue);
    });

    test('no connection keeps the photo the phone has', () async {
      final (users, user, store) = await phone(
          MockClient((_) async => throw http.ClientException('down')));
      final local = await store.save(jpeg);
      await user.setPhotoPath(local);
      await store.saveVersion('v1');

      await users.syncPhoto(store, user, serverSays(hasPhoto: true, version: 'v2'));
      expect(user.profile!.photoPath, local);
      expect(await store.savedVersion(), 'v1');
    });
  });
}

/// The app's private folders, in a temp folder for the test.
class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}
