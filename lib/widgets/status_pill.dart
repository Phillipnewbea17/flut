import 'package:flutter/material.dart';

import '../app_state/accessibility_provider.dart';
import '../models/application_status.dart';
import '../models/document_item.dart';
import '../models/identity_verification.dart';
import '../models/pension_record.dart';
import '../models/senior_id.dart';
import '../models/service_request.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

/// How a status looks: always an icon AND words, never color alone.
class StatusLook {
  final IconData icon;
  final Color color;
  final String label;

  const StatusLook(this.icon, this.color, this.label);

  static StatusLook application(BuildContext context, ApplicationStage stage) {
    final label = context.tr(stage.labelKey);
    switch (stage) {
      case ApplicationStage.notStarted:
        return StatusLook(Icons.radio_button_unchecked, AppColors.textSecondary, label);
      case ApplicationStage.submitted:
        return StatusLook(Icons.send_outlined, AppColors.info, label);
      case ApplicationStage.review:
        return StatusLook(Icons.hourglass_top, AppColors.info, label);
      case ApplicationStage.needsAction:
        return StatusLook(Icons.priority_high, AppColors.warning, label);
      case ApplicationStage.approved:
        return StatusLook(Icons.check_circle, AppColors.success, label);
      case ApplicationStage.rejected:
        return StatusLook(Icons.cancel_outlined, AppColors.danger, label);
      case ApplicationStage.cancelled:
        return StatusLook(Icons.block, AppColors.textSecondary, label);
    }
  }

  /// Every request screen uses this, so the words are the same everywhere:
  /// Submitted, Under review, Needs action, Approved, Rejected, Cancelled.
  /// Any other word from the office is shown as it is, in a neutral chip.
  static StatusLook request(ServiceRequest request) {
    final label = request.displayLabel;
    switch (request.displayStatus) {
      case RequestDisplayStatus.notSent:
        return StatusLook(Icons.cloud_off_outlined, AppColors.danger, label);
      case RequestDisplayStatus.submitted:
        return StatusLook(Icons.send_outlined, AppColors.info, label);
      case RequestDisplayStatus.underReview:
        return StatusLook(Icons.hourglass_top, AppColors.info, label);
      case RequestDisplayStatus.needsAction:
        return StatusLook(Icons.priority_high, AppColors.warning, label);
      case RequestDisplayStatus.approved:
        return StatusLook(Icons.check_circle, AppColors.success, label);
      case RequestDisplayStatus.rejected:
        return StatusLook(Icons.cancel_outlined, AppColors.danger, label);
      case RequestDisplayStatus.cancelled:
        return StatusLook(Icons.block, AppColors.textSecondary, label);
      case RequestDisplayStatus.other:
        return StatusLook(Icons.info_outline, AppColors.textSecondary, label);
    }
  }

  static StatusLook document(DocumentState state) {
    final label = state.label;
    switch (state) {
      case DocumentState.notSubmitted:
        return StatusLook(Icons.radio_button_unchecked, AppColors.textSecondary, label);
      case DocumentState.sending:
        return StatusLook(Icons.schedule, AppColors.info, label);
      case DocumentState.notSent:
        return StatusLook(Icons.error_outline, AppColors.danger, label);
      case DocumentState.savedOnPhone:
        return StatusLook(Icons.phone_android, AppColors.textSecondary, label);
      case DocumentState.submitted:
        return StatusLook(Icons.send_outlined, AppColors.info, label);
      case DocumentState.needsCorrection:
        return StatusLook(Icons.priority_high, AppColors.warning, label);
      case DocumentState.approved:
        return StatusLook(Icons.check_circle, AppColors.success, label);
      case DocumentState.rejected:
        return StatusLook(Icons.cancel_outlined, AppColors.danger, label);
    }
  }

  static StatusLook identity(IdentityState state) {
    final label = state.label;
    switch (state) {
      case IdentityState.verified:
        return StatusLook(Icons.verified, AppColors.success, label);
      case IdentityState.pendingReview:
        return StatusLook(Icons.hourglass_top, AppColors.info, label);
      case IdentityState.unverified:
        return StatusLook(Icons.priority_high, AppColors.warning, label);
    }
  }

  /// The Senior ID status on Personal information (null for "none").
  static StatusLook? userStatus(UserApplicationStatus status) {
    final label = status.label;
    if (label == null) return null;
    return switch (status) {
      UserApplicationStatus.submitted =>
        StatusLook(Icons.send_outlined, AppColors.info, label),
      UserApplicationStatus.underReview =>
        StatusLook(Icons.hourglass_top, AppColors.info, label),
      UserApplicationStatus.needsAction =>
        StatusLook(Icons.priority_high, AppColors.warning, label),
      UserApplicationStatus.approved =>
        StatusLook(Icons.check_circle, AppColors.success, label),
      UserApplicationStatus.rejected =>
        StatusLook(Icons.cancel_outlined, AppColors.danger, label),
      UserApplicationStatus.none => null,
    };
  }

  static StatusLook correction(CorrectionRequest request) {
    if (request.localOnly) {
      return const StatusLook(
          Icons.phone_android, AppColors.textSecondary, 'Saved on this phone only');
    }
    switch (request.status) {
      case CorrectionStatus.pending:
        return const StatusLook(Icons.schedule, AppColors.info, 'Waiting for OSCA');
      case CorrectionStatus.approved:
        return const StatusLook(Icons.check_circle, AppColors.success, 'Approved');
      case CorrectionStatus.rejected:
        return const StatusLook(Icons.cancel_outlined, AppColors.danger, 'Not approved');
    }
  }

  static StatusLook seniorId(SeniorIdStatus status) {
    final label = status.label;
    switch (status) {
      case SeniorIdStatus.pendingIssuance:
        return StatusLook(Icons.hourglass_top, AppColors.info, label);
      case SeniorIdStatus.active:
        return StatusLook(Icons.verified_outlined, AppColors.success, label);
      case SeniorIdStatus.forReplacement:
        return StatusLook(Icons.autorenew, AppColors.warning, label);
      case SeniorIdStatus.inactive:
        return StatusLook(Icons.block, AppColors.danger, label);
    }
  }

  /// A pension release, in the office's words (Released, Pending, On Hold).
  static StatusLook pension(PensionRecord record) {
    final label = record.status;
    if (record.isReleased) {
      return StatusLook(Icons.check_circle, AppColors.success, label);
    }
    if (record.isOnHold) {
      return StatusLook(Icons.pause_circle_outline, AppColors.warning, label);
    }
    return StatusLook(Icons.schedule, AppColors.textSecondary, label);
  }
}

/// A rounded badge: colored icon + dark text on a light tint.
class StatusPill extends StatelessWidget {
  final StatusLook look;
  final bool large;

  const StatusPill(this.look, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: ${look.label}',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: large ? 16 : 12,
            vertical: large ? 10 : 6,
          ),
          decoration: BoxDecoration(
            color: look.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: look.color, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(look.icon, color: look.color, size: large ? 30 : 22),
              SizedBox(width: large ? 10 : 8),
              Flexible(
                child: Text(
                  look.label,
                  style: TextStyle(
                    fontSize: large ? 18 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
