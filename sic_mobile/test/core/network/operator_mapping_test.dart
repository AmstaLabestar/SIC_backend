import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/network/operator_mapping.dart';

void main() {
  group('OperatorMapping', () {
    test('fromBackend mappe ORANGE -> OM / Orange Money', () {
      final r = OperatorMapping.fromBackend('ORANGE');
      expect(r.code, 'OM');
      expect(r.name, 'Orange Money');
    });

    test('fromBackend garde MOOV / TELECEL / CORIS', () {
      expect(OperatorMapping.fromBackend('MOOV').code, 'MOOV');
      expect(OperatorMapping.fromBackend('TELECEL').code, 'TELECEL');
      expect(OperatorMapping.fromBackend('CORIS').code, 'CORIS');
    });

    test('fromBackend : operateur inconnu -> code = valeur en majuscules', () {
      final r = OperatorMapping.fromBackend('autre');
      expect(r.code, 'AUTRE');
    });

    test('toBackend mappe OM -> ORANGE et garde le reste', () {
      expect(OperatorMapping.toBackend('OM'), 'ORANGE');
      expect(OperatorMapping.toBackend('MOOV'), 'MOOV');
    });
  });
}
