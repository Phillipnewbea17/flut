/// Rules for the password a senior chooses. Length is what actually helps,
/// so there are no symbol or mixed-case demands: a senior should not be
/// fought with rules they cannot read. The backend applies the same rules;
/// these only save a trip to the server.
class PasswordValidator {
  PasswordValidator._();

  /// Keep in step with AppAccount::MIN_PASSWORD on the backend.
  static const int minLength = 8;

  /// Bcrypt stops reading after 72 bytes, so there is no point allowing more.
  static const int maxLength = 72;

  /// The handful that would be guessed first. The backend has the same list.
  static const List<String> _common = [
    'password',
    'password1',
    'password123',
    '12345678',
    '123456789',
    '1234567890',
    'qwertyui',
    'qwerty123',
    '11111111',
    '00000000',
    'abc12345',
    'iloveyou',
    'senior123',
  ];

  /// Returns null when valid, otherwise a short, senior-friendly message.
  /// [email] is the address being registered: a password must not be it.
  static String? validate(String password, {String? email}) {
    if (password.isEmpty) return 'Please enter a password.';
    if (password.length < minLength) {
      return 'Please use at least $minLength characters.';
    }
    if (password.length > maxLength) {
      return 'Please use $maxLength characters or fewer.';
    }
    final lower = password.toLowerCase();
    if (email != null && lower == email.trim().toLowerCase()) {
      return 'Please do not use your email address as your password.';
    }
    if (_common.contains(lower)) {
      return 'This password is too easy to guess. Please choose another one.';
    }
    return null;
  }

  /// True when [password] is long enough to be worth sending (the Login
  /// screen, where an older password may not follow today's rules).
  static bool isComplete(String password) => password.isNotEmpty;

  static bool matches(String a, String b) => a.isNotEmpty && a == b;
}
