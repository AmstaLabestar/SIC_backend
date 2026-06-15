"""
Règles de robustesse du code PIN (lot A6).

Refuse les PIN triviaux (tout identiques, séquences croissantes/décroissantes)
qui sont les premiers essayés en cas de vol d'appareil. Partagé par le
serializer de création de PIN ; la même logique est dupliquée côté Flutter
(lib/core/utils/pin_rules.dart) pour un retour immédiat à l'utilisateur.
"""


def weak_pin_reason(pin):
    """Retourne une raison (str) si le PIN est trop faible, sinon None.

    Suppose un PIN déjà validé comme une suite de chiffres (4 à 6).
    """
    pin = (pin or '').strip()

    # Tous les chiffres identiques : 0000, 1111, 222222...
    if len(set(pin)) == 1:
        return "Code trop simple : évitez de répéter le même chiffre."

    # Séquence strictement croissante ou décroissante : 1234, 3456, 4321...
    digits = [int(c) for c in pin]
    diffs = {b - a for a, b in zip(digits, digits[1:])}
    if diffs == {1}:
        return "Code trop simple : évitez les chiffres qui se suivent."
    if diffs == {-1}:
        return "Code trop simple : évitez les chiffres qui se suivent."

    return None
