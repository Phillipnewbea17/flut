import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_senior_app/models/application_status.dart';
import 'package:my_senior_app/models/document_item.dart';
import 'package:my_senior_app/repositories/document_repository.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/document_service.dart';
import 'package:my_senior_app/storage/document_vault.dart';
import 'package:my_senior_app/storage/local_db.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

DocumentItem _photo(DocumentStatus status, {DateTime? at}) => DocumentItem(
      id: 'proofOfResidence-1',
      type: DocumentType.proofOfResidence,
      filePath: '/tmp/x.jpg',
      sizeBytes: 1,
      addedAt: at ?? DateTime(2026, 9, 28),
      status: status,
    );

DocumentState _state(
  DocumentItem? item, {
  DocumentReview? review,
  bool approved = false,
  bool live = true,
}) =>
    documentStateOf(
      item: item,
      review: review,
      applicationApproved: approved,
      sendsToOffice: live,
    );

void main() {
  test('what is on the phone', () {
    expect(_state(null), DocumentState.notSubmitted);
    expect(_state(_photo(DocumentStatus.uploading)), DocumentState.sending);
    expect(_state(_photo(DocumentStatus.failed)), DocumentState.notSent);
    expect(_state(_photo(DocumentStatus.uploaded)), DocumentState.submitted);
  });

  test('demo mode never says a photo reached the office', () {
    expect(
      _state(_photo(DocumentStatus.uploaded), live: false, approved: true),
      DocumentState.savedOnPhone,
    );
  });

  test("the office's review decides, until a newer photo is sent", () {
    final review = DocumentReview(
      type: DocumentType.proofOfResidence,
      status: DocumentReviewStatus.needsCorrection,
      note: 'Blurred',
      reviewedAt: DateTime(2026, 10, 2),
    );
    expect(
      _state(_photo(DocumentStatus.uploaded), review: review),
      DocumentState.needsCorrection,
    );
    expect(
      _state(_photo(DocumentStatus.uploaded, at: DateTime(2026, 10, 3)),
          review: review),
      DocumentState.submitted,
    );
  });

  test('an approved application approves its sent papers', () {
    expect(
      _state(_photo(DocumentStatus.uploaded), approved: true),
      DocumentState.approved,
    );
  });

  test('GET /application may include per-paper results', () {
    final status = ApplicationStatus.fromJson({
      'applicationNo': 'APP-2026-0012',
      'stage': 'needsAction',
      'message': 'Please fix your proof of address.',
      'documents': [
        {
          'type': 'proofOfResidence',
          'status': 'needsCorrection',
          'note': 'Blurred',
          'reviewedAt': '2026-10-02T10:00:00',
        },
      ],
    });
    expect(status.stage, ApplicationStage.needsAction);
    expect(status.reviewOf(DocumentType.proofOfResidence)?.note, 'Blurred');
    expect(status.reviewOf(DocumentType.idPhoto), isNull);

    // The saved copy keeps them.
    final again = ApplicationStatus.fromJson(status.toJson());
    expect(again.documents.single.status, DocumentReviewStatus.needsCorrection);
  });

  test('new stages: rejected and cancelled', () {
    expect(ApplicationStageText.parse('rejected'), ApplicationStage.rejected);
    expect(ApplicationStageText.parse('cancelled'), ApplicationStage.cancelled);
    expect(ApplicationStage.cancelled.wasSent, isFalse);
    expect(ApplicationStage.rejected.canSubmit, isTrue);
    expect(ApplicationStage.submitted.canSubmit, isFalse);
  });

  test('a new phone shows what the office has, with no photo here', () {
    final approved = DocumentReview(
      type: DocumentType.validId,
      status: DocumentReviewStatus.approved,
      reviewedAt: DateTime(2026, 10, 2),
    );
    expect(_state(null, review: approved), DocumentState.approved);
    expect(_state(null), DocumentState.notSubmitted);
  });

  test('the office can ask for new photos of some papers only', () {
    final status = ApplicationStatus.fromJson({
      'stage': 'needsAction',
      'message': 'Please send a new proof of address.',
      'canUpload': true,
      'reuploadTypes': ['proofOfResidence', 'notAPaper'],
      'documents': [
        {'type': 'validId', 'status': 'approved'},
        {'type': 'proofOfResidence', 'status': 'needsCorrection'},
      ],
    });
    expect(status.reuploadTypes, [DocumentType.proofOfResidence]);
    expect(status.canUploadType(DocumentType.proofOfResidence), isTrue);
    expect(status.canUploadType(DocumentType.validId), isFalse);
  });

  test('papers can be sent only when the server says so', () {
    final sent = ApplicationStatus.fromJson(
        {'stage': 'submitted', 'canUpload': false});
    expect(DocumentType.values.any(sent.canUploadType), isFalse);

    // A saved copy from before canUpload existed: the stage decides.
    expect(ApplicationStatus.fromJson({'stage': 'notStarted'}).canUpload,
        isTrue);
    expect(ApplicationStatus.fromJson({'stage': 'submitted'}).canUpload,
        isFalse);
    final saved = ApplicationStatus.fromJson(ApplicationStatus.empty().toJson());
    expect(saved.canUpload, isTrue);
    expect(saved.reuploadTypes, isEmpty);
  });

  group('the papers count with the office\'s list', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('scms_documents');
      PathProviderPlatform.instance = _TempPaths(temp);
    });
    tearDown(() => temp.delete(recursive: true));

    /// A phone whose office accepts every photo sent to it.
    Future<DocumentRepository> repository() async => DocumentRepository(
          service: DocumentService(ApiClient(
            baseUrl: 'http://backend:8000',
            latency: Duration.zero,
            client: MockClient((_) async => http.Response('{"ok":true}', 201)),
          )),
          vault: await DocumentVault.open(),
          db: await LocalDb.open(),
        );

    final photo = Uint8List.fromList([1, 2, 3]);

    test('papers the office has count, with those sent from this phone',
        () async {
      final documents = await repository();
      await documents.add(DocumentType.validId, photo);
      final status = ApplicationStatus.fromJson({
        'stage': 'submitted',
        'documents': [
          {'type': 'birthCertificate', 'status': 'pending'},
        ],
      });
      expect(documents.sentCount(status), 2);
      expect(documents.sentCount(ApplicationStatus.empty()), 1);
    });

    test('a first submission needs all four papers, a new request only those asked for',
        () async {
      final documents = await repository();
      final asked = ApplicationStatus.fromJson({
        'stage': 'needsAction',
        'canUpload': true,
        'reuploadTypes': ['proofOfResidence'],
        'documents': [
          {
            'type': 'proofOfResidence',
            'status': 'needsCorrection',
            'reviewedAt': '2020-01-01T00:00:00+08:00',
          },
        ],
      });
      expect(DocumentRepository.requiredFor(ApplicationStatus.empty()),
          DocumentType.values);
      expect(DocumentRepository.requiredFor(asked),
          [DocumentType.proofOfResidence]);

      // The office's copy is old: a new photo is what it is waiting for.
      expect(documents.readyToSubmit(asked), isFalse);
      await documents.add(DocumentType.proofOfResidence, photo);
      expect(documents.readyToSubmit(asked), isTrue);
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
