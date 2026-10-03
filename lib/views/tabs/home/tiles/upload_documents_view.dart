import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../models/application_status.dart';
import '../../../../models/document_item.dart';
import '../../../../repositories/application_repository.dart';
import '../../../../repositories/document_repository.dart';
import '../../../../routes/app_router.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/image_compressor.dart';
import '../../../../widgets/big_button.dart';
import '../../../../widgets/info_card.dart';
import '../../wallet/document_preview_sheet.dart';

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

    setState(() => _busyType = type);
    final item = await documents.add(type, bytes);
    if (!mounted) return;
    setState(() => _busyType = null);
    _say(item.isUploaded
        ? '${type.title}: sent.'
        : '${type.title}: saved, but not sent yet. Please check your '
        'internet and tap "Send again".');
  }

  Future<void> _submit() async {
    final documents = context.read<DocumentRepository>();
    final applications = context.read<ApplicationRepository>();
    setState(() => _submitting = true);
    try {
      final reference = await documents.submitApplication();
      await applications.markSubmitted(reference);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
          title: const Text('Application sent', style: TextStyle(fontSize: 26)),
          content: Text(
            'Your reference number is $reference.\n\nWe will send you a '
                'notification when the OSCA office has checked your papers.',
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
    } catch (_) {
      if (mounted) _say('The application was not sent. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentRepository>();
    final stage = context.watch<ApplicationRepository>().status.stage;
    final others = documents.documents
        .where((d) => d.type == DocumentType.other)
        .toList();

    return Scaffold(
      appBar: AppTheme.appBar('Upload documents'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Text(
            'Take a clear photo of each paper. Put it on a table, in good '
                'light, and make sure all the words can be read.',
            style: TextStyle(fontSize: 18, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            '${documents.requiredDoneCount} of '
                '${DocumentRepository.requiredTypes.length} papers sent',
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
              busy: _busyType == type,
              onCamera: () => _capture(type, ImageSource.camera),
              onGallery: () => _capture(type, ImageSource.gallery),
            ),
            const SizedBox(height: 14),
          ],
          _OtherPapersCard(
            items: others,
            busy: _busyType == DocumentType.other,
            onCamera: () => _capture(DocumentType.other, ImageSource.camera),
            onGallery: () => _capture(DocumentType.other, ImageSource.gallery),
          ),
          const SizedBox(height: 24),
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
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _DocumentCard({
    required this.type,
    required this.item,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final current = item;
    return InfoCard(
      outlined: true,
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
                    _StatusChip(item: current, busy: busy),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (busy)
            const Center(child: CircularProgressIndicator())
          else if (type == DocumentType.idPhoto)
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
      ),
    );
  }
}

class _OtherPapersCard extends StatelessWidget {
  final List<DocumentItem> items;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _OtherPapersCard({
    required this.items,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      outlined: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${DocumentType.other.title} (if asked)',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DocumentType.other.hint,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  _Thumbnail(item: item, icon: Icons.description_outlined),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (busy)
            const Center(child: CircularProgressIndicator())
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
      ),
    );
  }
}

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

class _StatusChip extends StatelessWidget {
  final DocumentItem? item;
  final bool busy;

  const _StatusChip({required this.item, required this.busy});

  @override
  Widget build(BuildContext context) {
    final current = item;
    final String text;
    final Color color;
    final IconData icon;
    if (busy || current?.status == DocumentStatus.uploading) {
      text = 'Sending...';
      color = AppColors.warning;
      icon = Icons.schedule;
    } else if (current == null) {
      text = 'Needed';
      color = AppColors.textSecondary;
      icon = Icons.radio_button_unchecked;
    } else if (current.isUploaded) {
      text = 'Sent';
      color = AppColors.success;
      icon = Icons.check_circle;
    } else {
      text = 'Not sent. Tap the photo to send again.';
      color = AppColors.danger;
      icon = Icons.error_outline;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
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