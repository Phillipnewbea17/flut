import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';

/// "Who is using this phone?" - Step 3 of 4.
class RoleSelectionView extends StatefulWidget {
  const RoleSelectionView({super.key});

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView> {
  final TextEditingController _nameController = TextEditingController();

  UserRole? _role;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // If the user comes back to this step, show what they chose before.
    final profile = context.read<UserProvider>().profile;
    if (profile != null && profile.fullName.isNotEmpty) {
      _nameController.text = profile.fullName;
      _role = profile.role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _ready => _role != null && _nameController.text.trim().length >= 2;

  Future<void> _continue() async {
    final role = _role;
    if (role == null || !_ready || _busy) return;

    FocusScope.of(context).unfocus();
    final user = context.read<UserProvider>();
    final session = context.read<SessionProvider>();

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await user.saveProfile(fullName: _nameController.text, role: role);
      await session.advanceTo(OnboardingStage.emergencySetup);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Who is using this phone?',
      subtitle: OnboardingStage.roleSelection.stepLabel!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Choose one', style: OnboardingScaffold.cardTitle),
          const SizedBox(height: 8),
          const Text(
            'This sets up the right account for you.',
            style: OnboardingScaffold.cardBody,
          ),
          const SizedBox(height: 20),
          _RoleOption(
            icon: Icons.person_outline,
            title: 'I am a Senior Citizen',
            subtitle: '60 years old or above',
            selected: _role == UserRole.senior,
            onTap: () => setState(() => _role = UserRole.senior),
          ),
          const SizedBox(height: 16),
          _RoleOption(
            icon: Icons.group_outlined,
            title: 'I am a Family Relative',
            subtitle: 'Proxy mode: I help a senior',
            selected: _role == UserRole.familyRelative,
            onTap: () => setState(() => _role = UserRole.familyRelative),
          ),
          const SizedBox(height: 28),
          const Text('Enter your full name', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _continue(),
            style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Maria Dela Cruz'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: OnboardingScaffold.errorText),
          ],
          const SizedBox(height: 28),
          BigButton(
            label: 'Continue to emergency setup',
            icon: Icons.arrow_forward,
            trailingIcon: true,
            onPressed: (_ready && !_busy) ? _continue : null,
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 3 : 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 34, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 17,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.borderStrong,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 26)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
