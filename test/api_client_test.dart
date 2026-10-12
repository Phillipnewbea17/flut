import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_senior_app/services/api_client.dart';

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

  // OSCA keeps the benefit cards in the web app, so the office's wording
  // wins. The shipped copy is only a backup for when it cannot be reached.
  test('benefits come from the OSCA office', () async {
    final api = ApiClient(
      bundle: _FakeBundle({'assets/data/benefits.json': '[{"id":"shipped"}]'}),
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient(
          (_) async => http.Response('[{"id":"from-osca"}]', 200)),
    );

    expect((await api.get('/benefits') as List).first['id'], 'from-osca');
  });

  test('benefits fall back to the shipped copy with no signal', () async {
    final offline = ApiClient(
      bundle: _FakeBundle({'assets/data/benefits.json': '[{"id":"shipped"}]'}),
      baseUrl: '',
      latency: Duration.zero,
      client: MockClient((_) async => fail('should not call the backend')),
    );
    expect((await offline.get('/benefits') as List).first['id'], 'shipped');

    // Reachable, but the office's server is having a bad day.
    final failing = ApiClient(
      bundle: _FakeBundle({'assets/data/benefits.json': '[{"id":"shipped"}]'}),
      baseUrl: 'http://backend:8000',
      latency: Duration.zero,
      client: MockClient((_) async => http.Response('oops', 500)),
    );
    expect((await failing.get('/benefits') as List).first['id'], 'shipped');
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
}
