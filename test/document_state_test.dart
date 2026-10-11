import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/models/application_status.dart';
import 'package:my_senior_app/models/document_item.dart';

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
}
