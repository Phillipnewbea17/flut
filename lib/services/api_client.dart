import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;

  /// The server's reason, e.g. "wrong_code" or "expired" (if it sent one).
  final String? code;

  /// HTTP status, or null when the server could not be reached.
  final int? statusCode;

  /// Tries left, when the server says.
  final int? attemptsLeft;

  /// The address the server is talking about, when it names one (an
  /// account whose email has not been confirmed).
  final String? email;

  /// How long to wait before trying again (429 answers), when known.
  final Duration? retryAfter;

  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.attemptsLeft,
    this.retryAfter,
    this.email,
  });

  @override
  String toString() => message;
}

/// Talks to the SCMS backend (Laravel) at [baseUrl]/api/mobile.
///
/// Everything about the user (sign-in, profile, application, requests,
/// Senior ID, pension, notifications, announcements) comes from the
/// backend. Without a backend address nothing is sent and nothing is
/// pretended: every call fails with "not connected".
///
/// The only answers from the phone are the [_bundled] guides (benefits
/// and discounts, places): reference content shipped with the app, which
/// the backend has no tables for.
///
/// The address is baked in ([permanentBaseUrl]), so an installed app works
/// on any phone, on mobile data, with no extra flags. Override it for local
/// work:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
/// Pass an empty one (--dart-define=API_BASE_URL=) to run with no backend.
class ApiClient {
  ApiClient({
    AssetBundle? bundle,
    http.Client? client,
    String? baseUrl,
    this.latency = const Duration(milliseconds: 500),
    this.timeout = const Duration(seconds: 15),
  })  : _bundle = bundle ?? rootBundle,
        _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: permanentBaseUrl,
            );

  /// Where the SCMS backend answers when nothing else is given.
  ///
  /// 10.0.2.2 is how the Android emulator reaches the computer it runs on,
  /// so `flutter run` on the emulator talks to `php artisan serve` with no
  /// flags and no tunnel. It never changes.
  ///
  /// A real phone cannot use this address: it has no way to reach the
  /// computer. Build for one with a public address instead, e.g.
  ///   flutter build apk --dart-define=API_BASE_URL=https://`tunnel`
  /// See ella-proj/start-scms.ps1, which opens that address.
  static const String permanentBaseUrl = 'http://10.0.2.2:8000';

  final AssetBundle _bundle;
  final http.Client _client;
  final Duration latency;
  final Duration timeout;

  /// The backend address, e.g. "http://10.0.2.2:8000". Empty = offline.
  final String baseUrl;

  /// Session token from /auth/login or /auth/register, sent with every
  /// request.
  String? token;

  /// Called when the backend refuses the session token (401) on a
  /// signed-in request, so the app can send the user back to Login.
  /// Sign-in requests (/auth/...) never call it.
  void Function()? onSessionExpired;

  /// True when the app talks to the real backend.
  bool get isConnected => baseUrl.isNotEmpty;

  /// Guides shipped with the app (not user data; the backend has no tables
  /// for them): address -> file in assets/data/.
  static const Map<String, String> _bundled = {
    '/places': 'places.json',
  };

  /// Addresses the backend answers, but which also ship a copy in the app
  /// for when it cannot be reached: address -> file in assets/data/.
  ///
  /// OSCA keeps the benefit cards in the web app now, so the backend has the
  /// current wording. Most of them are national law that rarely changes, and
  /// a senior at a pharmacy counter needs to show what they are entitled to
  /// even with no signal - so a slightly old copy beats an error.
  static const Map<String, String> _fallback = {
    '/benefits': 'benefits.json',
  };

  static const ApiException notConnected = ApiException(
    'This app is not connected to the OSCA office. Please contact OSCA.',
  );

  /// True when [path] goes to the SCMS backend.
  bool isLive(String path) => isConnected && !_bundled.containsKey(path);

  Future<dynamic> get(String path) async {
    final file = _bundled[path];
    if (file != null) return _readBundled(file);

    final backup = _fallback[path];
    if (!isConnected) {
      if (backup != null) return _readBundled(backup);
      throw notConnected;
    }
    try {
      return await _send(http.Request('GET', _uri(path)));
    } on ApiException {
      if (backup != null) return _readBundled(backup);
      rethrow;
    }
  }

  Future<dynamic> _readBundled(String file) async {
    await Future<void>.delayed(latency);
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

  /// Sends [body] as JSON.
  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
      ) async {
    if (!isLive(path)) throw notConnected;
    final request = http.Request('POST', _uri(path))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
    return _asMap(await _send(request));
  }

  /// Sends the file at [filePath] as "file", with [fields] as form fields.
  Future<Map<String, dynamic>> postFile(
      String path, {
        required String filePath,
        Map<String, String> fields = const {},
      }) async {
    if (!isLive(path)) throw notConnected;
    final request = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields);
    try {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } on FileSystemException {
      throw const ApiException('The photo is missing. Please take it again.');
    }
    return _asMap(await _send(request));
  }

  /// Sends [bytes] as the multipart "file" without saving it on the phone
  /// first (selfies).
  Future<Map<String, dynamic>> postBytes(
      String path, {
        required Uint8List bytes,
        required String filename,
        Map<String, String> fields = const {},
      }) async {
    if (!isLive(path)) throw notConnected;
    final request = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _asMap(await _send(request));
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api/mobile$path');

  Future<dynamic> _send(http.BaseRequest request) async {
    const noConnection = ApiException(
      'Could not connect. Please check your internet and try again.',
    );
    request.headers['Accept'] = 'application/json';
    // A free ngrok address answers an unknown visitor with a warning page
    // instead of the backend. This header asks for the backend itself.
    if (request.url.host.endsWith('.ngrok-free.app')) {
      request.headers['ngrok-skip-browser-warning'] = 'true';
    }
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

    if (status == 401 && token != null && !_isAuthPath(request.url)) {
      onSessionExpired?.call();
    }

    // Laravel sends {"message": "...", "code": "..."} for errors the user
    // can fix (wrong code, missing paper). Server crashes get a plain text.
    final message = data is Map && status < 500 ? data['message'] : null;
    final attemptsLeft = data is Map ? data['attemptsLeft'] : null;
    final retryAfter = data is Map ? data['retryAfter'] : null;
    final email = data is Map ? data['email'] : null;
    final retryHeader = int.tryParse(response.headers['retry-after'] ?? '');
    throw ApiException(
      message is String && message.isNotEmpty
          ? message
          : status == 401
          ? 'Please sign in again.'
          : 'Could not load the information.',
      code: data is Map ? data['code'] as String? : null,
      statusCode: status,
      attemptsLeft: attemptsLeft is num ? attemptsLeft.toInt() : null,
      retryAfter: retryAfter is num
          ? Duration(seconds: retryAfter.toInt())
          : retryHeader == null
          ? null
          : Duration(seconds: retryHeader),
      email: email is String && email.isNotEmpty ? email : null,
    );
  }

  static bool _isAuthPath(Uri url) => url.path.startsWith('/api/mobile/auth/');

  static Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
}
