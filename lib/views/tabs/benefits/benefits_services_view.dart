import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/benefit.dart';
import '../../../routes/app_router.dart';
import '../../../services/benefits_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';

/// "Benefits & services": what seniors can get, and how.
class BenefitsServicesView extends StatefulWidget {
  /// Category shown first (e.g. pension). Null = all.
  final BenefitCategory? initialFilter;

  const BenefitsServicesView({super.key, this.initialFilter});

  @override
  State<BenefitsServicesView> createState() => _BenefitsServicesViewState();
}

class _BenefitsServicesViewState extends State<BenefitsServicesView> {
  late Future<List<Benefit>> _future;
  BenefitCategory? _filter; // null = all

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _future = context.read<BenefitsService>().fetchBenefits();
  }

  void _reload() {
    setState(() {
      _future = context.read<BenefitsService>().fetchBenefits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Benefits & services'),
      body: FutureBuilder<List<Benefit>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Could not load the list. Please check your internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  BigButton(label: 'Try again', icon: Icons.refresh, onPressed: _reload),
                ],
              ),
            );
          }
          final all = snapshot.data ?? const <Benefit>[];
          final shown = _filter == null
              ? all
              : all.where((b) => b.category == _filter).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final c in BenefitCategory.values)
                    _FilterChip(
                      label: c.label,
                      selected: _filter == c,
                      onTap: () => setState(() => _filter = c),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              for (final benefit in shown) ...[
                _BenefitCard(benefit: benefit),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              InfoCard(
                outlined: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Were you refused a discount?',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tell the OSCA office. They can follow it up for you.',
                      style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    BigButton(
                      label: 'Report a store',
                      icon: Icons.report_outlined,
                      style: BigButtonStyle.tonal,
                      onPressed: () => context.push(Routes.reportViolation),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rules and amounts can change. Ask your OSCA office to be sure.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppColors.primary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onSelected: (_) => onTap(),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final Benefit benefit;

  const _BenefitCard({required this.benefit});

  IconData get _icon {
    switch (benefit.category) {
      case BenefitCategory.discount:
        return Icons.sell_outlined;
      case BenefitCategory.health:
        return Icons.health_and_safety_outlined;
      case BenefitCategory.pension:
        return Icons.payments_outlined;
      case BenefitCategory.assistance:
        return Icons.volunteer_activism_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_icon, color: AppColors.primary, size: 28),
        ),
        title: Text(
          benefit.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            benefit.summary,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            benefit.details,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          if (benefit.howToGet.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'How to get it',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < benefit.howToGet.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}.',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit.howToGet[i],
                        style: const TextStyle(
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
        ],
      ),
    );
  }
}
