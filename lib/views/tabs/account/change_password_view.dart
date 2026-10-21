import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/session_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/password_validator.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/green_page_header.dart';
import '../../../widgets/password_field.dart';

/// Account > Change Password: the current password, then the new one twice.
/// The backend checks the current one and signs every other phone out.
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final FocusNode _nextFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  String? _currentError;
  String? _nextError;
  String? _confirmError;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_currentError == null && _nextError == null && _confirmError == null) {
      return;
    }
    setState(() {
      _currentError = null;
      _nextError = null;
      _confirmError = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final session = context.read<SessionProvider>();
    final nextError =
        PasswordValidator.validate(_next.text, email: session.lastEmail);
    final confirmError = PasswordValidator.matches(_next.text, _confirm.text)
        ? null
        : 'The passwords do not match. Please type them again.';
    final currentError =
        _current.text.isEmpty ? 'Please enter your current password.' : null;

    if (currentError != null || nextError != null || confirmError != null) {
      setState(() {
        _currentError = currentError;
        _nextError = nextError;
        _confirmError = nextError == null ? confirmError : null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _currentError = null;
      _nextError = null;
      _confirmError = null;
    });

    final problem = await session.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (problem != null) {
      // A new password the backend refused goes under the new password;
      // anything else (a wrong current password, no connection) under the
      // current one.
      setState(() {
        if (SessionProvider.newPasswordProblems.contains(problem)) {
          _nextError = problem;
        } else {
          _currentError = problem;
        }
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your password was changed.',
            style: TextStyle(fontSize: 18)),
      ),
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const GreenPageHeader(
            title: 'Change Password',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'You will stay logged in on this phone. Any other phone will '
                'have to log in again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 17, height: 1.4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Current password'),
                PasswordField(
                  controller: _current,
                  enabled: !_saving,
                  hasError: _currentError != null,
                  textInputAction: TextInputAction.next,
                  hintText: 'Your password now',
                  onChanged: (_) => _clearErrors(),
                  onSubmitted: (_) => _nextFocus.requestFocus(),
                ),
                ..._message(_currentError),
                const SizedBox(height: 18),
                _label('New password'),
                PasswordField(
                  controller: _next,
                  focusNode: _nextFocus,
                  enabled: !_saving,
                  isNew: true,
                  hasError: _nextError != null,
                  textInputAction: TextInputAction.next,
                  hintText: 'At least ${PasswordValidator.minLength} characters',
                  onChanged: (_) => _clearErrors(),
                  onSubmitted: (_) => _confirmFocus.requestFocus(),
                ),
                ..._message(_nextError),
                const SizedBox(height: 18),
                _label('Confirm new password'),
                PasswordField(
                  controller: _confirm,
                  focusNode: _confirmFocus,
                  enabled: !_saving,
                  isNew: true,
                  hasError: _confirmError != null,
                  hintText: 'Type the new password again',
                  onChanged: (_) => _clearErrors(),
                  onSubmitted: (_) => _save(),
                ),
                ..._message(_confirmError),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 8, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: BigButton(
            label: _saving ? 'Saving...' : 'Save new password',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );

  List<Widget> _message(String? text) => text == null
      ? const []
      : [
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ];
}
