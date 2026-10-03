import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Big on-screen number pad (easier than the system keyboard for seniors).
class MpinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const MpinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map(_buildKey).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String key) {
    if (key.isEmpty) return const SizedBox(width: 84, height: 72);

    final isBackspace = key == '<';
    return SizedBox(
      width: 84,
      height: 72,
      child: Material(
        color: isBackspace ? Colors.transparent : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => isBackspace ? onBackspace() : onDigit(key),
          child: Center(
            child: isBackspace
                ? const Icon(Icons.backspace_outlined,
                    size: 30, color: AppColors.primary)
                : Text(
                    key,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
