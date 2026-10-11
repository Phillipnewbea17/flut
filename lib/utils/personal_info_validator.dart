import '../models/personal_info.dart';
import '../models/user_profile.dart';
import 'senior_id_qr.dart';

/// Checks the personal information form before it is sent. The backend
/// checks it again; this only catches mistakes early, in plain words.
class PersonalInfoValidator {
  PersonalInfoValidator._();

  /// Fields that must be filled. Keep this in line with the SCMS senior
  /// citizen record's required columns.
  static const Set<PersonalField> required = {
    PersonalField.firstName,
    PersonalField.lastName,
    PersonalField.birthDate,
    PersonalField.sex,
    PersonalField.civilStatus,
    PersonalField.province,
    PersonalField.municipality,
    PersonalField.barangay,
  };

  static const int seniorAge = 60;

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _nameChars = RegExp(r"^[A-Za-zÑñ .'\-]+$");

  /// Field -> message. Empty when everything is fine.
  static Map<PersonalField, String> validate(
    PersonalInfo info, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final errors = <PersonalField, String>{};

    for (final field in required) {
      if (info.valueOf(field).trim().isEmpty) {
        errors[field] = switch (field) {
          PersonalField.birthDate => 'Please choose your date of birth.',
          PersonalField.sex => 'Please choose one.',
          PersonalField.civilStatus => 'Please choose one.',
          _ => 'Please fill this in.',
        };
      }
    }

    for (final field in const [
      PersonalField.firstName,
      PersonalField.middleName,
      PersonalField.lastName,
    ]) {
      final value = info.valueOf(field).trim();
      if (value.isNotEmpty && !_nameChars.hasMatch(value)) {
        errors[field] = 'Please use letters only.';
      }
    }

    final birth = info.birthDate;
    if (birth != null) {
      if (birth.isAfter(now) || birth.year < 1900) {
        errors[PersonalField.birthDate] = 'Please check the date of birth.';
      } else if (UserProfile.ageOn(birth, now) < seniorAge) {
        errors[PersonalField.birthDate] =
            'Senior citizens are $seniorAge years old or above. '
            'Please check the date of birth.';
      }
    }

    final id = info.seniorId.trim();
    if (id.isNotEmpty && !SeniorIdQr.isValidId(id)) {
      errors[PersonalField.seniorId] =
          'Please check the ID number. Use only the letters, numbers and '
          'dashes on your ID.';
    }

    final email = info.email.trim();
    if (email.isNotEmpty && !_email.hasMatch(email)) {
      errors[PersonalField.email] = 'Please check the email address.';
    }

    return errors;
  }
}
