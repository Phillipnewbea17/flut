/// The name a new user gives in Create Account, before the mobile number.
/// It is sent with the registration and becomes the account's First,
/// Middle and Last name and Suffix in Personal Information.
class RegistrationName {
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;

  /// "I have no middle name" is checked: [middleName] is intentionally empty.
  final bool noMiddleName;

  const RegistrationName({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.noMiddleName,
  });

  static const int maxNameLength = 100;
  static const int maxSuffixLength = 10;

  /// Same letters as Personal Information (PersonalInfoValidator).
  static final RegExp _nameChars = RegExp(r"^[A-Za-zÑñ .'\-]+$");

  /// Jr., Sr., II, III, IV...
  static final RegExp _suffixChars = RegExp(r'^[A-Za-z.]+$');

  /// Trimmed, with single spaces, and no middle name when it was ticked off.
  RegistrationName get cleaned {
    String tidy(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return RegistrationName(
      firstName: tidy(firstName),
      middleName: noMiddleName ? '' : tidy(middleName),
      lastName: tidy(lastName),
      suffix: tidy(suffix),
      noMiddleName: noMiddleName,
    );
  }

  /// "Rosela Santos Mabuhay Jr."
  String get fullName => [firstName, middleName, lastName, suffix]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(' ');

  /// Field name -> message. Empty when everything is fine.
  static Map<String, String> validate(RegistrationName raw) {
    final name = raw.cleaned;
    final errors = <String, String>{};

    void checkName(String field, String value, String label,
        {required bool required}) {
      if (value.isEmpty) {
        if (required) errors[field] = 'Please enter your $label.';
      } else if (value.length > maxNameLength) {
        errors[field] = 'Please shorten your $label.';
      } else if (!_nameChars.hasMatch(value)) {
        errors[field] = 'Please use letters only.';
      }
    }

    checkName('firstName', name.firstName, 'first name', required: true);
    checkName('middleName', name.middleName, 'middle name',
        required: !name.noMiddleName);
    if (errors['middleName'] == 'Please enter your middle name.') {
      errors['middleName'] = 'Please enter your middle name, or tick '
          '"I have no middle name".';
    }
    checkName('lastName', name.lastName, 'last name', required: true);

    if (name.suffix.isNotEmpty &&
        (name.suffix.length > maxSuffixLength ||
            !_suffixChars.hasMatch(name.suffix))) {
      errors['suffix'] = 'Please write the suffix like Jr., Sr. or III.';
    }
    return errors;
  }

  /// The fields sent to POST /auth/register.
  Map<String, dynamic> toJson() {
    final name = cleaned;
    return {
      'firstName': name.firstName,
      'middleName': name.noMiddleName ? null : name.middleName,
      'lastName': name.lastName,
      'suffix': name.suffix.isEmpty ? null : name.suffix,
      'noMiddleName': name.noMiddleName,
    };
  }
}
