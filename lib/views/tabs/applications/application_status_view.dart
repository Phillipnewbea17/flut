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
import '../../../widgets/section_title.dart';
import '../../../widgets/status_pill.dart';
import '../../../widgets/status_stepper.dart';

/// Application Status: the full picture of the Senior Citizen ID
/// application. Home only shows a summary and links here.
class ApplicationStatusView extends StatelessWidget {
  const ApplicationStatusView({super.key});

  @override
  Widget build(BuildContext context) {
    final applications = context.watch<ApplicationRepository>();
    final documents = context.watch<DocumentRepository>();
    final status = applications.status;
    final stage = status.stage;
    final dateFormat = DateFormat('MMMM d, y, h:mm a');

    final states = {
      for (final type in DocumentRepository.requiredTypes)
        type: documentStateOf(
          item: documents.latestOf(type),
          review: status.reviewOf(type),
          applicationApproved: stage == ApplicationStage.approved,
          sendsToOffice: documents.sendsToOffice,
        ),
    };
    final toFix = states.entries
        .where((e) =>
            e.value == DocumentState.needsCorrection ||
            e.value == DocumentState.rejected)
        .map((e) => e.key)
        .toList();

    return Scaffold(
      appBar: AppTheme.appBar('Application status'),
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
                  if (status.applicationNo.isNotEmpty) ...[
                    SelectableText(
                      'Application #${status.applicationNo}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  StatusStepper(stage: stage),
                  const SizedBox(height: 24),
                  const Text(
                    'Current status',
                    style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  StatusPill(StatusLook.application(context, stage), large: true),
                  const SizedBox(height: 18),
                  const Text(
                    'Message',
                    style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.message,
                    style: const TextStyle(
                      fontSize: 19,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (status.updatedAt != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Last update: ${dateFormat.format(status.updatedAt!)}',
                      style: const TextStyle(
                        fontSize: 17,
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
            if (stage == ApplicationStage.needsAction) ...[
              const SizedBox(height: 20),
              NoticeCard(
                icon: Icons.priority_high,
                color: AppColors.warning,
                title: 'What you need to do',
                text: toFix.isEmpty
                    ? 'Read the message from the OSCA office above, then send '
                        'new photos of the papers they asked for.'
                    : 'Send a new photo of: '
                        '${toFix.map((t) => t.title).join(', ')}.',
              ),
            ],
            const SizedBox(height: 28),
            const SectionTitle('What happened so far', fontSize: 22),
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
            SectionTitle(
              'Your documents (${documents.requiredDoneCount} of '
              '${DocumentRepository.requiredTypes.length} sent)',
              fontSize: 22,
            ),
            const SizedBox(height: 12),
            for (final type in DocumentRepository.requiredTypes)
              _PaperRow(
                type: type,
                state: states[type]!,
                note: status.reviewOf(type)?.note ?? '',
              ),
            const SizedBox(height: 20),
            BigButton(
              label: stage == ApplicationStage.needsAction ||
                      stage == ApplicationStage.rejected
                  ? 'Upload / resubmit documents'
                  : 'Upload documents',
              icon: Icons.upload_file_outlined,
              style: stage.canSubmit
                  ? BigButtonStyle.filled
                  : BigButtonStyle.tonal,
              onPressed: () => context.push(Routes.upload),
            ),
          ],
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
    final look = StatusLook.application(context, event.stage);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(look.icon, color: look.color, size: 28),
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
  final DocumentState state;

  /// The office's note about this paper, if any.
  final String note;

  const _PaperRow({required this.type, required this.state, this.note = ''});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        outlined: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type.title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            StatusPill(StatusLook.document(state)),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
