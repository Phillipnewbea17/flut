import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/service_request.dart';
import '../../../repositories/requests_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/request_summary_card.dart';
import '../../../widgets/section_title.dart';

/// Landing page for Medical assistance, Burial assistance and
/// Help & complaints: start a new request, then current and previous ones.
class RequestsHubView extends StatelessWidget {
  final RequestKind kind;

  const RequestsHubView({super.key, required this.kind});

  String get _intro {
    switch (kind) {
      case RequestKind.medical:
        return 'The OSCA office can help with medicine, check-ups, '
            'laboratory tests and hospital bills.';
      case RequestKind.burial:
        return 'Family members can ask for burial assistance when a senior '
            'citizen passes away.';
      case RequestKind.help:
        return 'Tell the OSCA office about a problem, a complaint or a '
            'question. They will answer you here.';
      case RequestKind.idReplacement:
        return 'Ask for a new Senior Citizen ID card.';
    }
  }

  String get _newLabel {
    switch (kind) {
      case RequestKind.medical:
        return 'Request medical assistance';
      case RequestKind.burial:
        return 'Request burial assistance';
      case RequestKind.help:
        return 'Send a concern';
      case RequestKind.idReplacement:
        return 'Request a new ID';
    }
  }

  String get _newRoute {
    switch (kind) {
      case RequestKind.medical:
        return Routes.medicalNew;
      case RequestKind.burial:
        return Routes.burialNew;
      case RequestKind.help:
        return Routes.helpNew;
      case RequestKind.idReplacement:
        return Routes.idReplacement;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RequestsRepository>();
    final current = repo.current(kind);
    final previous = repo.previous(kind);

    return Scaffold(
      appBar: AppTheme.appBar(kind.title),
      body: RefreshIndicator(
        onRefresh: repo.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              _intro,
              style: const TextStyle(
                fontSize: 19,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: _newLabel,
              icon: Icons.add,
              onPressed: () => context.push(_newRoute),
            ),
            if (!repo.isAvailable(kind)) ...[
              const SizedBox(height: 16),
              NoticeCard.notConnected(
                text: 'You can fill in a request here, but the app cannot '
                    'send ${kind.title.toLowerCase()} requests to the OSCA '
                    'office yet. It will be saved on this phone only. To get '
                    'help now, please visit or call the OSCA office.',
              ),
            ],
            if (repo.error != null) ...[
              const SizedBox(height: 12),
              Text(
                repo.error!,
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 28),
            const SectionTitle('Current requests', fontSize: 22),
            const SizedBox(height: 12),
            if (current.isEmpty)
              const Text(
                'No active request.',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
              )
            else
              for (final r in current) ...[
                RequestSummaryCard(request: r),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 24),
            const SectionTitle('Completed requests', fontSize: 22),
            const SizedBox(height: 12),
            if (previous.isEmpty)
              const Text(
                'None yet.',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
              )
            else
              for (final r in previous) ...[
                RequestSummaryCard(request: r),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}
