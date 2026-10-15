import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Email address box, in the same big, high-contrast style as [PhoneField].
/// The envelope in front says what the box is for without extra reading.
class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  const EmailField({
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
                    width: 64,
                    color: AppColors.primaryLight,
                    alignment: Alignment.center,
                    child: const ExcludeSemantics(
                      child: Icon(
                        Icons.mail_outline,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: enabled,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: textInputAction,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        // Addresses are lower-case here, and the first
                        // letter must not be capitalised for the user.
                        textCapitalization: TextCapitalization.none,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'juan@gmail.com',
                          hintStyle: TextStyle(
                            fontSize: 19,
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
