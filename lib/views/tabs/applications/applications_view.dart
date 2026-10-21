import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../models/application_status.dart';
import '../../../repositories/application_repository.dart';
import '../../../repositories/requests_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/request_row.dart';
import '../../../widgets/section_title.dart';
import '../../../widgets/status_pill.dart';

/// Applications tab: the senior citizen application and every request for
/// assistance, in one place.
class ApplicationsView extends StatelessWidget {
  const ApplicationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final applications = context.watch<ApplicationRepository>();
    final requests = context.watch<RequestsRepository>();
    final active = requests.overview(active: true);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        onRefresh: () => Future.wait([applications.load(), requests.load()]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            TabHeader(
              title: context.tr('applicationsTitle'),
              subtitle: 'Your application and requests to the OSCA office.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('My application'),
                  const SizedBox(height: 12),
                  _SeniorApplicationCard(status: applications.status),
                  const SizedBox(height: 32),
                  // Medical, Burial, Documents and Complaints together.
                  SectionTitle('Active requests (${active.length})'),
                  const SizedBox(height: 12),
                  if (active.isEmpty)
                    const Text(
                      'No active requests.',
                      style: TextStyle(
                          fontSize: 18, color: AppColors.textSecondary),
                    )
                  else
                    for (final r in active.take(3)) ...[
                      RequestRow(request: r),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 14),
                  BigButton(
                    label: 'View all my requests',
                    icon: Icons.list_alt,
                    style: BigButtonStyle.tonal,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.push(Routes.requests);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeniorApplicationCard extends StatelessWidget {
  final ApplicationStatus status;

  const _SeniorApplicationCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final stage = status.stage;
    return InfoCard(
      outlined: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_ind_outlined,
                  color: AppColors.primary, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Senior Citizen application',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(StatusLook.application(context, stage)),
          ),
          if (status.applicationNo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reference: ${status.applicationNo}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
          if (status.updatedAt != null)
            Text(
              'Last update: ${DateFormat('MMMM d, y').format(status.updatedAt!)}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 14),
          if (stage.wasSent) ...[
            BigButton(
              label: 'View status',
              icon: Icons.chevron_right,
              trailingIcon: true,
              onPressed: () => context.push(Routes.applicationStatus),
            ),
            const SizedBox(height: 10),
            BigButton(
              label: status.canUpload ? 'Fix my documents' : 'My documents',
              icon: Icons.upload_file_outlined,
              style: BigButtonStyle.tonal,
              onPressed: () => context.push(Routes.upload),
            ),
          ] else
            BigButton(
              label: 'Start application',
              icon: Icons.upload_file_outlined,
              onPressed: () => context.push(Routes.upload),
            ),
        ],
      ),
    );
  }
}
