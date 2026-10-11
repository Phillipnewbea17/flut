import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import '../app_state/user_provider.dart';
import '../models/emergency_contact.dart';
import '../theme/app_colors.dart';
import 'big_button.dart';
import 'onboarding_scaffold.dart';
import 'phone_field.dart';

/// Name + mobile number form for the SOS contact. Used in setup (Step 4) and
/// again later in Account > Emergency contact, so the button text is a
/// parameter.
class EmergencyContactForm extends StatefulWidget {
  final EmergencyContact? initial;

  /// The user's own number (10 digits). The SOS contact cannot be the same.
  final String? ownPhone;

  /// Numbers of the other emergency contacts, so no one is added twice.
  final Set<String> takenPhones;

  final String submitLabel;
  final IconData submitIcon;
  final Future<void> Function(EmergencyContact contact) onSubmit;

  const EmergencyContactForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.submitIcon = Icons.save_outlined,
    this.initial,
    this.ownPhone,
    this.takenPhones = const {},
  });

  @override
  State<EmergencyContactForm> createState() => _EmergencyContactFormState();
}

class _EmergencyContactFormState extends State<EmergencyContactForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  final FlutterNativeContactPicker _picker = FlutterNativeContactPicker();

  String? _nameError;
  String? _phoneError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _nameController.text = initial.name;
      _phoneController.text = PhoneNumberFormatter.format(initial.phone);
      _relationshipController.text = initial.relationship;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  /// Opens the phone's own contact list and fills in the form.
  Future<void> _pickContact() async {
    try {
      final contact = await _picker.selectContact();
      if (contact == null || !mounted) return;

      final name = (contact.fullName ?? '').trim();
      final numbers = contact.phoneNumbers ?? const <String>[];

      String? digits;
      for (final number in numbers) {
        final candidate = UserProvider.normalizePhone(number);
        if (UserProvider.isValidPhone(candidate)) {
          digits = candidate;
          break;
        }
      }

      setState(() {
        if (name.isNotEmpty) {
          _nameController.text = name;
          _nameError = null;
        }
        if (digits != null) {
          _phoneController.text = PhoneNumberFormatter.format(digits);
          _phoneError = null;
        } else {
          _phoneController.clear();
          _phoneError =
              'This contact has no Philippine mobile number. Please type one.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phoneError =
            'We could not open your contacts. Please type the number instead.';
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = UserProvider.normalizePhone(_phoneController.text);

    String? nameError;
    String? phoneError;
    if (name.length < 2) {
      nameError = 'Please enter the name of this person.';
    }
    if (!UserProvider.isValidPhone(phone)) {
      phoneError = 'Please enter a 10-digit mobile number that starts with 9.';
    } else if (phone == widget.ownPhone) {
      phoneError = 'Please choose someone other than yourself.';
    } else if (widget.takenPhones.contains(phone)) {
      phoneError = 'This person is already on your list.';
    }

    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
    });
    if (nameError != null || phoneError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.onSubmit(EmergencyContact(
        name: name,
        phone: phone,
        relationship: _relationshipController.text.trim(),
      ));
    } catch (_) {
      if (mounted) {
        setState(() {
          _phoneError = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BigButton(
          label: 'Choose from phone contacts',
          icon: Icons.person_outline,
          style: BigButtonStyle.tonal,
          onPressed: _busy ? null : _pickContact,
        ),
        const SizedBox(height: 28),
        const Text('Contact name', style: OnboardingScaffold.fieldLabel),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Juan Dela Cruz',
            errorText: _nameError,
            errorMaxLines: 2,
            errorStyle: OnboardingScaffold.errorText,
          ),
        ),
        const SizedBox(height: 24),
        const Text('Relationship (optional)',
            style: OnboardingScaffold.fieldLabel),
        const SizedBox(height: 10),
        TextField(
          controller: _relationshipController,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Daughter, Son, Neighbor'),
        ),
        const SizedBox(height: 24),
        const Text('Mobile number', style: OnboardingScaffold.fieldLabel),
        const SizedBox(height: 10),
        PhoneField(
          controller: _phoneController,
          enabled: !_busy,
          hasError: _phoneError != null,
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        if (_phoneError != null) ...[
          const SizedBox(height: 8),
          Text(_phoneError!, style: OnboardingScaffold.errorText),
        ],
        const SizedBox(height: 28),
        BigButton(
          label: widget.submitLabel,
          icon: widget.submitIcon,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
