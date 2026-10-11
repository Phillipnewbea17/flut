import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/utils/mpin_validator.dart';

void main() {
  group('OtpValidator (4 digits)', () {
    test('accepts exactly 4 digits', () {
      expect(OtpValidator.length, 4);
      expect(OtpValidator.validate('4827'), isNull);
      expect(OtpValidator.validate('0000'), isNull);
    });

    test('rejects 3 digits', () {
      expect(OtpValidator.validate('482'), isNotNull);
    });

    test('rejects 5 digits', () {
      expect(OtpValidator.validate('48271'), isNotNull);
    });

    test('rejects letters', () {
      expect(OtpValidator.validate('48a7'), 'Use numbers only.');
      expect(OtpValidator.validate('abcd'), isNotNull);
    });

    test('rejects an empty code', () {
      expect(OtpValidator.validate(''), isNotNull);
    });
  });

  group('MpinValidator (4 digits)', () {
    test('accepts exactly 4 digits', () {
      expect(MpinValidator.length, 4);
      expect(MpinValidator.validate('4827'), isNull);
    });

    test('rejects 3 digits', () {
      expect(MpinValidator.validate('482'), isNotNull);
    });

    test('rejects 5 digits', () {
      expect(MpinValidator.validate('48271'), isNotNull);
    });

    test('rejects 6 digits (the old length)', () {
      expect(MpinValidator.validate('482715'), isNotNull);
    });

    test('rejects letters', () {
      expect(MpinValidator.validate('12a4'), 'Use numbers only.');
    });

    test('rejects an empty MPIN', () {
      expect(MpinValidator.validate(''), isNotNull);
    });

    test('rejects weak MPINs', () {
      for (final weak in ['0000', '1111', '1234', '4321', '6789', '9876']) {
        expect(MpinValidator.validate(weak), isNotNull, reason: weak);
      }
    });

    test('rejects the code from the text message', () {
      expect(MpinValidator.validate('4827', otp: '4827'), isNotNull);
      expect(MpinValidator.validate('4827', otp: '5190'), isNull);
    });

    test('confirming: matching MPINs', () {
      expect(MpinValidator.matches('4827', '4827'), isTrue);
    });

    test('confirming: mismatching MPINs', () {
      expect(MpinValidator.matches('4827', '4828'), isFalse);
      expect(MpinValidator.matches('', ''), isFalse);
    });

    test('isComplete only checks the shape (for Unlock)', () {
      expect(MpinValidator.isComplete('1234'), isTrue);
      expect(MpinValidator.isComplete('123'), isFalse);
      expect(MpinValidator.isComplete('12a4'), isFalse);
    });
  });
}
