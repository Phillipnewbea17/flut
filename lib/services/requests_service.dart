import '../models/service_request.dart';
import 'api_client.dart';

/// Thrown when the backend has no route for a kind of request yet. The
/// request is then kept on the phone as "Not sent yet".
class NotConnectedException implements Exception {
  const NotConnectedException();

  @override
  String toString() =>
      'This service is not connected to the OSCA office yet. Your request '
      'is saved on this phone but was NOT sent.';
}

/// Sends requests to the SCMS backend and reads their status back.
///
/// SCMS backend routes (/api/mobile, linked accounts only). For each
/// RequestKind.apiPath:
///   GET  {apiPath}                       -> [ServiceRequest JSON, ...]
///        Only the signed-in account's requests, only public updates.
///   POST {apiPath}                       <- {"clientId": "...", ...payload}
///        -> {"ok": true, "reference": "MA-2026-0012", "status": "Pending"}
///   POST {apiPath}/{reference}/attachments  (multipart "file")
/// The web module (Medical, Burial, Help Desk, Senior IDs) shows these with
/// source "App", like Document Verification does today.
class RequestsService {
  RequestsService(this._api);

  final ApiClient _api;

  /// True when requests of [kind] really reach the OSCA office.
  bool isAvailable(RequestKind kind) => _api.isLive(kind.apiPath);

  /// Sends [request] and returns it with the office's reference and status.
  Future<ServiceRequest> submit(ServiceRequest request, DateTime now) async {
    if (!isAvailable(request.kind)) throw const NotConnectedException();

    final result = await _api.post(request.kind.apiPath, {
      'clientId': request.id,
      ...request.payload,
    });
    final reference = result['reference'];
    if (result['ok'] != true || reference is! String || reference.isEmpty) {
      throw const ApiException('The request was not sent. Please try again.');
    }

    for (final path in request.attachments) {
      await _api.postFile(
        '${request.kind.apiPath}/$reference/attachments',
        filePath: path,
        fields: {'clientId': request.id},
      );
    }

    final status = result['status'] as String?;
    return request.copyWith(
      reference: reference,
      status: RequestStatusInfo.parse(status),
      statusText: status ?? '',
      submittedAt: now,
      updatedAt: now,
      sendError: () => null,
    );
  }

  /// The account's requests of [kind], as the office sees them.
  Future<List<ServiceRequest>> fetch(RequestKind kind) async {
    if (!isAvailable(kind)) return const [];
    final data = await _api.get(kind.apiPath);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => ServiceRequest.fromJson(
              Map<String, dynamic>.from(e),
              kind: kind,
            ))
        .where((r) => r.reference.isNotEmpty)
        .toList();
  }
}
