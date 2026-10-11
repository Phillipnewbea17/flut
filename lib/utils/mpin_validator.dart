/// Rules for the 4-digit one-time code (OTP). The backend decides whether
/// a code is right; this only stops input that can never be a code.
class OtpValidator {
  OtpValidator._();

  static const int length = 4;

  static final RegExp _digits = RegExp(r'^\d+$');

  /// Returns null when [code] could be a code, otherwise a short message.
  static String? validate(String code) {
    if (code.isEmpty) return 'Please enter the 4-digit code.';
    if (!_digits.hasMatch(code)) return 'Use numbers only.';
    if (code.length != length) return 'Please enter all 4 numbers.';
    return null;
  }
}

/// Rules for the MPIN a senior creates. Kept simple but blocks the
/// guessable ones (1234, 0000, 1111...). The backend should apply the same
/// rules: these only save a trip to the server.
class MpinValidator {
  MpinValidator._();

  static const int length = 4;

  static final RegExp _digits = RegExp(r'^\d+$');

  /// Returns null when valid, otherwise a short, senior-friendly message.
  /// [otp] is the code just used to verify the phone: the MPIN must not be
  /// the same, because that code was sent by text message.
  static String? validate(String pin, {String? otp}) {
    if (pin.isEmpty) return 'Please enter $length numbers.';
    if (!_digits.hasMatch(pin)) return 'Use numbers only.';
    if (pin.length != length) return 'Please enter exactly $length numbers.';
    if (_allSame(pin)) return 'Please avoid repeating numbers like 1111.';
    if (_isSequence(pin)) return 'Please avoid easy numbers like 1234.';
    if (otp != null && otp.isNotEmpty && pin == otp) {
      return 'Please do not use the code from the text message as your MPIN.';
    }
    return null;
  }

  /// True when [pin] is exactly 4 numbers (for the Unlock screen, where
  /// an old MPIN may not follow today's rules).
  static bool isComplete(String pin) =>
      pin.length == length && _digits.hasMatch(pin);

  static bool matches(String a, String b) => a.isNotEmpty && a == b;

  static bool _allSame(String pin) => pin.split('').toSet().length == 1;

  static bool _isSequence(String pin) {
    final d = pin.codeUnits.map((c) => c - 48).toList();
    var asc = true;
    var desc = true;
    for (var i = 1; i < d.length; i++) {
      if (d[i] != d[i - 1] + 1) asc = false;
      if (d[i] != d[i - 1] - 1) desc = false;
    }
    return asc || desc;
  }
}
