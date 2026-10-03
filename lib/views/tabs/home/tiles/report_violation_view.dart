import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app_state/user_provider.dart';
import '../../../../services/benefits_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/big_button.dart';
import '../../../../widgets/onboarding_scaffold.dart';

/// Report a store that refused the senior discount or priority lane.
class ReportViolationView extends StatefulWidget {
  const ReportViolationView({super.key});

  @override
  State<ReportViolationView> createState() => _ReportViolationViewState();
}

class _ReportViolationViewState extends State<ReportViolationView> {
  static const List<String> _issues = [
    'They did not give my 20% discount',
    'They did not remove the VAT',
    'They did not give the 5% grocery discount',
    'No priority lane for seniors',
    'They asked for papers I do not need',
    'Something else',
  ];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  DateTime _date = DateTime.now();
  String? _issue;
  String? _issueError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    if (profile != null && profile.hasAddress) {
      _placeController.text = profile.shortAddress;
    }
  }

  @override
  void dispose() {
    _storeController.dispose();
    _placeController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'When did it happen?',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _send() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _issueError = _issue == null ? 'Please choose one.' : null);
    if (!formOk || _issue == null) return;

    FocusScope.of(context).unfocus();
    final service = context.read<BenefitsService>();
    final phone = context.read<UserProvider>().profile?.phone ?? '';
    setState(() => _sending = true);
    try {
      final reference = await service.reportViolation(
        store: _storeController.text.trim(),
        location: _placeController.text.trim(),
        date: _date,
        issue: _issue!,
        details: _detailsController.text.trim(),
        reporterPhone: phone,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
          title: const Text('Report sent', style: TextStyle(fontSize: 26)),
          content: Text(
            'Thank you. Your reference number is $reference. The OSCA office '
            'may call you about it.',
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (context.canPop()) context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The report was not sent. Please try again.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Report a store'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Text('Name of the store', style: OnboardingScaffold.fieldLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _storeController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                hintText: 'e.g. ABC Pharmacy',
                errorStyle: OnboardingScaffold.errorText,
              ),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Please enter the store name.'
                  : null,
            ),
            const SizedBox(height: 20),
            const Text('Where is it?', style: OnboardingScaffold.fieldLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _placeController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(hintText: 'Town or street'),
            ),
            const SizedBox(height: 20),
            const Text('When did it happen?', style: OnboardingScaffold.fieldLabel),
            const SizedBox(height: 8),
            BigButton(
              label: DateFormat('MMMM d, y').format(_date),
              icon: Icons.event_outlined,
              style: BigButtonStyle.tonal,
              onPressed: _pickDate,
            ),
            const SizedBox(height: 20),
            const Text('What happened?', style: OnboardingScaffold.fieldLabel),
            const SizedBox(height: 8),
            for (final issue in _issues)
              _IssueOption(
                text: issue,
                selected: _issue == issue,
                onTap: () => setState(() {
                  _issue = issue;
                  _issueError = null;
                }),
              ),
            if (_issueError != null)
              Text(_issueError!, style: OnboardingScaffold.errorText),
            const SizedBox(height: 20),
            const Text('Tell us more (optional)', style: OnboardingScaffold.fieldLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _detailsController,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(fontSize: 19),
              decoration: const InputDecoration(
                hintText: 'What did the cashier say? How much did you pay?',
              ),
            ),
            const SizedBox(height: 28),
            BigButton(
              label: _sending ? 'Sending...' : 'Send report',
              icon: Icons.send_outlined,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueOption extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _IssueOption({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primaryLight : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? AppColors.primary : AppColors.borderStrong,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
