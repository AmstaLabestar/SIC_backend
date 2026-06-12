import 'dart:convert';

/// Decode le payload (2e segment) d'un JWT sans verifier la signature.
///
/// La verification de signature est faite cote serveur ; ici on lit juste les
/// claims (ex: `has_pin`) que le backend ajoute au token d'acces.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return const {};
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    return decoded is Map<String, dynamic> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}

/// Vrai si le token d'acces porte le claim `has_pin = true`.
bool jwtHasPin(String? token) {
  if (token == null || token.isEmpty) return false;
  return decodeJwtPayload(token)['has_pin'] == true;
}
