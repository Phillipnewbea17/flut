import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/service_request.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import 'big_button.dart';
import 'info_card.dart';
import 'status_pill.dart';

/// One request in a list: what it is, its status, dates and "View details".
class RequestSummaryCard extends StatelessWidget {
  final ServiceRequest request;

  /// Shows the kind ("Medical assistance") above the title (history list).
  final bool showKind;

  const RequestSummaryCard({
    super.key,
    required this.request,
    this.showKind = false,
  });

  static final DateFormat _date = DateFormat('MMMM d, y');

  @override
  Widget build(BuildContext context) {
    final r = request;
    return InfoCard(
      outlined: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showKind)
            Text(
              r.kind.title,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          Text(
            r.title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.reference.isEmpty ? 'No reference yet' : 'Reference: ${r.reference}',
            style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(StatusLook.request(r)),
          ),
          const SizedBox(height: 12),
          _DateLine(
            label: r.isSent ? 'Submitted' : 'Saved',
            date: _date.format(r.submittedAt ?? r.createdAt),
          ),
          if (r.updatedAt != null)
            _DateLine(label: 'Last update', date: _date.format(r.updatedAt!)),
          const SizedBox(height: 14),
          BigButton(
            label: 'View details',
            icon: Icons.chevron_right,
            trailingIcon: true,
            style: BigButtonStyle.tonal,
            onPressed: () => context.push(Routes.request(r.id)),
          ),
        ],
      ),
    );
  }
}

class _DateLine extends StatelessWidget {
  final String label;
  final String date;

  const _DateLine({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          TextSpan(
            text: date,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 17),
    );
  }
}
