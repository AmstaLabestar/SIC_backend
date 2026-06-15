/// Regles de robustesse du code PIN (lot A6).
///
/// Miroir de api/services/pin_rules.py cote backend : refuse les PIN triviaux
/// (tout identiques, sequences croissantes/decroissantes) pour un retour
/// immediat a l'utilisateur avant l'appel reseau.
library;

/// Retourne une raison si le PIN est trop faible, sinon `null`.
/// Suppose un PIN compose uniquement de chiffres (4 a 6).
String? weakPinReason(String pin) {
  pin = pin.trim();

  // Tous les chiffres identiques : 0000, 1111...
  if (pin.split('').toSet().length == 1) {
    return 'Code trop simple : evitez de repeter le meme chiffre.';
  }

  // Sequence strictement croissante ou decroissante : 1234, 4321...
  final digits = pin.split('').map(int.parse).toList();
  final diffs = <int>{};
  for (var i = 1; i < digits.length; i++) {
    diffs.add(digits[i] - digits[i - 1]);
  }
  if (diffs.length == 1 && (diffs.contains(1) || diffs.contains(-1))) {
    return 'Code trop simple : evitez les chiffres qui se suivent.';
  }

  return null;
}
