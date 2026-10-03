import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../models/application_status.dart';
import '../../../models/document_item.dart';
import '../../../repositories/application_repository.dart';
import '../../../repositories/document_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/status_stepper.dart';

/// "View progress": full status, what happened so far, and the papers.
class ApplicationProgressView extends StatelessWidget {
  const ApplicationProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final applications = context.watch<ApplicationRepository>();
    final documents = context.watch<DocumentRepository>();
    final status = applications.status;
    final dateFormat = DateFormat('MMM d, y  h:mm a');

    return Scaffold(
      appBar: AppTheme.appBar('Application progress'),
      body: RefreshIndicator(
        onRefresh: applications.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(status.stage.labelKey),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (status.applicationNo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SelectableText(
                      'Reference no. ${status.applicationNo}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  StatusStepper(stage: status.stage),
                  const SizedBox(height: 18),
                  Text(
                    status.message,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (status.updatedAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Last update: ${dateFormat.format(status.updatedAt!)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (applications.error != null) ...[
              const SizedBox(height: 12),
              Text(
                applications.error!,
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 28),
            const _Heading('What happened so far'),
            const SizedBox(height: 12),
            if (status.history.isEmpty)
              const Text(
                'Nothing yet. Send your papers to start.',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
              )
            else
              ...status.history.reversed.map(
                    (event) => _HistoryTile(event: event, dateFormat: dateFormat),
              ),
            const SizedBox(height: 28),
            _Heading(
              'Your papers (${documents.requiredDoneCount} of '
                  '${DocumentRepository.requiredTypes.length} sent)',
            ),
            const SizedBox(height: 12),
            for (final type in DocumentRepository.requiredTypes)
              _PaperRow(type: type, item: documents.latestOf(type)),
            const SizedBox(height: 20),
            BigButton(
              label: 'Upload documents',
              icon: Icons.upload_file_outlined,
              onPressed: () => context.push(Routes.upload),
            ),
            if (status.stage == ApplicationStage.submitted) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmCancel(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(48, 52),
                  ),
                  icon: const Icon(Icons.undo),
                  label: const Text(
                    'Cancel my application',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Text(
                'You can cancel only before the OSCA office starts checking it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmCancel(BuildContext context) async {
  final applications = context.read<ApplicationRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(
        'Cancel your application?',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'The OSCA office will not check it. You can send it again later '
            'from Upload documents.',
        style: TextStyle(fontSize: 18, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep it', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Cancel application',
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
  await applications.cancelApplication();
  messenger.showSnackBar(
    const SnackBar(
      content: Text(
        'Your application was cancelled.',
        style: TextStyle(fontSize: 18),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final StatusEvent event;
  final DateFormat dateFormat;

  const _HistoryTile({required this.event, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(event.stage.labelKey),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  event.note,
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                Text(
                  dateFormat.format(event.date),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
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

class _PaperRow extends StatelessWidget {
  final DocumentType type;
  final DocumentItem? item;

  const _PaperRow({required this.type, required this.item});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String state;
    if (item == null) {
      icon = Icons.radio_button_unchecked;
      color = AppColors.textSecondary;
      state = 'Not yet sent';
    } else if (item!.isUploaded) {
      icon = Icons.check_circle;
      color = AppColors.success;
      state = 'Sent';
    } else if (item!.status == DocumentStatus.failed) {
      icon = Icons.error_outline;
      color = AppColors.danger;
      state = 'Not sent. Open Upload documents to try again.';
    } else {
      icon = Icons.schedule;
      color = AppColors.warning;
      state = 'Sending...';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  state,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
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