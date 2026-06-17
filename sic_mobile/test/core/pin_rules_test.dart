import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/utils/pin_rules.dart';

// Parite front/back : ce corpus doit rester identique a celui du backend
// (api/tests.py::PinStrengthTest.test_unit_weak_pin_reason) pour garantir que
// les deux implementations de weakPinReason / weak_pin_reason donnent le meme
// verdict. Toute modification ici doit etre repercutee la-bas.
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
