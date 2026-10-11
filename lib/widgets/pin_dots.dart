import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Four big boxes showing how many MPIN digits have been typed. The digits
/// themselves are never shown: a typed box shows ●.
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;

  const PinDots({
    super.key,
    this.length = 4,
    required this.filled,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$filled of $length digits entered',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (i) {
          final isFilled = i < filled;
          final isCurrent = i == filled && !error;
          final color = error
              ? AppColors.danger
              : isCurrent
                  ? AppColors.primaryBright
                  : AppColors.primary;
          // Up to 60x72, smaller on narrow phones or big text.
          return Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 60),
                child: AspectRatio(
                  aspectRatio: 60 / 72,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: color, width: isCurrent ? 3.5 : 2),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isFilled ? '●' : '',
                        style: TextStyle(fontSize: 30, color: color),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
