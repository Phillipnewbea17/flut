import 'package:flutter_test/flutter_test.dart';
import 'package:my_senior_app/utils/mpin_validator.dart';

void main() {
  group('MpinValidator', () {
    test('accepts a normal PIN', () {
      expect(MpinValidator.validate('4827'), isNull);
    });

    test('rejects wrong length', () {
      expect(MpinValidator.validate('123'), isNotNull);
      expect(MpinValidator.validate('48271'), isNotNull);
    });

    test('rejects repeated digits', () {
      expect(MpinValidator.validate('1111'), isNotNull);
      expect(MpinValidator.validate('0000'), isNotNull);
    });

    test('rejects sequences', () {
      expect(MpinValidator.validate('1234'), isNotNull);
      expect(MpinValidator.validate('4321'), isNotNull);
    });

    test('rejects non-digits', () {
      expect(MpinValidator.validate('12a4'), isNotNull);
    });

    test('matches compares two PINs', () {
      expect(MpinValidator.matches('4827', '4827'), isTrue);
      expect(MpinValidator.matches('4827', '4828'), isFalse);
    });
  });
}
