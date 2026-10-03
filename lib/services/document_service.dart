import '../models/document_item.dart';
import 'api_client.dart';

/// Sends photos of papers and the finished application to the server.
class DocumentService {
  DocumentService(this._api);

  final ApiClient _api;

  Future<void> upload(DocumentItem item) async {
    final result = await _api.post('/documents', {
      'id': item.id,
      'type': item.type.name,
      'sizeBytes': item.sizeBytes,
    });
    if (result['ok'] != true) {
      throw const ApiException('The photo was not sent. Please try again.');
    }
  }

  /// Returns the application reference number.
  Future<String> submitApplication(List<DocumentItem> documents) async {
    final result = await _api.post('/application/submit', {
      'documents': documents.map((d) => d.id).toList(),
    });
    if (result['ok'] != true) {
      throw const ApiException('The application was not sent. Please try again.');
    }
    return result['reference'] as String? ?? ApiClient.newReference();
  }
}
