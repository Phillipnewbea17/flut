import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/service_request.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/choice_option.dart';
import '../../../widgets/onboarding_scaffold.dart';
import '../../shared/request_wizard.dart';

/// "Request burial assistance", filed by a family member for a senior who
/// passed away: about the senior -> about you -> photos -> review.
/// Staff process it in the web's Burial Requests module.
class BurialRequestFormView extends StatefulWidget {
  const BurialRequestFormView({super.key});

  static const List<String> relationships = [
    'Spouse',
    'Son or daughter',
    'Grandchild',
    'Brother or sister',
    'Other relative',
  ];

  @override
  State<BurialRequestFormView> createState() => _BurialRequestFormViewState();
}

class _BurialRequestFormViewState extends State<BurialRequestFormView> {
  final _seniorController = TextEditingController();
  final _claimantController = TextEditingController();
  final _contactController = TextEditingController();
  final _funeralHomeController = TextEditingController();
  DateTime? _deathDate;
  String? _relationship;

  static final DateFormat _dateFormat = DateFormat('MMMM d, y');

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    if (profile != null) {
      _claimantController.text = profile.fullName;
      if (profile.phone.isNotEmpty) _contactController.text = '0${profile.phone}';
    }
  }

  @override
  void dispose() {
    _seniorController.dispose();
    _claimantController.dispose();
    _contactController.dispose();
    _funeralHomeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deathDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Date of death',
    );
    if (picked != null && mounted) setState(() => _deathDate = picked);
  }

  RequestDraft _draft() {
    final senior = _seniorController.text.trim();
    final death = _deathDate;
    return RequestDraft(
      title: senior.isEmpty ? 'Burial assistance' : 'For $senior',
      details: [
        RequestDetail('Name of the senior citizen', senior),
        RequestDetail('Date of death', death == null ? '' : _dateFormat.format(death)),
        RequestDetail('Your name', _claimantController.text.trim()),
        RequestDetail('Your relationship', _relationship ?? ''),
        RequestDetail('Contact number', _contactController.text.trim()),
        RequestDetail('Funeral home', _funeralHomeController.text.trim()),
      ],
      payload: {
        'seniorName': senior,
        'deathDate': death?.toIso8601String().substring(0, 10) ?? '',
        'claimantName': _claimantController.text.trim(),
        'relationship': _relationship ?? '',
        'contact': _contactController.text.trim(),
        'funeralHome': _funeralHomeController.text.trim(),
        'requestDate': DateTime.now().toIso8601String().substring(0, 10),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RequestWizard(
      title: 'Burial assistance',
      kind: RequestKind.burial,
      photosHint: 'death certificate, and your valid ID',
      buildDraft: _draft,
      steps: [
        WizardStep(
          title: 'About the senior citizen',
          validate: () {
            if (_seniorController.text.trim().length < 3) {
              return 'Please enter the full name.';
            }
            if (_deathDate == null) return 'Please choose the date of death.';
            return null;
          },
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WizardTextField(
                label: 'Full name of the senior citizen',
                controller: _seniorController,
                capitalization: TextCapitalization.words,
              ),
              const Text('Date of death', style: OnboardingScaffold.fieldLabel),
              const SizedBox(height: 8),
              BigButton(
                label: _deathDate == null
                    ? 'Choose the date'
                    : _dateFormat.format(_deathDate!),
                icon: Icons.event_outlined,
                style: BigButtonStyle.tonal,
                onPressed: _pickDate,
              ),
            ],
          ),
        ),
        WizardStep(
          title: 'About you',
          validate: () {
            if (_claimantController.text.trim().length < 3) {
              return 'Please enter your full name.';
            }
            if (_relationship == null) {
              return 'Please choose your relationship.';
            }
            if (_contactController.text.trim().length < 7) {
              return 'Please enter a contact number.';
            }
            return null;
          },
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WizardTextField(
                label: 'Your full name',
                controller: _claimantController,
                capitalization: TextCapitalization.words,
              ),
              const Text('You are the senior\'s...',
                  style: OnboardingScaffold.fieldLabel),
              const SizedBox(height: 8),
              for (final r in BurialRequestFormView.relationships)
                ChoiceOption(
                  text: r,
                  selected: _relationship == r,
                  onTap: () => setState(() => _relationship = r),
                ),
              const SizedBox(height: 10),
              WizardTextField(
                label: 'Contact number',
                controller: _contactController,
                keyboardType: TextInputType.phone,
              ),
              WizardTextField(
                label: 'Funeral home (if any)',
                controller: _funeralHomeController,
                capitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
