import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Talks to "the server".
///
/// Addresses in [_remotePaths] come from the SCMS backend (Laravel) at
/// [baseUrl]/api/mobile when [baseUrl] is set. Everything else, or
/// everything when [baseUrl] is empty, answers from the JSON files in
/// assets/data/ after a short wait, like a real connection would.
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

  /// Addresses the backend already answers. Add more as the backend grows.
  static const Set<String> _remotePaths = {'/announcements'};

  /// Address -> seed file in assets/data/.
  static const Map<String, String> _seedFiles = {
    '/notifications': 'notifications.json',
    '/announcements': 'announcements.json',
    '/benefits': 'benefits.json',
    '/places': 'places.json',
    '/wallet': 'wallet.json',
  };

  Future<dynamic> get(String path) async {
    if (baseUrl.isNotEmpty && _remotePaths.contains(path)) {
      return _getRemote(path);
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

  Future<dynamic> _getRemote(String path) async {
    const noConnection = ApiException(
      'Could not connect. Please check your internet and try again.',
    );
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$baseUrl/api/mobile$path'),
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout);
    } on SocketException {
      throw noConnection;
    } on TimeoutException {
      throw noConnection;
    } on http.ClientException {
      throw noConnection;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Could not load the information.');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Could not load the information.');
    }
  }

  /// Sends [body]. Returns {"ok": true, "reference": "SC-123456"}.
  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
      ) async {
    await Future<void>.delayed(latency);
    return {'ok': true, 'reference': newReference()};
  }

  /// Reference number shown to the user, e.g. "SC-482913".
  static String newReference() {
    final n = DateTime.now().millisecondsSinceEpoch % 1000000;
    return 'SC-${n.toString().padLeft(6, '0')}';
  }
}
