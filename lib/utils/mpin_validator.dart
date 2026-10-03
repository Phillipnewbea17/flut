/// Rules for the MPIN a senior creates. Kept simple but blocks the
/// guessable ones (1234, 0000, 1111...).
class MpinValidator {
  MpinValidator._();

  static const int length = 4;

  /// Returns null when valid, otherwise a short, senior-friendly message.
  static String? validate(String pin) {
    if (pin.length != length) return 'Please enter $length digits.';
    if (!RegExp(r'^\d+$').hasMatch(pin)) return 'Use numbers only.';
    if (_allSame(pin)) return 'Please avoid repeating numbers like 1111.';
    if (_isSequence(pin)) return 'Please avoid easy numbers like 1234.';
    return null;
  }

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
