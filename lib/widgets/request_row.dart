import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/service_request.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import 'info_card.dart';
import 'status_pill.dart';

/// One request in a compact list: category icon, title, (reference), status
/// chip and date. The whole row opens the request's details.
class RequestRow extends StatelessWidget {
  final ServiceRequest request;

  /// Shows "Ref: MED-2026-0001" (My requests).
  final bool showReference;

  const RequestRow({
    super.key,
    required this.request,
    this.showReference = false,
  });

  static final DateFormat _shortDate = DateFormat('MMM d, y');
  static final DateFormat _spokenDate = DateFormat('MMMM d');

  @override
  Widget build(BuildContext context) {
    final r = request;
    final category = r.category;
    final reference = r.reference.isEmpty ? 'No reference yet' : 'Ref: ${r.reference}';

    return Semantics(
      button: true,
      // "Hospital assistance, Submitted, October 6"
      label: '${r.title}, ${r.displayLabel}, ${_spokenDate.format(r.sortDate)}',
      excludeSemantics: true,
      child: InfoCard(
        outlined: true,
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(Routes.request(r.id));
        },
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (showReference) ...[
                    const SizedBox(height: 2),
                    Text(
                      reference,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(StatusLook.request(r)),
                      Text(
                        _shortDate.format(r.sortDate),
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 26),
          ],
        ),
      ),
    );
  }
}
