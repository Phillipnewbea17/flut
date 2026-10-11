import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_senior_app/models/service_request.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/requests_service.dart';

ServiceRequest _request(RequestKind kind) => ServiceRequest(
      id: 'medical-1',
      kind: kind,
      title: 'Medicine',
      createdAt: DateTime(2026, 10, 1),
      payload: const {'assistanceType': 'Medicine'},
    );

void main() {
  group('status words from the web modules', () {
    test('map to one status list, keeping the office word', () {
      final cases = {
        'Pending': RequestStatus.pending,
        'Working on it': RequestStatus.inProgress,
        'On Hold': RequestStatus.onHold,
        'Approved': RequestStatus.approved,
        'Completed': RequestStatus.completed,
        'Released': RequestStatus.completed,
        'Resolved': RequestStatus.completed,
        'Rejected': RequestStatus.rejected,
        'Closed': RequestStatus.closed,
      };
      cases.forEach((word, status) {
        final r = ServiceRequest.fromJson({'reference': 'X-1', 'status': word},
            kind: RequestKind.help);
        expect(r.status, status, reason: word);
        expect(r.statusLabel, word, reason: word);
      });
    });

    test('a saved copy reads back the same', () {
      final saved = _request(RequestKind.medical).copyWith(
        status: RequestStatus.inProgress,
        sendError: () => 'offline',
      );
      final read = ServiceRequest.fromJson(saved.toJson());
      expect(read.status, RequestStatus.inProgress);
      expect(read.statusLabel, 'Under review');
      expect(read.kind, RequestKind.medical);
      expect(read.payload, {'assistanceType': 'Medicine'});
      expect(read.sendError, 'offline');
    });
  });

  group('RequestsService', () {
    test('without a backend address nothing is sent or faked', () async {
      final api = ApiClient(
        baseUrl: '',
        latency: Duration.zero,
        client: MockClient((_) async => fail('should not call the backend')),
      );
      final service = RequestsService(api);

      for (final kind in RequestKind.values) {
        expect(service.isAvailable(kind), isFalse, reason: kind.name);
        await expectLater(
          service.submit(_request(kind), DateTime(2026, 10, 4)),
          throwsA(isA<NotConnectedException>()),
        );
        expect(await service.fetch(kind), isEmpty);
      }
    });

    test('every request kind goes to the backend', () async {
      final paths = <String>[];
      final api = ApiClient(
        baseUrl: 'http://backend:8000',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
              '{"ok":true,"reference":"MED-2026-0001","status":"Pending"}', 201);
        }),
      );
      final service = RequestsService(api);

      for (final kind in RequestKind.values) {
        expect(service.isAvailable(kind), isTrue, reason: kind.name);
        final sent = await service.submit(_request(kind), DateTime(2026, 10, 4));
        expect(sent.reference, 'MED-2026-0001');
      }
      expect(paths, [
        '/api/mobile/medical-requests',
        '/api/mobile/burial-requests',
        '/api/mobile/help-requests',
        '/api/mobile/senior-id/replacement-requests',
      ]);
      expect(api.isLive('/medical-requests/MED-1/attachments'), isTrue);
    });

    test('an answer without the office reference is not "sent"', () async {
      final api = ApiClient(
        baseUrl: 'http://backend:8000',
        client: MockClient((_) async => http.Response('{"ok":true}', 201)),
      );
      await expectLater(
        RequestsService(api).submit(
            _request(RequestKind.help), DateTime(2026, 10, 4)),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
