import 'package:flutter/material.dart';

import '../../../models/help_category.dart';
import '../../../models/service_request.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/onboarding_scaffold.dart';
import '../../shared/request_wizard.dart';

/// "Help & complaints": details (concern + what happened) -> photo ->
/// review. Staff answer it in the web's Help & Complaint Desk.
class HelpRequestFormView extends StatefulWidget {
  /// Already chosen (shown in the concern field), or null.
  final HelpCategory? category;

  const HelpRequestFormView({super.key, this.category});

  @override
  State<HelpRequestFormView> createState() => _HelpRequestFormViewState();
}

class _HelpRequestFormViewState extends State<HelpRequestFormView> {
  static const int _detailsStep = 0;

  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _otherController = TextEditingController();
  HelpCategory? _category;

  bool get _isOther => _category == HelpCategory.other;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  /// "Something else: (what was typed)" or the concern's title.
  String get _concernText {
    final category = _category ?? HelpCategory.other;
    final typed = _otherController.text.trim();
    return _isOther && typed.isNotEmpty
        ? '${category.label}: $typed'
        : category.label;
  }

  RequestDraft _draft() {
    final category = _category ?? HelpCategory.other;
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();
    final typed = _otherController.text.trim();
    final fallbackTitle = _isOther && typed.isNotEmpty ? typed : category.label;
    return RequestDraft(
      title: subject.isEmpty ? fallbackTitle : subject,
      details: [
        RequestDetail('Concern', _concernText),
        if (subject.isNotEmpty) RequestDetail('Short title', subject),
        RequestDetail('What happened', description),
      ],
      editSteps: const {
        'Concern': _detailsStep,
        'Short title': _detailsStep,
        'What happened': _detailsStep,
      },
      payload: {
        'category': category.deskCategory,
        'concernType': category.name,
        'subject': subject.isEmpty ? fallbackTitle : subject,
        'description': description,
        if (_isOther && typed.isNotEmpty) 'concernOther': typed,
      },
    );
  }

  String? _validate() {
    if (_category == null) return 'Please choose your concern.';
    if (_isOther && _otherController.text.trim().length < 2) {
      return 'Please type your concern.';
    }
    if (_descriptionController.text.trim().length < 10) {
      return 'Please tell us a little more (at least a few words).';
    }
    return null;
  }

  Future<void> _chooseConcern() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<HelpCategory>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => _ConcernSheet(selected: _category),
    );
    if (picked != null && mounted) setState(() => _category = picked);
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    return RequestWizard(
      title: 'Help & complaints',
      kind: RequestKind.help,
      photosHint: 'a photo of the problem, a receipt, or a paper',
      buildDraft: _draft,
      steps: [
        WizardStep(
          title: 'Tell us your concern',
          shortName: 'Details',
          validate: _validate,
          canContinue: () => _category != null,
          blockedHint: 'Choose one to continue',
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('What is your concern about?',
                  style: OnboardingScaffold.fieldLabel),
              const SizedBox(height: 8),
              _ConcernField(category: category, onTap: _chooseConcern),
              const SizedBox(height: 18),
              if (_isOther)
                WizardTextField(
                  label: 'Type your concern',
                  controller: _otherController,
                ),
              WizardTextField(
                label: 'Short title (optional)',
                hint: category?.titleExample ??
                    'e.g. A short summary of your concern',
                controller: _subjectController,
              ),
              WizardTextField(
                label: 'What happened? What do you need?',
                controller: _descriptionController,
                maxLines: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The "Tap to choose" box; shows the chosen concern once picked.
class _ConcernField extends StatelessWidget {
  final HelpCategory? category;
  final VoidCallback onTap;

  const _ConcernField({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chosen = category;
    return Semantics(
      button: true,
      label: chosen == null
          ? 'What is your concern about? Tap to choose.'
          : 'Concern: ${chosen.label}. Tap to change.',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: chosen == null ? AppColors.borderStrong : AppColors.primary,
            width: chosen == null ? 1.5 : 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  if (chosen != null) ...[
                    Icon(chosen.icon, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      chosen?.label ?? 'Tap to choose',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            chosen == null ? FontWeight.w400 : FontWeight.w700,
                        color: chosen == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more,
                      color: AppColors.primary, size: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The list of concerns in a bottom sheet: big rows with an icon, the
/// title, a one-line hint, and a check on the chosen one.
class _ConcernSheet extends StatelessWidget {
  final HelpCategory? selected;

  const _ConcernSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'What is your concern about?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: HelpCategory.values.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = HelpCategory.values[i];
                final isSelected = c == selected;
                return Semantics(
                  selected: isSelected,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pop(c),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 76),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(c.icon,
                                  color: AppColors.primary, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.label,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.hint,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
