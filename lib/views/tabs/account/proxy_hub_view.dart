import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/user_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// "Family mode": a relative keeps a list of the seniors they help, and
/// sends papers for them.
class ProxyHubView extends StatelessWidget {
  const ProxyHubView({super.key});

  Future<void> _remove(BuildContext context, ManagedSenior senior) async {
    final repo = context.read<UserRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${senior.fullName}?',
            style: const TextStyle(fontSize: 24)),
        content: const Text(
          'They will be removed from your list on this phone.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await repo.removeSenior(senior.id);
  }

  @override
  Widget build(BuildContext context) {
    final isProxy = context.watch<UserProvider>().isProxy;
    final seniors = context.watch<UserRepository>().managedSeniors;

    return Scaffold(
      appBar: AppTheme.appBar('Family mode'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          InfoCard(
            outlined: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.group_outlined, color: AppColors.primary, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isProxy
                        ? 'Add the seniors you help. You can send their '
                            'papers and check on their application for them.'
                        : 'A family member can help you apply. They install '
                            'this app on their phone and choose "I am a '
                            'Family Relative". You can also add a senior you '
                            'help here.',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            seniors.isEmpty ? 'No one added yet' : 'Seniors you help',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final senior in seniors) ...[
            _SeniorCard(
              senior: senior,
              onUpload: () => context.push(Routes.upload),
              onRemove: () => _remove(context, senior),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          BigButton(
            label: 'Add a senior',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              backgroundColor: Colors.white,
              builder: (sheetContext) => const _AddSeniorSheet(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeniorCard extends StatelessWidget {
  final ManagedSenior senior;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  const _SeniorCard({
    required this.senior,
    required this.onUpload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final eligible = senior.isEligible;
    return InfoCard(
      outlined: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person_outline, color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senior.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${senior.relationship}  •  Age ${senior.age}',
                      style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                iconSize: 28,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                eligible ? Icons.check_circle : Icons.schedule,
                color: eligible ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eligible
                      ? 'Can apply for a Senior Citizen ID'
                      : 'Can apply when they turn 60',
                  style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          if (eligible) ...[
            const SizedBox(height: 14),
            BigButton(
              label: 'Send their papers',
              icon: Icons.upload_file_outlined,
              style: BigButtonStyle.tonal,
              onPressed: onUpload,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddSeniorSheet extends StatefulWidget {
  const _AddSeniorSheet();

  @override
  State<_AddSeniorSheet> createState() => _AddSeniorSheetState();
}

class _AddSeniorSheetState extends State<_AddSeniorSheet> {
  static const List<String> _relationships = [
    'Mother',
    'Father',
    'Grandparent',
    'Spouse',
    'Sibling',
    'Other',
  ];

  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
  String _relationship = _relationships.first;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 65, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Their birthday',
      initialEntryMode: DatePickerEntryMode.input,
      fieldHintText: 'mm/dd/yyyy',
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final birthDate = _birthDate;
    if (name.length < 2) {
      setState(() => _error = 'Please enter their full name.');
      return;
    }
    if (birthDate == null) {
      setState(() => _error = 'Please choose their birthday.');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<UserRepository>().addSenior(
          ManagedSenior(
            id: 'senior-${DateTime.now().millisecondsSinceEpoch}',
            fullName: name,
            birthDate: birthDate,
            relationship: _relationship,
          ),
        );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add a senior',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          const Text('Full name', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(hintText: 'Maria Dela Cruz'),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 18),
          const Text('They are my...', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final r in _relationships)
                ChoiceChip(
                  label: Text(r),
                  selected: r == _relationship,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: r == _relationship ? Colors.white : AppColors.primary,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  onSelected: (_) => setState(() => _relationship = r),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: OnboardingScaffold.errorText),
          ],
          const SizedBox(height: 24),
          BigButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save),
        ],
      ),
    );
  }
}
