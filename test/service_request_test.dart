import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:my_senior_app/models/application_status.dart';
import 'package:my_senior_app/models/pension_record.dart';
import 'package:my_senior_app/models/service_request.dart';
import 'package:my_senior_app/repositories/requests_repository.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/requests_service.dart';
import 'package:my_senior_app/storage/document_vault.dart';
import 'package:my_senior_app/storage/local_db.dart';
import 'package:my_senior_app/utils/manila_time.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The app's private folders, in a temp folder for the test.
class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

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
        'Claimed': RequestStatus.completed,
        'Resolved': RequestStatus.completed,
        'Rejected': RequestStatus.rejected,
        'Declined': RequestStatus.rejected,
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

  group('assistance certificates', () {
    Map<String, dynamic> approved({String? claimedAt}) => {
          'clientId': 'medical-1',
          'reference': 'MED-2026-0001',
          'status': claimedAt == null ? 'Approved' : 'Claimed',
          'title': 'Medicine',
          'certificate': {
            'number': 'CRT-2026-0001',
            'code': 'K7Q4-M2XD-9PRT',
            'program': 'Medical assistance',
            'seniorName': 'Ana Dela Cruz',
            'seniorNumber': 'SC-2026-0001',
            'oscaIdNumber': 'LA-SC-2020-0001',
            'claimantName': null,
            'issuedAt': '2026-10-17T09:00:00+08:00',
            'issuedBy': 'Admin Ana',
            'state': claimedAt == null ? 'Ready to claim' : 'Claimed',
            'claimedAt': claimedAt,
            'receivedBy': claimedAt == null ? null : 'Ana Dela Cruz',
          },
        };

    test('an approved request carries its certificate, also when saved', () {
      final request =
          ServiceRequest.fromJson(approved(), kind: RequestKind.medical);
      final certificate = request.certificate!;
      expect(certificate.number, 'CRT-2026-0001');
      expect(certificate.code, 'K7Q4-M2XD-9PRT');
      expect(certificate.claimantName, '');
      expect(certificate.isClaimed, isFalse);
      expect(request.displayStatus, RequestDisplayStatus.approved);
      expect(request.category, RequestCategory.medical);

      final saved = ServiceRequest.fromJson(request.toJson());
      expect(saved.kind, RequestKind.medical);
      expect(saved.certificate!.code, 'K7Q4-M2XD-9PRT');
      expect(saved.certificate!.issuedBy, 'Admin Ana');
    });

    test('a claimed certificate is used up, and the request is finished', () {
      final request = ServiceRequest.fromJson(
          approved(claimedAt: '2026-10-20T10:30:00+08:00'),
          kind: RequestKind.medical);
      expect(request.certificate!.isClaimed, isTrue);
      expect(request.certificate!.receivedBy, 'Ana Dela Cruz');
      expect(request.status, RequestStatus.completed);
      expect(request.displayLabel, 'Claimed');
      expect(request.isActive, isFalse);
    });

    test('no certificate before approval, and a declined request says so', () {
      final declined = ServiceRequest.fromJson(
          {'reference': 'MED-2026-0001', 'status': 'Declined', 'certificate': null},
          kind: RequestKind.medical);
      expect(declined.certificate, isNull);
      expect(declined.displayStatus, RequestDisplayStatus.rejected);
      expect(declined.isActive, isFalse);
    });

    test('the bell opens the request it is about', () {
      final notice = AppNotification.fromJson({
        'id': 'MedicalRequest-1-Approved',
        'title': 'Medical assistance approved',
        'body': 'Bring your certificate.',
        'date': '2026-10-17T09:00:00+08:00',
        'request': {'kind': 'medical', 'reference': 'MED-2026-0001'},
        'hasCertificate': true,
      });
      expect(notice.requestReference, 'MED-2026-0001');
      expect(notice.hasCertificate, isTrue);

      final saved = AppNotification.fromJson(notice.copyWith(read: true).toJson());
      expect(saved.requestReference, 'MED-2026-0001');
      expect(saved.hasCertificate, isTrue);
      expect(saved.read, isTrue);

      final plain = AppNotification.fromJson(
          {'id': 'linked-1', 'title': 'Account verified', 'body': '', 'date': ''});
      expect(plain.requestReference, isEmpty);
      expect(plain.hasCertificate, isFalse);
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

  group('RequestsRepository says why the list could not load', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('scms_requests');
      PathProviderPlatform.instance = _TempPaths(temp);
    });
    tearDown(() => temp.delete(recursive: true));

    Future<RequestsRepository> loaded(MockClient client) async {
      final repo = RequestsRepository(
        service: RequestsService(
            ApiClient(baseUrl: 'http://backend:8000', client: client)),
        vault: await DocumentVault.open(),
        db: await LocalDb.open(),
      );
      await repo.load();
      return repo;
    }

    test('an account not linked yet is told so, not "no internet"', () async {
      final repo = await loaded(MockClient((_) async => http.Response(
          '{"message":"Not yet","code":"not_linked"}', 403)));
      expect(repo.notLinked, isTrue);
      expect(repo.error, isNull);
    });

    test('no connection is "no internet"', () async {
      final repo = await loaded(
          MockClient((_) async => throw http.ClientException('down')));
      expect(repo.error, startsWith('No internet'));
      expect(repo.notLinked, isFalse);
    });

    test('a server problem is not blamed on the internet', () async {
      final repo =
          await loaded(MockClient((_) async => http.Response('oops', 500)));
      expect(repo.error, startsWith('Could not load your requests'));
      expect(repo.notLinked, isFalse);
    });
  });

  group('server times are read as Philippine time', () {
    test('an evening with +08:00 stays 9:15 PM', () {
      final evening = parseServerTime('2026-10-20T21:15:00+08:00')!;
      expect(evening.isUtc, isFalse);
      expect(DateFormat('h:mm a').format(evening), '9:15 PM');
    });

    test('the same moment in UTC is also 9:15 PM', () {
      final evening = parseServerTime('2026-10-20T13:15:00Z')!;
      expect(evening.isUtc, isFalse);
      expect(DateFormat('h:mm a').format(evening), '9:15 PM');
    });

    test('a plain date or a naive time is read as written', () {
      expect(parseServerTime('2026-10-20'), DateTime(2026, 10, 20));
      expect(parseServerTime('2026-10-20T21:15:00'),
          DateTime(2026, 10, 20, 21, 15));
      expect(parseServerTime(''), isNull);
      expect(parseServerTime(null), isNull);
    });

    test('notifications and requests show the same time', () {
      final notice = AppNotification.fromJson({
        'id': 'n-1',
        'title': 'Application sent',
        'body': '',
        'date': '2026-10-20T13:15:00Z',
      });
      expect(DateFormat('h:mm a').format(notice.date), '9:15 PM');

      final request = ServiceRequest.fromJson(
          {'reference': 'HLP-1', 'status': 'Pending', 'createdAt': '2026-10-20T21:15:00+08:00'},
          kind: RequestKind.help);
      expect(DateFormat('h:mm a').format(request.createdAt), '9:15 PM');
    });
  });

  group('pension releases', () {
    test('remarks and the recording time are read when the office sends them',
        () {
      final release = PensionRecord.fromJson({
        'period': 'July–September 2026',
        'status': 'Released',
        'releaseDate': '2026-09-30',
        'reference': 'PEN-2026-0091',
        'receivedBy': 'Representative',
        'remarks': 'Signed by her son',
        'recordedAt': '2026-10-20T21:15:00+08:00',
      });
      expect(release.isReleased, isTrue);
      expect(release.remarks, 'Signed by her son');
      expect(DateFormat('h:mm a').format(release.recordedAt!), '9:15 PM');
    });

    test('a record without them still reads', () {
      final release = PensionRecord.fromJson({
        'period': 'April–June 2026',
        'status': 'On Hold',
        'releaseDate': null,
        'reference': 'PEN-2026-0090',
      });
      expect(release.isOnHold, isTrue);
      expect(release.releaseDate, isNull);
      expect(release.remarks, isEmpty);
      expect(release.recordedAt, isNull);
    });
  });

  test('a birthday greeting from the office is kept as one', () {
    final greeting = AppNotification.fromJson({
      'id': 'greeting-7d2f',
      'title': 'Happy birthday!',
      'body': 'Maligayang kaarawan from the OSCA office!',
      'date': '2026-10-20T08:00:00+08:00',
      'kind': 'greeting',
    });
    expect(greeting.isGreeting, isTrue);
    expect(AppNotification.fromJson(greeting.toJson()).isGreeting, isTrue);

    final plain = AppNotification.fromJson(
        {'id': 'linked-1', 'title': 'Account verified', 'body': '', 'date': ''});
    expect(plain.isGreeting, isFalse);
    expect(plain.kind, isEmpty);
  });
}
