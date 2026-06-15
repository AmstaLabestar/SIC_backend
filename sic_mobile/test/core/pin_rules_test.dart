import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/utils/pin_rules.dart';

void main() {
  test('PIN triviaux refuses (repetition / sequences)', () {
    for (final weak in ['0000', '1111', '1234', '4321', '2345', '987654', '111111']) {
      expect(weakPinReason(weak), isNotNull, reason: '$weak doit etre faible');
    }
  });

  test('PIN robustes acceptes', () {
    for (final ok in ['1357', '2580', '1928', '4071']) {
      expect(weakPinReason(ok), isNull, reason: '$ok doit etre accepte');
    }
  });
}
