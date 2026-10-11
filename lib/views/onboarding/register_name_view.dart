import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/auth/registration_flow.dart';
import '../../models/onboarding_stage.dart';
import '../../models/registration_name.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Create Account, step 1: the user's name (before the mobile number).
/// It is sent with the registration and later fills Personal Information.
class RegisterNameView extends StatefulWidget {
  const RegisterNameView({super.key});

  @override
  State<RegisterNameView> createState() => _RegisterNameViewState();
}

class _RegisterNameViewState extends State<RegisterNameView> {
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _suffix = TextEditingController();
  bool _noMiddleName = false;
  bool _busy = false;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    // Coming back from the mobile number screen: show what was typed.
    final saved = context.read<RegistrationFlow>().name;
    if (saved != null) {
      _first.text = saved.firstName;
      _middle.text = saved.middleName;
      _last.text = saved.lastName;
      _suffix.text = saved.suffix;
      _noMiddleName = saved.noMiddleName;
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _suffix.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    // When the name is fine, the router opens the mobile number screen.
    final errors = await context.read<RegistrationFlow>().saveName(
          RegistrationName(
            firstName: _first.text,
            middleName: _middle.text,
            lastName: _last.text,
            suffix: _suffix.text,
            noMiddleName: _noMiddleName,
          ),
        );
    if (mounted) {
      setState(() {
        _busy = false;
        _errors = errors;
      });
    }
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() => _errors = Map.of(_errors)..remove(field));
    }
  }

  Widget _field({
    required String field,
    required String label,
    required TextEditingController controller,
    String? hint,
    bool enabled = true,
    TextInputAction action = TextInputAction.next,
  }) {
    final error = _errors[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled && !_busy,
            textCapitalization: TextCapitalization.words,
            textInputAction: action,
            autofillHints: switch (field) {
              'firstName' => const [AutofillHints.givenName],
              'middleName' => const [AutofillHints.middleName],
              'lastName' => const [AutofillHints.familyName],
              _ => const [AutofillHints.nameSuffix],
            },
            onChanged: (_) => _clearError(field),
            onSubmitted: action == TextInputAction.done ? (_) => _continue() : null,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              hintText: hint,
              errorText: error,
              errorStyle: OnboardingScaffold.errorText,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Create Your Account',
      subtitle: AuthFlow.register.stepLabel(OnboardingStage.signedOut)!,
      onBack: _busy ? null : () => context.go(Routes.welcome),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Please enter your name as it appears on your ID.',
              style: OnboardingScaffold.cardBody,
            ),
            const SizedBox(height: 24),
            _field(field: 'firstName', label: 'First Name', controller: _first),
            _field(
              field: 'middleName',
              label: 'Middle Name',
              controller: _middle,
              enabled: !_noMiddleName,
              hint: _noMiddleName ? 'No middle name' : null,
            ),
            // Big, easy-to-tap checkbox row.
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _busy
                    ? null
                    : () => setState(() {
                          _noMiddleName = !_noMiddleName;
                          _errors = Map.of(_errors)..remove('middleName');
                        }),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 1.4,
                        child: Checkbox(
                          value: _noMiddleName,
                          activeColor: AppColors.primary,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                    _noMiddleName = v ?? false;
                                    _errors = Map.of(_errors)
                                      ..remove('middleName');
                                  }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'I have no middle name',
                          style: TextStyle(
                            fontSize: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _field(field: 'lastName', label: 'Last Name', controller: _last),
            _field(
              field: 'suffix',
              label: 'Suffix (optional)',
              controller: _suffix,
              hint: 'Jr., Sr., III',
              action: TextInputAction.done,
            ),
            const SizedBox(height: 10),
            BigButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              trailingIcon: true,
              onPressed: _busy ? null : _continue,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.go(Routes.login),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Already have an account? Login',
                    style: OnboardingScaffold.linkText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
