import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../app_state/user_provider.dart';
import '../../../models/service_request.dart';
import '../../../repositories/requests_repository.dart';
import '../../../repositories/wallet_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/request_summary_card.dart';
import '../../../widgets/section_title.dart';
import '../../../widgets/senior_id_card.dart';

/// My ID tab: the official Senior Citizen ID from the OSCA office.
class MyIdView extends StatelessWidget {
  const MyIdView({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletRepository>();
    final requests = context.watch<RequestsRepository>();
    final user = context.watch<UserProvider>();
    final replacement = requests.latestActive(RequestKind.idReplacement);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        onRefresh: () => Future.wait([wallet.load(), requests.load()]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            TabHeader(
              title: context.tr('myIdTitle'),
              subtitle: 'Your official ID from the OSCA office.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SeniorIdCard(
                seniorId: wallet.seniorId,
                fallbackName: user.profile?.fullName ?? '',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wallet.hasSeniorId) ...[
                    BigButton(
                      label: 'Show QR',
                      icon: Icons.qr_code_2,
                      onPressed: () => context.push(Routes.qrCashier),
                    ),
                    const SizedBox(height: 12),
                    BigButton(
                      label: 'View ID details',
                      icon: Icons.badge_outlined,
                      style: BigButtonStyle.tonal,
                      onPressed: () => context.push(Routes.idDetails),
                    ),
                    const SizedBox(height: 12),
                    BigButton(
                      label: 'Request replacement',
                      icon: Icons.autorenew,
                      style: BigButtonStyle.tonal,
                      onPressed: () => context.push(Routes.idReplacement),
                    ),
                  ] else
                    BigButton(
                      label: 'Check my application',
                      icon: Icons.assignment_outlined,
                      style: BigButtonStyle.tonal,
                      onPressed: () => context.push(Routes.applicationStatus),
                    ),
                  if (replacement != null) ...[
                    const SizedBox(height: 28),
                    const _Heading('ID replacement request'),
                    const SizedBox(height: 12),
                    RequestSummaryCard(request: replacement),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
