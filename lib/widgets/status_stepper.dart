import 'package:flutter/material.dart';

import '../app_state/accessibility_provider.dart';
import '../models/application_status.dart';
import '../theme/app_colors.dart';

enum _StepState { upcoming, done, current, warning, failed }

/// Submitted -> Under review -> Approved, with an extra "Action needed" step
/// only while the OSCA office is waiting for corrected papers.
///
///   Not started   ( )----( )----( )
///   Submitted     (✓)----( )----( )         papers sent, waiting
///   Under review  (✓)====(•)----( )         the OSCA office is checking
///   Action needed (✓)====(✓)====(!)----( )  the office needs new papers
///   Approved      (✓)====(✓)====(✓)
///   Not approved  (✓)====(✓)====(✗)
class StatusStepper extends StatelessWidget {
  final ApplicationStage stage;

  const StatusStepper({super.key, required this.stage});

  List<(String, _StepState)> _steps(BuildContext context) {
    final submitted = context.tr('stepSubmitted');
    final review = context.tr('stepReview');
    final approved = context.tr('stepApproved');
    const up = _StepState.upcoming;
    const done = _StepState.done;
    switch (stage) {
      case ApplicationStage.notStarted:
      case ApplicationStage.cancelled:
        return [(submitted, up), (review, up), (approved, up)];
      case ApplicationStage.submitted:
        return [(submitted, done), (review, up), (approved, up)];
      case ApplicationStage.review:
        return [(submitted, done), (review, _StepState.current), (approved, up)];
      case ApplicationStage.needsAction:
        return [
          (submitted, done),
          (review, done),
          (context.tr('stepNeedsAction'), _StepState.warning),
          (approved, up),
        ];
      case ApplicationStage.approved:
        return [(submitted, done), (review, done), (approved, done)];
      case ApplicationStage.rejected:
        return [
          (submitted, done),
          (review, done),
          (context.tr('stepNotApproved'), _StepState.failed),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps(context);
    bool reached(int i) => steps[i].$2 != _StepState.upcoming;

    return Semantics(
      label: 'Application progress: ${context.tr(stage.labelKey)}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(steps.length, (i) {
            final (label, state) = steps[i];
            return Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      // Line coming in from the previous step.
                      Expanded(
                        child: i == 0
                            ? const SizedBox.shrink()
                            : _Line(active: reached(i)),
                      ),
                      _Node(state: state),
                      // Line going out to the next step.
                      Expanded(
                        child: i == steps.length - 1
                            ? const SizedBox.shrink()
                            : _Line(active: reached(i + 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // One line; shrinks a little on small screens instead of
                  // breaking a word in two.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            reached(i) ? FontWeight.w700 : FontWeight.w400,
                        color: reached(i)
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
  final _StepState state;

  const _Node({required this.state});

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      // Finished: green circle with a check mark.
      case _StepState.done:
        return _filled(AppColors.primary, Icons.check);
      // Not approved: red circle with a cross.
      case _StepState.failed:
        return _filled(AppColors.danger, Icons.close);
      // In progress: white circle with a ring and a dot, or "!" when the
      // office needs something from the user.
      case _StepState.current:
      case _StepState.warning:
        final warning = state == _StepState.warning;
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
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
        );
      // Not reached yet: empty grey circle.
      case _StepState.upcoming:
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

  Widget _filled(Color color, IconData icon) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }
}
