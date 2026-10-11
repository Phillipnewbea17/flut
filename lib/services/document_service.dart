import '../models/document_item.dart';
import 'api_client.dart';

/// Sends photos of papers and the finished application to the server.
class DocumentService {
  DocumentService(this._api);

  final ApiClient _api;

  /// False without a backend address: then nothing can be sent.
  bool get sendsToOffice => _api.isLive('/documents');

  Future<void> upload(DocumentItem item) async {
    // Sending the same clientId again replaces the earlier photo.
    final result = await _api.postFile(
      '/documents',
      filePath: item.filePath,
      fields: {'type': item.type.name, 'clientId': item.id},
    );
    if (result['ok'] != true) {
      throw const ApiException('The photo was not sent. Please try again.');
    }
  }

  /// Returns the application reference number.
  Future<String> submitApplication(List<DocumentItem> documents) async {
    final result = await _api.post('/application/submit', {
      'documents': documents.map((d) => d.id).toList(),
    });
    final reference = result['reference'];
    // Only the OSCA office's own reference number counts as "sent".
    if (result['ok'] != true || reference is! String || reference.isEmpty) {
      throw const ApiException('The application was not sent. Please try again.');
    }
    return reference;
  }
}
