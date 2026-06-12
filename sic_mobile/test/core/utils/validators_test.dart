import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/utils/validators.dart';

void main() {
  group('Validators.validateOperatorPhone', () {
    test('Orange Burkina (8 chiffres, prefixe valide) -> null', () {
      expect(Validators.validateOperatorPhone('07123456', 'OM'), isNull);
      expect(Validators.validateOperatorPhone('54123456', 'OM'), isNull);
    });

    test('indicatif +226 accepte et normalise', () {
      expect(Validators.validateOperatorPhone('+22670123456', 'MOOV'), isNull);
    });

    test('Moov Burkina prefixe valide (70) -> null', () {
      expect(Validators.validateOperatorPhone('70123456', 'MOOV'), isNull);
    });

    test('Telecel Burkina prefixe valide (78) -> null', () {
      expect(Validators.validateOperatorPhone('78123456', 'TELECEL'), isNull);
    });

    test('prefixe d\'un autre operateur -> message d\'erreur', () {
      // 70 = Moov, refuse pour Orange.
      expect(Validators.validateOperatorPhone('70123456', 'OM'), isNotNull);
    });

    test('mauvaise longueur -> message d\'erreur', () {
      expect(Validators.validateOperatorPhone('0712345', 'OM'), isNotNull);
    });

    test('Cote d\'Ivoire 10 chiffres (07 Orange) -> null', () {
      expect(Validators.validateOperatorPhone('0701234567', 'OM'), isNull);
    });

    test('MTN uniquement Cote d\'Ivoire (05, 10 chiffres) -> null', () {
      expect(Validators.validateOperatorPhone('0512345678', 'MTN'), isNull);
      // MTN n'existe pas au Burkina (8 chiffres) -> refuse.
      expect(Validators.validateOperatorPhone('05123456', 'MTN'), isNotNull);
    });

    test('numero vide -> message d\'erreur', () {
      expect(Validators.validateOperatorPhone('', 'OM'), isNotNull);
    });
  });
}
