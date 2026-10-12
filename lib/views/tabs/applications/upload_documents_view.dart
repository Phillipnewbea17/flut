import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/application_status.dart';
import '../../../models/document_item.dart';
import '../../../repositories/application_repository.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../routes/app_router.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/image_compressor.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/onboarding_scaffold.dart';
import '../../../widgets/section_title.dart';
import '../../../widgets/status_pill.dart';
import '../../shared/document_preview_sheet.dart';

/// "Upload documents": one card per paper, take a photo or choose one,
/// then send the application.
class UploadDocumentsView extends StatefulWidget {
  const UploadDocumentsView({super.key});

  @override
  State<UploadDocumentsView> createState() => _UploadDocumentsViewState();
}

class _UploadDocumentsViewState extends State<UploadDocumentsView> {
  DocumentType? _busyType;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    context.read<DocumentRepository>().load();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: const TextStyle(fontSize: 18))),
    );
  }

  Future<void> _capture(DocumentType type, ImageSource source) async {
    // The face photo has its own screen with tips.
    if (type == DocumentType.idPhoto) {
      context.push(Routes.idPhoto);
      return;
    }

    final compressor = context.read<ImageCompressor>();
    final documents = context.read<DocumentRepository>();

    Uint8List? bytes;
    try {
      bytes = await compressor.pickDocument(source);
    } on PlatformException {
      if (!mounted) return;
      _say(source == ImageSource.camera
          ? 'Could not open the camera. Please allow camera access in your '
          'phone settings.'
          : 'Could not open your photos. Please allow access in your phone '
          'settings.');
      return;
    }
    if (bytes == null || !mounted) return;

    // Let the user check the photo before it is sent.
    final choice = await _confirmPhoto(type, bytes);
    if (!mounted) return;
    if (choice == _PhotoChoice.retake) return _capture(type, source);
    if (choice != _PhotoChoice.send) return;

    setState(() => _busyType = type);
    final item = await documents.add(type, bytes);
    if (!mounted) return;
    setState(() => _busyType = null);
    _sayResult(type, item);
  }

  Future<void> _resend(DocumentItem item) async {
    setState(() => _busyType = item.type);
    final result = await context.read<DocumentRepository>().upload(item);
    if (!mounted) return;
    setState(() => _busyType = null);
    _sayResult(item.type, result);
  }

  void _sayResult(DocumentType type, DocumentItem item) {
    if (!item.isUploaded) {
      _say('${type.title}: saved, but not sent yet. Please check your '
          'internet and tap "Send again".');
    } else {
      _say('${type.title}: sent to the OSCA office.');
    }
  }

  Future<_PhotoChoice?> _confirmPhoto(DocumentType type, Uint8List bytes) {
    return showDialog<_PhotoChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Check the photo', style: const TextStyle(fontSize: 24)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${type.title}. Can you read all the words?',
                style: const TextStyle(fontSize: 18, height: 1.4),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.45,
                  ),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PhotoChoice.retake),
            style: TextButton.styleFrom(minimumSize: const Size(48, 52)),
            child: const Text('Take again', style: TextStyle(fontSize: 18)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(_PhotoChoice.send),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
            icon: const Icon(Icons.send_outlined),
            label: const Text(
              'Use this photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final documents = context.read<DocumentRepository>();
    final applications = context.read<ApplicationRepository>();
    final profile = context.read<UserProvider>().profile;
    final users = context.read<UserRepository>();
    setState(() => _submitting = true);
    try {
      // The OSCA office needs the name and birthday with the application.
      if (profile != null) await users.syncProfile(profile);
      final reference = await documents.submitApplication();
      await applications.markSubmitted(reference);
      if (!mounted) return;
      // Only reached with the OSCA office's own reference number.
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 56,
          ),
          title: const Text(
            'Application sent',
            style: TextStyle(fontSize: 26),
          ),
          content: Text(
            'Your reference number is $reference.\n\nWe will send you '
                'a notification when the OSCA office has checked your '
                'papers.',
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (context.canPop()) context.pop();
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } catch (_) {
      if (mounted) _say('The application was not sent. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentRepository>();
    final status = context.watch<ApplicationRepository>().status;
    final stage = status.stage;

    DocumentState stateOf(DocumentType type) => documentStateOf(
          item: documents.latestOf(type),
          review: status.reviewOf(type),
          applicationApproved: stage == ApplicationStage.approved,
          sendsToOffice: documents.sendsToOffice,
        );

    return Scaffold(
      appBar: AppTheme.appBar('Upload documents'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (stage == ApplicationStage.needsAction) ...[
            NoticeCard(
              icon: Icons.priority_high,
              color: AppColors.warning,
              title: 'The OSCA office needs corrected papers',
              text: status.message,
            ),
            const SizedBox(height: 16),
          ],
          if (!documents.sendsToOffice) ...[
            const NoticeCard.notConnected(
              text: 'This app is not connected to the OSCA office, so papers '
                  'cannot be sent. Please contact OSCA.',
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Take a clear photo of each paper. Put it on a table, in good '
                'light, and make sure all the words can be read.',
            style: TextStyle(fontSize: 18, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            '${documents.requiredDoneCount} of '
                '${DocumentRepository.requiredTypes.length} papers '
                'sent',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          for (final type in DocumentRepository.requiredTypes) ...[
            _DocumentCard(
              type: type,
              item: documents.latestOf(type),
              state: stateOf(type),
              note: status.reviewOf(type)?.note ?? '',
              busy: _busyType == type,
              onCamera: () => _capture(type, ImageSource.camera),
              onGallery: () => _capture(type, ImageSource.gallery),
              onResend: _resend,
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 10),
          if (stage.canSubmit) ...[
            BigButton(
              label: _submitting ? 'Sending...' : 'Send my application',
              icon: Icons.send_outlined,
              onPressed: (documents.hasAllRequired && !_submitting && _busyType == null)
                  ? _submit
                  : null,
            ),
            if (!documents.hasAllRequired) ...[
              const SizedBox(height: 10),
              const Text(
                'Send all the papers above first.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
              ),
            ],
          ] else
            const InfoCard(
              outlined: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your application was already sent. You can still '
                          'replace a paper if the OSCA office asks you to.',
                      style: TextStyle(
                        fontSize: 17,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentType type;
  final DocumentItem? item;
  final DocumentState state;

  /// The office's note about this paper, if any.
  final String note;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<DocumentItem> onResend;

  const _DocumentCard({
    required this.type,
    required this.item,
    required this.state,
    required this.note,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final current = item;
    final fix = state == DocumentState.needsCorrection ||
        state == DocumentState.rejected;
    return InfoCard(
      outlined: !fix,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(
                item: current,
                icon: type == DocumentType.idPhoto
                    ? Icons.face_outlined
                    : Icons.description_outlined,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.hint,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusPill(StatusLook.document(
                      busy ? DocumentState.sending : state,
                    )),
                  ],
                ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'OSCA office: $note',
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (state == DocumentState.notSent && current != null) ...[
              BigButton(
                label: 'Send again',
                icon: Icons.cloud_upload_outlined,
                onPressed: () => onResend(current),
              ),
              const SizedBox(height: 10),
            ],
            if (fix)
              Text(
                'Replace document:',
                style: OnboardingScaffold.fieldLabel,
              ),
            if (fix) const SizedBox(height: 6),
            if (type == DocumentType.idPhoto)
              _ActionButton(
                icon: Icons.photo_camera_outlined,
                label: current == null ? 'Take my photo' : 'Take a new photo',
                onPressed: onCamera,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Camera',
                      onPressed: onCamera,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onPressed: onGallery,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

enum _PhotoChoice { send, retake }

class _Thumbnail extends StatelessWidget {
  final DocumentItem? item;
  final IconData icon;

  const _Thumbnail({required this.item, required this.icon});

  @override
  Widget build(BuildContext context) {
    final current = item;
    final placeholder = Icon(icon, color: AppColors.primary, size: 36);
    return Semantics(
      button: current != null,
      label: current == null ? null : 'Open photo',
      child: GestureDetector(
        onTap: current == null
            ? null
            : () => showDocumentPreviewSheet(context, current),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 76,
            height: 76,
            color: AppColors.primaryLight,
            child: current == null
                ? placeholder
                : Image.file(
              File(current.filePath),
              fit: BoxFit.cover,
              cacheWidth: 200,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 26),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 58),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 2),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}