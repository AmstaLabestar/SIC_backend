import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/utils/jwt_utils.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg({'alg': 'HS256', 'typ': 'JWT'});
  final body = seg(payload);
  return '$header.$body.signature';
}

void main() {
  test('jwtHasPin : true quand le claim has_pin est vrai', () {
    expect(jwtHasPin(_fakeJwt({'has_pin': true})), isTrue);
  });

  test('jwtHasPin : false quand le claim est faux ou absent', () {
    expect(jwtHasPin(_fakeJwt({'has_pin': false})), isFalse);
    expect(jwtHasPin(_fakeJwt({'sub': 'x'})), isFalse);
  });

  test('jwtHasPin : false pour un token invalide ou nul', () {
    expect(jwtHasPin(null), isFalse);
    expect(jwtHasPin(''), isFalse);
    expect(jwtHasPin('pas-un-jwt'), isFalse);
  });

  test('decodeJwtPayload : retourne les claims', () {
    final payload = decodeJwtPayload(_fakeJwt({'has_pin': true, 'sub': '42'}));
    expect(payload['has_pin'], true);
    expect(payload['sub'], '42');
  });
}
