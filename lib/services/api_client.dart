import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;

  /// The server's reason, e.g. "wrong_code" or "expired" (if it sent one).
  final String? code;

  /// HTTP status, or null when the server could not be reached.
  final int? statusCode;

  const ApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() => message;
}

/// Talks to "the server".
///
/// When [baseUrl] is set, requests go to the SCMS backend (Laravel) at
/// [baseUrl]/api/mobile. Addresses the backend does not have yet
/// ([_localOnly]), or everything when [baseUrl] is empty, answer from the
/// JSON files in assets/data/ after a short wait, like a real connection
/// would.
///
/// Set the backend address when running the app:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
class ApiClient {
  ApiClient({
    AssetBundle? bundle,
    http.Client? client,
    String? baseUrl,
    this.latency = const Duration(milliseconds: 500),
    this.timeout = const Duration(seconds: 15),
  })  : _bundle = bundle ?? rootBundle,
        _client = client ?? http.Client(),
        baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL');

  final AssetBundle _bundle;
  final http.Client _client;
  final Duration latency;
  final Duration timeout;

  /// The backend address, e.g. "http://10.0.2.2:8000". Empty = offline.
  final String baseUrl;

  /// Sign-in token from /auth/verify, sent with every request.
  String? token;

  /// True when the app talks to the real backend.
  bool get isConnected => baseUrl.isNotEmpty;

  /// Addresses the backend does not have yet: always answered on the phone.
  static const Set<String> _localOnly = {
    '/notifications',
    '/benefits',
    '/places',
    '/wallet',
    '/violations',
  };

  /// Address -> seed file in assets/data/.
  static const Map<String, String> _seedFiles = {
    '/notifications': 'notifications.json',
    '/announcements': 'announcements.json',
    '/benefits': 'benefits.json',
    '/places': 'places.json',
    '/wallet': 'wallet.json',
  };

  bool _isRemote(String path) => isConnected && !_localOnly.contains(path);

  Future<dynamic> get(String path) async {
    if (_isRemote(path)) {
      return _send(http.Request('GET', _uri(path)));
    }
    await Future<void>.delayed(latency);
    final file = _seedFiles[path];
    if (file == null) throw ApiException('Unknown address: $path');
    try {
      final raw = await _bundle.loadString('assets/data/$file', cache: false);
      return jsonDecode(raw);
    } on FormatException {
      throw ApiException('The file assets/data/$file is not valid JSON.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException('Could not load the information.');
    }
  }

  /// Sends [body]. Offline it returns {"ok": true, "reference": "SC-123456"}.
  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
      ) async {
    if (_isRemote(path)) {
      final request = http.Request('POST', _uri(path))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
      return _asMap(await _send(request));
    }
    await Future<void>.delayed(latency);
    return {'ok': true, 'reference': newReference()};
  }

  /// Sends the file at [filePath] as "file", with [fields] as form fields.
  Future<Map<String, dynamic>> postFile(
      String path, {
        required String filePath,
        Map<String, String> fields = const {},
      }) async {
    if (_isRemote(path)) {
      final request = http.MultipartRequest('POST', _uri(path))
        ..fields.addAll(fields);
      try {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      } on FileSystemException {
        throw const ApiException('The photo is missing. Please take it again.');
      }
      return _asMap(await _send(request));
    }
    return post(path, fields);
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api/mobile$path');

  Future<dynamic> _send(http.BaseRequest request) async {
    const noConnection = ApiException(
      'Could not connect. Please check your internet and try again.',
    );
    request.headers['Accept'] = 'application/json';
    final token = this.token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on SocketException {
      throw noConnection;
    } on TimeoutException {
      throw noConnection;
    } on http.ClientException {
      throw noConnection;
    }

    dynamic data;
    try {
      final text = utf8.decode(response.bodyBytes);
      data = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      data = null;
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return data;

    // Laravel sends {"message": "...", "code": "..."} for errors the user
    // can fix (wrong code, missing paper). Server crashes get a plain text.
    final message = data is Map && status < 500 ? data['message'] : null;
    throw ApiException(
      message is String && message.isNotEmpty
          ? message
          : status == 401
          ? 'Please sign in again.'
          : 'Could not load the information.',
      code: data is Map ? data['code'] as String? : null,
      statusCode: status,
    );
  }

  static Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  /// Reference number shown to the user, e.g. "SC-482913".
  static String newReference() {
    final n = DateTime.now().millisecondsSinceEpoch % 1000000;
    return 'SC-${n.toString().padLeft(6, '0')}';
  }
}
