import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/service_request.dart';
import '../../../repositories/requests_repository.dart';
import '../../../repositories/wallet_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/menu_group.dart';
import '../../../widgets/request_summary_card.dart';
import '../../../widgets/section_title.dart';

/// "ID services" (Home quick action): everything about the Senior ID.
/// Issuing, activating and deactivating IDs stay in the web app.
class IdServicesView extends StatelessWidget {
  const IdServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletRepository>();
    final replacement = context
        .watch<RequestsRepository>()
        .latestActive(RequestKind.idReplacement);

    return Scaffold(
      appBar: AppTheme.appBar('ID services'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (!wallet.hasSeniorId) ...[
            const NoticeCard(
              icon: Icons.hourglass_top,
              text: 'You do not have a Senior Citizen ID yet. It will '
                  'appear here when your application is approved.',
            ),
            const SizedBox(height: 20),
          ],
          MenuGroup(
            items: [
              MenuItem(
                icon: Icons.badge_outlined,
                label: 'Digital Senior ID',
                subtitle: 'See your ID card',
                // My ID is a tab, so switch to it instead of opening a copy.
                onTap: () => context.go(Routes.myId),
              ),
              MenuItem(
                icon: Icons.qr_code_2,
                label: 'QR code',
                subtitle: 'Show to the cashier or the office',
                onTap: () => context.push(Routes.qrCashier),
              ),
              MenuItem(
                icon: Icons.list_alt_outlined,
                label: 'ID details',
                subtitle: 'Your ID number and information',
                onTap: () => context.push(Routes.idDetails),
              ),
              MenuItem(
                icon: Icons.autorenew,
                label: 'ID replacement',
                subtitle: 'Lost, damaged or wrong details',
                onTap: () => context.push(Routes.idReplacement),
              ),
            ],
          ),
          if (replacement != null) ...[
            const SizedBox(height: 8),
            const SectionTitle('Your replacement request', fontSize: 22),
            const SizedBox(height: 12),
            RequestSummaryCard(request: replacement),
          ],
          const SizedBox(height: 16),
          const Text(
            'The OSCA office issues and manages all Senior Citizen IDs.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
