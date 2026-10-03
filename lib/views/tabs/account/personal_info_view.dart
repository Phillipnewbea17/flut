import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/user_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/onboarding_scaffold.dart';

class PersonalInfoView extends StatefulWidget {
  const PersonalInfoView({super.key});

  @override
  State<PersonalInfoView> createState() => _PersonalInfoViewState();
}

class _PersonalInfoViewState extends State<PersonalInfoView> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    _nameController.text = profile?.fullName ?? '';
    _birthDate = profile?.birthDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 60, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Your birthday',
      initialEntryMode: DatePickerEntryMode.input,
      fieldHintText: 'mm/dd/yyyy',
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final user = context.read<UserProvider>();
    final users = context.read<UserRepository>();
    final profile = user.profile;
    final name = _nameController.text.trim();
    if (profile == null) return;
    if (name.length < 2) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final updated = profile.copyWith(fullName: name, birthDate: _birthDate);
    await user.updateProfile(updated);
    await users.syncProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved.', style: TextStyle(fontSize: 18))),
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().profile;

    return Scaffold(
      appBar: AppTheme.appBar('Personal information'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Text('Full name', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Maria Dela Cruz',
              errorText: _error,
              errorStyle: OnboardingScaffold.errorText,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Birthday', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          BigButton(
            label: _birthDate == null
                ? 'Choose birthday'
                : DateFormat('MMMM d, y').format(_birthDate!),
            icon: Icons.cake_outlined,
            style: BigButtonStyle.tonal,
            onPressed: _pickDate,
          ),
          const SizedBox(height: 20),
          const Text('Mobile number', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          Text(
            profile?.displayPhone ?? '',
            style: const TextStyle(fontSize: 22, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'To use a new number, log out and log in with the new number.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('I am a', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          Text(
            profile?.role.label ?? '',
            style: const TextStyle(fontSize: 22, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 32),
          BigButton(
            label: _saving ? 'Saving...' : 'Save changes',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
