import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Password box, in the same big, high-contrast style as [EmailField].
///
/// The eye button shows the password as plain text. That matters here: a
/// senior typing a long password on a phone keyboard needs to be able to
/// check what they typed, and hiding it is what makes them pick something
/// short instead.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool hasError;
  final bool enabled;

  /// "new-password" lets the phone offer to make and save a strong one;
  /// "current-password" lets it fill the saved one in.
  final bool isNew;

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  const PasswordField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hasError = false,
    this.enabled = true,
    this.isNew = false,
    this.hintText = 'Your password',
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _shown = false;

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
          final Color borderColor = widget.hasError
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
                width: (focused || widget.hasError) ? 3 : 1.5,
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
                        Icons.lock_outline,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: widget.enabled,
                        obscureText: !_shown,
                        keyboardType: _shown
                            ? TextInputType.visiblePassword
                            : TextInputType.text,
                        textInputAction: widget.textInputAction,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: [
                          widget.isNew
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: const TextStyle(
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
                  // Big enough to hit without aiming.
                  Semantics(
                    button: true,
                    label: _shown ? 'Hide password' : 'Show password',
                    child: InkWell(
                      onTap: widget.enabled
                          ? () => setState(() => _shown = !_shown)
                          : null,
                      child: SizedBox(
                        width: 60,
                        height: 72,
                        child: Center(
                          child: Icon(
                            _shown
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 26,
                            color: AppColors.textSecondary,
                          ),
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
