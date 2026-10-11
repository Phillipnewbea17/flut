import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/help_category.dart';
import '../../../models/service_request.dart';
import '../../../repositories/requests_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/choice_option.dart';
import '../../../widgets/onboarding_scaffold.dart';
import '../../../widgets/section_title.dart';

/// Report a store that refused the senior discount or priority lane.
/// Part of Help & complaints ("Discount or benefit problem").
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

  /// Files the report as a Help & complaints case ("Discount or benefit
  /// problem"), so the web Help Desk receives it like any other concern.
  Future<void> _send() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _issueError = _issue == null ? 'Please choose one.' : null);
    if (!formOk || _issue == null) return;

    FocusScope.of(context).unfocus();
    final requests = context.read<RequestsRepository>();
    final store = _storeController.text.trim();
    final place = _placeController.text.trim();
    final date = DateFormat('MMMM d, y').format(_date);
    final details = _detailsController.text.trim();
    const category = HelpCategory.discountProblem;
    setState(() => _sending = true);
    try {
      final request = await requests.create(
        kind: RequestKind.help,
        title: 'Store: $store',
        details: [
          const RequestDetail('Concern', 'Discount or benefit problem'),
          RequestDetail('Store', store),
          RequestDetail('Where', place),
          RequestDetail('When', date),
          RequestDetail('What happened', _issue!),
          if (details.isNotEmpty) RequestDetail('More details', details),
        ],
        payload: {
          'category': category.deskCategory,
          'concernType': category.name,
          'subject': 'Discount refused: $store',
          'description': [
            'Store: $store',
            if (place.isNotEmpty) 'Where: $place',
            'When: $date',
            'What happened: $_issue',
            if (details.isNotEmpty) details,
          ].join('\n'),
        },
      );
      if (!mounted) return;
      context.pushReplacement(Routes.request(request.id, justSent: true));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your report. Please try again.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        context.watch<RequestsRepository>().isAvailable(RequestKind.help);
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
              ChoiceOption(
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
            if (!available) ...[
              const NoticeCard.notConnected(
                text: 'Reports cannot be sent from the app yet. If you '
                    'continue, your report is saved on this phone only. It is '
                    'NOT sent to the OSCA office.',
              ),
              const SizedBox(height: 16),
            ],
            BigButton(
              label: _sending
                  ? 'Sending...'
                  : available
                      ? 'Send report'
                      : 'Save on this phone',
              icon: Icons.send_outlined,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
