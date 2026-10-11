import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/personal_info.dart';
import '../../models/user_profile.dart';
import '../../repositories/identity_repository.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/personal_info_validator.dart';
import '../../widgets/big_button.dart';
import '../../widgets/choice_option.dart';
import '../../widgets/onboarding_scaffold.dart';
import 'identity_actions.dart';

enum InfoFormMode {
  /// "Enter your information": an empty form, then Review.
  manual,

  /// "Review Your Information": what was found or typed, then Confirm.
  review,
}

/// The personal information form. In review mode, fields that came from the
/// SCMS record are shown locked ("Managed by OSCA"); everything else can be
/// corrected, including what was read from the ID.
class PersonalInfoFormView extends StatefulWidget {
  final InfoFormMode mode;

  const PersonalInfoFormView({super.key, required this.mode});

  @override
  State<PersonalInfoFormView> createState() => _PersonalInfoFormViewState();
}

class _PersonalInfoFormViewState extends State<PersonalInfoFormView> {
  late final Map<PersonalField, TextEditingController> _text;
  DateTime? _birthDate;
  Sex? _sex;
  CivilStatus? _civilStatus;
  Map<PersonalField, String> _errors = const {};

  static const _textFields = [
    PersonalField.firstName,
    PersonalField.middleName,
    PersonalField.lastName,
    PersonalField.suffix,
    PersonalField.seniorId,
    PersonalField.email,
    PersonalField.province,
    PersonalField.municipality,
    PersonalField.barangay,
    PersonalField.purok,
    PersonalField.addressLine,
  ];

  bool get _isReview => widget.mode == InfoFormMode.review;

  @override
  void initState() {
    super.initState();
    final draft = context.read<IdentityRepository>().draft;
    _text = {
      for (final f in _textFields)
        f: TextEditingController(text: draft.valueOf(f)),
    };
    _birthDate = draft.birthDate;
    _sex = draft.sex;
    _civilStatus = draft.civilStatus;
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  PersonalInfo _collect(PersonalInfo base) => PersonalInfo(
        firstName: _text[PersonalField.firstName]!.text,
        middleName: _text[PersonalField.middleName]!.text,
        lastName: _text[PersonalField.lastName]!.text,
        suffix: _text[PersonalField.suffix]!.text,
        birthDate: _birthDate,
        sex: _sex,
        civilStatus: _civilStatus,
        seniorId: _text[PersonalField.seniorId]!.text.trim().toUpperCase(),
        mobile: base.mobile,
        email: _text[PersonalField.email]!.text,
        province: _text[PersonalField.province]!.text,
        municipality: _text[PersonalField.municipality]!.text,
        barangay: _text[PersonalField.barangay]!.text,
        purok: _text[PersonalField.purok]!.text,
        addressLine: _text[PersonalField.addressLine]!.text,
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 65, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Your date of birth',
      initialEntryMode: DatePickerEntryMode.input,
      fieldHintText: 'mm/dd/yyyy',
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _errors = Map.of(_errors)..remove(PersonalField.birthDate);
      });
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final identity = context.read<IdentityRepository>();
    identity.updateDraft(_collect(identity.draft));

    final errors = _isReview
        ? identity.confirmDraft()
        : PersonalInfoValidator.validate(identity.draft);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    if (_isReview) {
      context.push(Routes.identityVerification);
    } else {
      context.push(Routes.reviewInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityRepository>();
    final locked = _isReview ? identity.lockedFields : const <PersonalField>{};
    final draft = identity.draft;

    return Scaffold(
      appBar: AppTheme.appBar(
          _isReview ? 'Review Your Information' : 'Enter your information'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _Intro(mode: widget.mode, source: identity.source),
          const SizedBox(height: 8),
          const Text('* required',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),

          _Section('Basic information'),
          ..._textOrLocked(PersonalField.firstName, locked),
          ..._textOrLocked(PersonalField.middleName, locked),
          ..._textOrLocked(PersonalField.lastName, locked),
          ..._textOrLocked(PersonalField.suffix, locked),
          if (locked.contains(PersonalField.birthDate))
            _LockedField(PersonalField.birthDate, draft.birthDateLabel)
          else
            _dateField(),
          if (locked.contains(PersonalField.sex))
            _LockedField(PersonalField.sex, draft.sex?.label ?? '')
          else
            _sexField(),
          if (locked.contains(PersonalField.civilStatus))
            _LockedField(PersonalField.civilStatus, draft.civilStatus?.label ?? '')
          else
            _civilStatusField(),

          _Section('Senior citizen information'),
          ..._textOrLocked(
            PersonalField.seniorId,
            locked,
            hint: 'e.g. SC-000123',
            help: 'The number on your Senior Citizen ID. Leave it empty if '
                'you do not have an ID yet.',
            caps: TextCapitalization.characters,
          ),

          _Section('Contact information'),
          const Text('Mobile number', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 6),
          Text(
            UserProfile.formatPhone(draft.mobile),
            style: const TextStyle(fontSize: 21, color: AppColors.textPrimary),
          ),
          const Text(
            'The number you signed in with.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          ..._textOrLocked(PersonalField.email, locked,
              keyboard: TextInputType.emailAddress, hint: 'Optional'),

          _Section('Address'),
          ..._textOrLocked(PersonalField.province, locked, hint: 'e.g. Bohol'),
          ..._textOrLocked(PersonalField.municipality, locked, hint: 'e.g. Ubay'),
          ..._textOrLocked(PersonalField.barangay, locked, hint: 'e.g. Poblacion'),
          ..._textOrLocked(PersonalField.purok, locked, hint: 'Optional'),
          ..._textOrLocked(PersonalField.addressLine, locked, hint: 'Optional'),

          const SizedBox(height: 12),
          if (_errors.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Please check the fields marked in red.',
                style: OnboardingScaffold.errorText,
              ),
            ),
          if (_isReview)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Please make sure the information above is correct.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          BigButton(
            label: _isReview ? 'Verify My Information' : 'Review information',
            icon: _isReview ? Icons.check : Icons.arrow_forward,
            trailingIcon: !_isReview,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => IdentityActions.otherMethods(context),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Use another method',
                  style: OnboardingScaffold.linkText),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _textOrLocked(
    PersonalField field,
    Set<PersonalField> locked, {
    String? hint,
    String? help,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization caps = TextCapitalization.words,
  }) {
    if (locked.contains(field)) {
      return [_LockedField(field, _text[field]!.text)];
    }
    final required = PersonalInfoValidator.required.contains(field);
    return [
      Text('${field.label}${required ? ' *' : ''}',
          style: OnboardingScaffold.fieldLabel),
      if (help != null) ...[
        const SizedBox(height: 4),
        Text(help,
            style: const TextStyle(
                fontSize: 16, color: AppColors.textSecondary, height: 1.35)),
      ],
      const SizedBox(height: 8),
      TextField(
        controller: _text[field],
        keyboardType: keyboard,
        textCapitalization:
            keyboard == TextInputType.emailAddress ? TextCapitalization.none : caps,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
        onChanged: (_) {
          if (_errors.containsKey(field)) {
            setState(() => _errors = Map.of(_errors)..remove(field));
          }
        },
        decoration: InputDecoration(
          hintText: hint,
          errorText: _errors[field],
          errorMaxLines: 3,
          errorStyle: OnboardingScaffold.errorText,
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  Widget _dateField() {
    final error = _errors[PersonalField.birthDate];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Date of birth *', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          BigButton(
            label: _birthDate == null
                ? 'Choose date of birth'
                : DateFormat('MMMM d, y').format(_birthDate!),
            icon: Icons.cake_outlined,
            style: BigButtonStyle.tonal,
            onPressed: _pickDate,
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: OnboardingScaffold.errorText),
          ],
        ],
      ),
    );
  }

  Widget _sexField() {
    final error = _errors[PersonalField.sex];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sex *', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          for (final s in Sex.values)
            ChoiceOption(
              text: s.label,
              selected: _sex == s,
              onTap: () => setState(() {
                _sex = s;
                _errors = Map.of(_errors)..remove(PersonalField.sex);
              }),
            ),
          if (error != null) Text(error, style: OnboardingScaffold.errorText),
        ],
      ),
    );
  }

  Widget _civilStatusField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Civil status *', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          DropdownButtonFormField<CivilStatus>(
            initialValue: _civilStatus,
            isExpanded: true,
            itemHeight: 56,
            style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Choose one',
              errorText: _errors[PersonalField.civilStatus],
              errorStyle: OnboardingScaffold.errorText,
            ),
            items: [
              for (final s in CivilStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (value) => setState(() {
              _civilStatus = value;
              _errors = Map.of(_errors)..remove(PersonalField.civilStatus);
            }),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final InfoFormMode mode;
  final InfoSource source;

  const _Intro({required this.mode, required this.source});

  @override
  Widget build(BuildContext context) {
    final text = mode == InfoFormMode.manual
        ? 'Please type your information. We will check it with the OSCA '
            'office records.'
        : switch (source) {
            InfoSource.record =>
              'We found your record at the OSCA office. Details with a lock '
                  'are managed by OSCA. Please check the rest.',
            InfoSource.qr || InfoSource.idPhoto =>
              'We filled in the information we found. Please check that '
                  'everything is correct.',
            InfoSource.manual =>
              'Please check that everything is correct.',
          };
    return Text(
      text,
      style: const TextStyle(fontSize: 19, color: AppColors.textPrimary, height: 1.4),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(thickness: 2, color: AppColors.primaryLight),
        ],
      ),
    );
  }
}

/// A field that only the OSCA office can change.
class _LockedField extends StatelessWidget {
  final PersonalField field;
  final String value;

  const _LockedField(this.field, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        label: '${field.label}: ${value.isEmpty ? 'not set' : value}. '
            'Managed by OSCA.',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.label,
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      value.isEmpty ? '-' : value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Managed by OSCA. Contact OSCA to correct this '
                      'information.',
                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
