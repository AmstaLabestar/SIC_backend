import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/utils/fcfa_formatter.dart';

void main() {
  group('FcfaFormatter', () {
    test('format ajoute le suffixe FCFA', () {
      final out = FcfaFormatter.format(75000);
      expect(out.endsWith('FCFA'), isTrue);
      expect(out.contains('75'), isTrue);
    });

    test('formatCompact : K pour les milliers', () {
      expect(FcfaFormatter.formatCompact(85000), '85K FCFA');
    });

    test('formatCompact : M pour les millions', () {
      expect(FcfaFormatter.formatCompact(1500000), '1,50M FCFA');
    });

    test('formatCompact : montant < 1000 garde le format normal', () {
      expect(FcfaFormatter.formatCompact(500), '500 FCFA');
    });

    test('formatBenefit prefixe + pour un montant positif', () {
      expect(FcfaFormatter.formatBenefit(12500).startsWith('+ '), isTrue);
    });

    test('formatBenefit prefixe - pour un montant negatif', () {
      expect(FcfaFormatter.formatBenefit(-5000).startsWith('- '), isTrue);
    });
  });
}
