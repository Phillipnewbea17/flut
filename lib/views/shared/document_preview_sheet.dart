import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/document_item.dart';
import '../../repositories/document_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/image_compressor.dart';
import '../../widgets/big_button.dart';

/// Opens a saved paper full size, with "Send again" and "Delete".
Future<void> showDocumentPreviewSheet(BuildContext context, DocumentItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => DocumentPreviewSheet(item: item),
  );
}

class DocumentPreviewSheet extends StatefulWidget {
  final DocumentItem item;

  const DocumentPreviewSheet({super.key, required this.item});

  @override
  State<DocumentPreviewSheet> createState() => _DocumentPreviewSheetState();
}

class _DocumentPreviewSheetState extends State<DocumentPreviewSheet> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    final result = await context.read<DocumentRepository>().upload(widget.item);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isUploaded
              ? '${_statusText(result.status)}.'
              : 'Still not sent. Please check your internet.',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
    if (result.isUploaded) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this photo?', style: TextStyle(fontSize: 24)),
        content: const Text(
          'It will be removed from this phone. You can take a new photo later.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await context.read<DocumentRepository>().remove(widget.item);
    navigator.pop();
  }

  String _statusText(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.saved:
        return 'Saved on this phone';
      case DocumentStatus.uploading:
        return 'Sending...';
      case DocumentStatus.uploaded:
        return context.read<DocumentRepository>().sendsToOffice
            ? 'Sent to the OSCA office'
            : 'Not sent: not connected to the OSCA office';
      case DocumentStatus.failed:
        return 'Not sent yet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final height = MediaQuery.sizeOf(context).height;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.type.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: AppColors.background,
              constraints: BoxConstraints(maxHeight: height * 0.5),
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.file(
                  File(item.filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image_outlined,
                        size: 64, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pinch to zoom.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'Status', value: _statusText(item.status)),
          _InfoRow(
            label: 'Added',
            value: DateFormat('MMM d, y  h:mm a').format(item.addedAt),
          ),
          _InfoRow(
            label: 'Size',
            value: ImageCompressor.describeSize(item.sizeBytes),
          ),
          const SizedBox(height: 20),
          if (item.status == DocumentStatus.failed ||
              item.status == DocumentStatus.saved) ...[
            BigButton(
              label: 'Send again',
              icon: Icons.cloud_upload_outlined,
              onPressed: _busy ? null : _retry,
            ),
            const SizedBox(height: 12),
          ],
          BigButton(
            label: 'Delete photo',
            icon: Icons.delete_outline,
            style: BigButtonStyle.tonal,
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
