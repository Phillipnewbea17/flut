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

  test('announcements come from the seed file when baseUrl is empty', () async {
    final api = ApiClient(
      bundle: bundle,
      baseUrl: '',
      latency: Duration.zero,
      client: MockClient((_) async => fail('should not call the backend')),
    );

    final data = await api.get('/announcements');

    expect((data as List).first['title'], 'From seed');
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
