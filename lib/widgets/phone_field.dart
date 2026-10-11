import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Shows a Philippine mobile number as the user types: 955 140 2068.
/// It keeps digits only, drops a leading 0 or 63, and stops at 10 digits.
class PhoneNumberFormatter extends TextInputFormatter {
  const PhoneNumberFormatter();

  /// "0955 140 2068", "+63 955 140 2068" or "9551402068" -> "955 140 2068".
  static String format(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length > 10) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length > 10) digits = digits.substring(0, 10);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Mobile number box with the Philippine flag and "+63" in front.
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  const PhoneField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hasError = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
  });

  @override
  Widget build(BuildContext context) {
    // This Focus widget only watches: it knows when the text box inside it
    // is focused, so the green ring can be drawn.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final Color borderColor = hasError
              ? AppColors.danger
              : focused
                  ? AppColors.primaryBright
                  : AppColors.borderStrong;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: (focused || hasError) ? 3 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Row(
                children: [
                  Container(
                    width: 116,
                    color: AppColors.primaryLight,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    // Shrinks a little with very big text instead of
                    // spilling out of the box.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _PhilippineFlag(),
                          SizedBox(width: 10),
                          Text(
                            '+63',
                            style: TextStyle(
                              fontSize: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: enabled,
                        keyboardType: TextInputType.phone,
                        textInputAction: textInputAction,
                        inputFormatters: const [PhoneNumberFormatter()],
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '9XX XXX XXXX',
                          hintStyle: TextStyle(
                            fontSize: 22,
                            letterSpacing: 1,
                            color: Color(0xFF8A9A92),
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhilippineFlag extends StatelessWidget {
  const _PhilippineFlag();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const SizedBox(
          width: 38,
          height: 26,
          child: CustomPaint(painter: _FlagPainter()),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = const Color(0xFF0038A8);
    final red = Paint()..color = const Color(0xFFCE1126);
    final white = Paint()..color = Colors.white;
    final yellow = Paint()..color = const Color(0xFFFCD116);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      blue,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      red,
    );

    final triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, white);

    canvas.drawCircle(
      Offset(size.width * 0.15, size.height / 2),
      size.height * 0.09,
      yellow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
