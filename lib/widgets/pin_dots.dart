import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Row of dots showing how many MPIN digits have been typed.
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (i) {
          final isFilled = i < filled;
          final color = error ? AppColors.danger : AppColors.primary;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? color : Colors.transparent,
              border: Border.all(color: color, width: 3),
            ),
          );
        }),
      ),
    );
  }
}
