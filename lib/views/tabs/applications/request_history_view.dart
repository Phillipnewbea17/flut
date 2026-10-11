import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/service_request.dart';
import '../../../repositories/requests_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/request_row.dart';

/// "My requests": every request the senior made (Medical, Burial,
/// Documents, Complaints), in Active and Completed tabs, newest first.
/// The Medical and Burial screens still list their own requests.
class RequestHistoryView extends StatefulWidget {
  const RequestHistoryView({super.key});

  @override
  State<RequestHistoryView> createState() => _RequestHistoryViewState();
}

class _RequestHistoryViewState extends State<RequestHistoryView> {
  /// Null = All.
  RequestCategory? _category;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppTheme.appBar(
          'My requests',
          bottom: TabBar(
            onTap: (_) => HapticFeedback.selectionClick(),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(height: 52, text: 'Active'),
              Tab(height: 52, text: 'Completed'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryChips(
              selected: _category,
              onSelected: (c) => setState(() => _category = c),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _RequestList(
                    active: true,
                    category: _category,
                    emptyText: 'No active requests.',
                  ),
                  _RequestList(
                    active: false,
                    category: _category,
                    emptyText: 'No completed requests yet. Finished requests '
                        'will appear here.',
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

/// All, Medical, Burial, Documents, Complaints.
class _CategoryChips extends StatelessWidget {
  final RequestCategory? selected;
  final ValueChanged<RequestCategory?> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, RequestCategory? value) {
      final isSelected = value == selected;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onSelected(value);
          },
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          labelStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 6),
      child: Row(
        children: [
          chip('All', null),
          for (final c in RequestCategory.values) chip(c.label, c),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final bool active;
  final RequestCategory? category;
  final String emptyText;

  const _RequestList({
    required this.active,
    required this.category,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RequestsRepository>();
    final items = repo.overview(active: active, category: category);

    return RefreshIndicator(
      onRefresh: repo.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (repo.error != null) ...[
            Text(
              repo.error!,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, color: AppColors.textSecondary, height: 1.4),
              ),
            )
          else
            for (final r in items) ...[
              RequestRow(request: r, showReference: true),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
