import 'package:flutter/material.dart';

import '../app_state/accessibility_provider.dart';
import '../models/application_status.dart';
import '../theme/app_colors.dart';

/// Submitted -> Review -> Approved.
///
/// What each status looks like:
///   Not started   ( )----( )----( )   nothing sent yet
///   Submitted     (✓)----( )----( )   papers sent, waiting for the OSCA office
///   Under review  (✓)====(•)----( )   the OSCA office is checking
///   Action needed (✓)====(!)----( )   the OSCA office needs something from you
///   Approved      (✓)====(✓)====(✓)   done
class StatusStepper extends StatelessWidget {
  final ApplicationStage stage;

  const StatusStepper({super.key, required this.stage});

  /// A finished step (green circle with a check mark).
  bool _isDone(int index) {
    switch (stage) {
      case ApplicationStage.notStarted:
        return false;
      case ApplicationStage.submitted:
      case ApplicationStage.review:
      case ApplicationStage.needsAction:
        return index == 0;
      case ApplicationStage.approved:
        return true;
    }
  }

  /// The step the OSCA office is working on right now (ring with a dot).
  bool _isCurrent(int index) {
    switch (stage) {
      case ApplicationStage.review:
      case ApplicationStage.needsAction:
        return index == 1;
      case ApplicationStage.notStarted:
      case ApplicationStage.submitted:
      case ApplicationStage.approved:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr('stepSubmitted'),
      context.tr('stepReview'),
      context.tr('stepApproved'),
    ];

    return Semantics(
      label: 'Application progress: ${context.tr(stage.labelKey)}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (i) {
            final done = _isDone(i);
            final current = _isCurrent(i);
            final highlighted = done || current;

            return Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      // Line coming in from the previous step.
                      Expanded(
                        child: i == 0
                            ? const SizedBox.shrink()
                            : _Line(active: highlighted),
                      ),
                      _Node(
                        done: done,
                        current: current,
                        warning: current &&
                            stage == ApplicationStage.needsAction,
                      ),
                      // Line going out to the next step.
                      Expanded(
                        child: i == labels.length - 1
                            ? const SizedBox.shrink()
                            : _Line(
                          active: _isDone(i + 1) || _isCurrent(i + 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // One line; shrinks a little on small screens instead of
                  // breaking a word in two.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                        highlighted ? FontWeight.w700 : FontWeight.w400,
                        color: highlighted
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final bool active;

  const _Line({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      color: active ? AppColors.primary : AppColors.primaryMuted,
    );
  }
}

class _Node extends StatelessWidget {
  final bool done;
  final bool current;
  final bool warning;

  const _Node({
    required this.done,
    required this.current,
    required this.warning,
  });

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    // Finished: green circle with a check mark.
    if (done) {
      return Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 26),
      );
    }

    // In progress: white circle with a ring and a dot (or "!" if action
    // is needed).
    if (current) {
      final color = warning ? AppColors.warning : AppColors.primary;
      return Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 4),
          boxShadow: const [
            BoxShadow(color: AppColors.primaryLight, spreadRadius: 4),
          ],
        ),
        child: warning
            ? Icon(Icons.priority_high, color: color, size: 24)
            : Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    // Not reached yet: empty grey circle.
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryMuted, width: 3),
      ),
    );
  }
}