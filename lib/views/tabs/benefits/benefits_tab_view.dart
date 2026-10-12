import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../models/pension_record.dart';
import '../../../models/purchase_booklet.dart' show formatPeso;
import '../../../routes/app_router.dart';
import '../../../services/pension_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/menu_group.dart';
import '../../../widgets/section_title.dart';

/// Benefits tab: the senior's own pension, then the discount calculator and
/// a way to report a store.
class BenefitsTabView extends StatefulWidget {
  const BenefitsTabView({super.key});

  @override
  State<BenefitsTabView> createState() => _BenefitsTabViewState();
}

class _BenefitsTabViewState extends State<BenefitsTabView> {
  late Future<List<PensionRecord>> _pension;

  @override
  void initState() {
    super.initState();
    _pension = context.read<PensionService>().fetchMine();
  }

  Future<void> _refresh() async {
    setState(() => _pension = context.read<PensionService>().fetchMine());
    await _pension.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final pensionService = context.read<PensionService>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            TabHeader(
              title: context.tr('benefitsTitle'),
              subtitle: 'Your pension, discounts and services for seniors.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('My pension'),
                  const SizedBox(height: 12),
                  if (pensionService.isAvailable)
                    _MyPension(future: _pension)
                  else
                    const NoticeCard(
                      icon: Icons.info_outline,
                      text: 'Your own pension release records are not in the '
                          'app yet. The OSCA office keeps them. Ask the OSCA '
                          'office about your pension.',
                    ),
                  const SizedBox(height: 28),
                  MenuGroup(
                    title: 'Benefits and services',
                    items: [
                      MenuItem(
                        icon: Icons.calculate_outlined,
                        label: 'Discount calculator',
                        subtitle: 'How much you should pay',
                        onTap: () => context.push(Routes.calculator),
                      ),
                    ],
                  ),
                  MenuGroup(
                    title: 'Problems with a benefit?',
                    items: [
                      MenuItem(
                        icon: Icons.storefront_outlined,
                        label: 'Report a store',
                        subtitle: 'A store refused your discount',
                        onTap: () => context.push(Routes.reportViolation),
                      ),
                    ],
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

/// The signed-in senior's own pension releases (newest first).
class _MyPension extends StatelessWidget {
  final Future<List<PensionRecord>> future;

  const _MyPension({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PensionRecord>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text(
            'Could not load your pension. Pull down to try again.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          );
        }
        final records = snapshot.data ?? const <PensionRecord>[];
        if (records.isEmpty) {
          return const Text(
            'No pension releases on record yet.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          );
        }
        final latest = records.first;
        final earlier = records.skip(1).toList();
        final date = DateFormat('MMMM d, y');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoCard(
              outlined: true,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field('Period', latest.period),
                  Row(
                    children: [
                      Icon(
                        latest.isReleased ? Icons.check_circle : Icons.schedule,
                        color:
                            latest.isReleased ? AppColors.success : AppColors.info,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _Field('Status', latest.status)),
                    ],
                  ),
                  // Set once the office releases it out of a fund.
                  if (latest.amount != null)
                    _Field('Amount', formatPeso(latest.amount!)),
                  if (latest.releaseDate != null)
                    _Field('Release date', date.format(latest.releaseDate!)),
                  if (latest.receivedBy.isNotEmpty)
                    _Field('Received by', latest.receivedBy),
                  if (latest.reference.isNotEmpty)
                    _Field('Reference', latest.reference),
                ],
              ),
            ),
            if (earlier.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionTitle('Earlier releases'),
              const SizedBox(height: 12),
              for (final record in earlier)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoCard(
                    outlined: true,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          record.isReleased
                              ? Icons.check_circle_outline
                              : Icons.schedule,
                          color: record.isReleased
                              ? AppColors.success
                              : AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.period,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                [
                                  record.status,
                                  if (record.amount != null)
                                    formatPeso(record.amount!),
                                  if (record.releaseDate != null)
                                    date.format(record.releaseDate!),
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
