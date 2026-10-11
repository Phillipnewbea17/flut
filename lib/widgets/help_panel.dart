import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'big_button.dart';

/// One button under a [HelpPanel].
class HelpAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  const HelpAction(this.label, this.icon, this.onPressed, {this.primary = false});
}

/// A big message with a way forward: used when scanning, reading an ID or
/// verifying does not work. There is always at least one other way to go
/// on, so the user is never stuck on a screen.
class HelpPanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  /// Extra lines under the message (e.g. what to check).
  final List<String> tips;
  final List<HelpAction> actions;

  const HelpPanel({
    super.key,
    required this.title,
    required this.message,
    required this.actions,
    this.icon = Icons.info_outline,
    this.color = AppColors.warning,
    this.tips = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: color),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        for (final tip in tips)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_outline,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          BigButton(
            label: actions[i].label,
            icon: actions[i].icon,
            style: (actions[i].primary || i == 0)
                ? BigButtonStyle.filled
                : BigButtonStyle.tonal,
            onPressed: actions[i].onPressed,
          ),
        ],
      ],
    );
  }
}

/// Shown while something is being checked: a spinner and what is going on.
class BusyPanel extends StatelessWidget {
  final String title;
  final String message;

  const BusyPanel({super.key, required this.title, this.message = ''});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(strokeWidth: 6),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
