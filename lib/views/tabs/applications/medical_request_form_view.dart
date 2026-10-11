import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/service_request.dart';
import '../../../widgets/choice_option.dart';
import '../../../widgets/onboarding_scaffold.dart';
import '../../shared/request_wizard.dart';

/// "Request medical assistance": type of help -> details -> photos ->
/// review. Staff process it in the web's Medical Requests module.
///
/// The backend gets the same fields as before (assistanceType, details,
/// facility, contact). The answers of step 2 are written into "details" so
/// the web shows them; they are also sent as their own fields (medicineFor,
/// consultationFor, labTest, hasDoctorRequest, hospitalHelp, hospital,
/// isUrgent, preferredDay), which the backend may store later and ignores
/// until then.
class MedicalRequestFormView extends StatefulWidget {
  const MedicalRequestFormView({super.key});

  /// Same list as the web (scms-frontend Medical.jsx ASSISTANCE_TYPES).
  static const List<String> assistanceTypes = [
    'Medicine',
    'Consultation',
    'Laboratory',
    'Hospital assistance',
    'Other',
  ];

  static const List<String> medicineOptions = [
    'Headache',
    'Fever',
    'Cough for weeks',
    'Body pain',
    'Stomach problem',
    'Maintenance medicine (e.g. blood pressure, diabetes)',
    'Vitamins',
  ];

  static const List<String> consultationOptions = [
    'General check-up',
    'Follow-up check-up',
    'Fever / cough / cold',
    'Blood pressure or sugar check',
    'Pain or body ache',
    'Skin problem',
    'Eye or ear problem',
  ];

  static const List<String> labOptions = [
    'Blood test (CBC)',
    'Blood sugar',
    'Cholesterol',
    'Urine test',
    'X-ray',
    'ECG',
  ];

  static const List<String> hospitalHelpOptions = [
    'Admission or confirmed bed',
    'Emergency help',
    'Wheelchair or someone to guide me',
    'Billing or PhilHealth help',
    'Medical records or results',
    'Transport to the hospital',
  ];

  /// "Which hospital?" Replace with the OSCA office's official list.
  /// ("Other (type it)" is always added.)
  static const List<String> hospitals = [
    'Ubay District Hospital',
    'Ubay Rural Health Unit',
  ];

  @override
  State<MedicalRequestFormView> createState() => _MedicalRequestFormViewState();
}

/// "Preferred day": shown label -> value sent to the backend.
const Map<String, String> _days = {
  'Today': 'today',
  'Tomorrow': 'tomorrow',
  'Any day': 'any',
};

class _MedicalRequestFormViewState extends State<MedicalRequestFormView> {
  static const int _typeStep = 0;
  static const int _detailsStep = 1;

  final _contactController = TextEditingController();
  String? _type;

  // Medicine
  String? _medicine;
  final _medicineOther = TextEditingController();

  // Consultation
  String? _consultation;
  final _consultationOther = TextEditingController();

  // Laboratory
  String? _lab;
  final _labOther = TextEditingController();
  bool? _hasDoctorRequest;

  // Hospital assistance
  String? _hospitalHelp;
  final _hospitalHelpOther = TextEditingController();
  String? _hospital;
  final _hospitalOther = TextEditingController();
  bool? _isUrgent;

  // Other
  final _otherNeed = TextEditingController();

  // Consultation, Laboratory, Hospital assistance, Other
  String? _day;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    if (profile != null && profile.phone.isNotEmpty) {
      _contactController.text = '0${profile.phone}';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _contactController,
      _medicineOther,
      _consultationOther,
      _labOther,
      _hospitalHelpOther,
      _hospitalOther,
      _otherNeed,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _answer(String? value, TextEditingController other) =>
      WizardDropdown.answer(value, other);

  static String _yesNo(bool? v) => v == null ? '' : (v ? 'Yes' : 'No');

  // ---------------------------------------------------------------------------
  // What is sent and shown on the review page
  // ---------------------------------------------------------------------------

  /// (review label, answer, extra backend field, its value) for step 2.
  List<(String, String, String?, String?)> _answers() {
    String? dayValue() => _day == null ? null : _days[_day];
    switch (_type) {
      case 'Medicine':
        final m = _answer(_medicine, _medicineOther);
        return [('What medicine do you need?', m, 'medicineFor', m)];
      case 'Consultation':
        final c = _answer(_consultation, _consultationOther);
        return [
          ('What is the consultation for?', c, 'consultationFor', c),
          ('Preferred day', _day ?? '', 'preferredDay', dayValue()),
        ];
      case 'Laboratory':
        final l = _answer(_lab, _labOther);
        return [
          ('Which test do you need?', l, 'labTest', l),
          ("Do you have a doctor's request?", _yesNo(_hasDoctorRequest),
              'hasDoctorRequest', _yesNo(_hasDoctorRequest).toLowerCase()),
          ('Preferred day', _day ?? '', 'preferredDay', dayValue()),
        ];
      case 'Hospital assistance':
        final h = _answer(_hospitalHelp, _hospitalHelpOther);
        final where = _answer(_hospital, _hospitalOther);
        final urgent = _isUrgent == null
            ? ''
            : (_isUrgent! ? 'Yes, today' : 'No, can wait');
        return [
          ('What help do you need?', h, 'hospitalHelp', h),
          ('Which hospital?', where, 'hospital', where),
          ('Is it urgent?', urgent, 'isUrgent',
              _isUrgent == null ? null : (_isUrgent! ? 'yes' : 'no')),
          ('Preferred day', _day ?? '', 'preferredDay', dayValue()),
        ];
      case 'Other':
        return [
          ('Tell us what you need', _otherNeed.text.trim(), null, null),
          ('Preferred day', _day ?? '', 'preferredDay', dayValue()),
        ];
    }
    return const [];
  }

  RequestDraft _draft() {
    final profile = context.read<UserProvider>().profile;
    final type = _type ?? '';
    final contact = _contactController.text.trim();
    final answers = _answers();
    const contactLabel = 'We will call you at this number';

    // One readable line for the web's Medical Requests ("details").
    final details = answers
        .where((a) => a.$2.isNotEmpty)
        .map((a) => type == 'Other' && a.$1 == 'Tell us what you need'
            ? a.$2
            : '${_shortLabel(a.$1)}: ${a.$2}.')
        .join(' ');

    return RequestDraft(
      title: type,
      details: [
        RequestDetail('Type of help', type),
        for (final a in answers) RequestDetail(a.$1, a.$2),
        RequestDetail(contactLabel, contact),
      ],
      editSteps: {
        'Type of help': _typeStep,
        for (final a in answers) a.$1: _detailsStep,
        contactLabel: _detailsStep,
      },
      payload: {
        'assistanceType': type,
        'details': details,
        'facility': type == 'Hospital assistance'
            ? _answer(_hospital, _hospitalOther)
            : '',
        'contact': contact,
        'requestDate': DateTime.now().toIso8601String().substring(0, 10),
        if (profile != null) 'barangay': profile.barangay,
        for (final a in answers)
          if (a.$3 != null && (a.$4 ?? '').isNotEmpty) a.$3!: a.$4!,
      },
    );
  }

  /// "What medicine do you need?" -> "Medicine for" (for "details").
  static String _shortLabel(String question) => switch (question) {
        'What medicine do you need?' => 'Medicine for',
        'What is the consultation for?' => 'Consultation for',
        'Which test do you need?' => 'Test',
        "Do you have a doctor's request?" => "Doctor's request",
        'What help do you need?' => 'Help needed',
        'Which hospital?' => 'Hospital',
        'Is it urgent?' => 'Urgent',
        _ => question,
      };

  // ---------------------------------------------------------------------------
  // Checking step 2
  // ---------------------------------------------------------------------------

  String? _validateDetails() {
    String? pick(String? value, TextEditingController other, String what) {
      if (value == null) return 'Please choose $what.';
      if (value == WizardDropdown.other && other.text.trim().length < 2) {
        return 'Please type $what.';
      }
      return null;
    }

    final error = switch (_type) {
      'Medicine' => pick(_medicine, _medicineOther, 'the medicine you need'),
      'Consultation' => pick(_consultation, _consultationOther,
              'what the consultation is for') ??
          (_day == null ? 'Please choose a preferred day.' : null),
      'Laboratory' => pick(_lab, _labOther, 'the test you need') ??
          (_hasDoctorRequest == null
              ? "Please tell us if you have a doctor's request."
              : null) ??
          (_day == null ? 'Please choose a preferred day.' : null),
      'Hospital assistance' =>
        pick(_hospitalHelp, _hospitalHelpOther, 'the help you need') ??
            pick(_hospital, _hospitalOther, 'the hospital') ??
            (_isUrgent == null ? 'Please tell us if it is urgent.' : null) ??
            (_day == null ? 'Please choose a preferred day.' : null),
      'Other' => _otherNeed.text.trim().length < 5
          ? 'Please tell us what you need.'
          : (_day == null ? 'Please choose a preferred day.' : null),
      _ => null,
    };
    if (error != null) return error;
    if (_contactController.text.replaceAll(RegExp(r'\D'), '').length < 7) {
      return 'Please enter the number we can call you at.';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Step 2 fields per type
  // ---------------------------------------------------------------------------

  List<Widget> _fieldsFor(String? type) {
    final day = _ChoiceGroup(
      label: 'Preferred day',
      options: _days.keys.toList(),
      value: _day,
      onChanged: (v) => setState(() => _day = v),
    );
    switch (type) {
      case 'Medicine':
        return [
          WizardDropdown(
            label: 'What medicine do you need?',
            options: MedicalRequestFormView.medicineOptions,
            value: _medicine,
            otherController: _medicineOther,
            otherLabel: 'Type the medicine you need',
            onChanged: (v) => setState(() => _medicine = v),
          ),
        ];
      case 'Consultation':
        return [
          WizardDropdown(
            label: 'What is the consultation for?',
            options: MedicalRequestFormView.consultationOptions,
            value: _consultation,
            otherController: _consultationOther,
            otherLabel: 'Type what the consultation is for',
            onChanged: (v) => setState(() => _consultation = v),
          ),
          day,
        ];
      case 'Laboratory':
        return [
          WizardDropdown(
            label: 'Which test do you need?',
            options: MedicalRequestFormView.labOptions,
            value: _lab,
            otherController: _labOther,
            otherLabel: 'Type the test you need',
            onChanged: (v) => setState(() => _lab = v),
          ),
          _ChoiceGroup(
            label: "Do you have a doctor's request?",
            options: const ['Yes', 'No'],
            value: _yesNo(_hasDoctorRequest),
            onChanged: (v) => setState(() => _hasDoctorRequest = v == 'Yes'),
          ),
          day,
        ];
      case 'Hospital assistance':
        return [
          WizardDropdown(
            label: 'What help do you need?',
            options: MedicalRequestFormView.hospitalHelpOptions,
            value: _hospitalHelp,
            otherController: _hospitalHelpOther,
            otherLabel: 'Type the help you need',
            onChanged: (v) => setState(() => _hospitalHelp = v),
          ),
          WizardDropdown(
            label: 'Which hospital?',
            options: MedicalRequestFormView.hospitals,
            value: _hospital,
            otherController: _hospitalOther,
            otherLabel: 'Type the name of the hospital',
            onChanged: (v) => setState(() => _hospital = v),
          ),
          _ChoiceGroup(
            label: 'Is it urgent?',
            options: const ['Yes, today', 'No, can wait'],
            value: _isUrgent == null
                ? null
                : (_isUrgent! ? 'Yes, today' : 'No, can wait'),
            onChanged: (v) => setState(() => _isUrgent = v == 'Yes, today'),
          ),
          day,
        ];
      case 'Other':
        return [
          WizardTextField(
            label: 'Tell us what you need',
            controller: _otherNeed,
            maxLines: 6,
          ),
          day,
        ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return RequestWizard(
      title: 'Medical assistance',
      kind: RequestKind.medical,
      photosHint: 'prescription, medical certificate, or hospital bill',
      buildDraft: _draft,
      steps: [
        WizardStep(
          title: 'What kind of help do you need?',
          shortName: 'Type of help',
          validate: () => _type == null ? 'Please choose one.' : null,
          builder: (context) => Column(
            children: [
              for (final type in MedicalRequestFormView.assistanceTypes)
                ChoiceOption(
                  text: type,
                  selected: _type == type,
                  onTap: () => setState(() => _type = type),
                ),
            ],
          ),
        ),
        WizardStep(
          title: 'Tell us more',
          shortName: 'Details',
          validate: _validateDetails,
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WizardChosenCard(
                text: 'You chose: ${_type ?? ''}',
                onChange: () => RequestWizard.goToStep(context, _typeStep),
              ),
              ..._fieldsFor(_type),
              WizardTextField(
                label: 'We will call you at this number',
                controller: _contactController,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A label above big single-choice buttons (Preferred day, Yes / No).
class _ChoiceGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  const _ChoiceGroup({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          for (final option in options)
            ChoiceOption(
              text: option,
              selected: value == option,
              onTap: () => onChanged(option),
            ),
        ],
      ),
    );
  }
}
