import '../network/operator_mapping.dart';

class Validators {
  const Validators._();

  /// Prefixes nationaux par operateur (code backend), miroir du backend.
  /// Burkina Faso (+226) : numero national de 8 chiffres.
  static const Map<String, List<String>> _bfPrefixes = {
    'ORANGE': [
      '04', '05', '06', '07', '44', '54', '55', '56', '57',
      '64', '65', '66', '67', '74', '75', '76', '77',
    ],
    'MOOV': [
      '01', '02', '03', '50', '51', '52', '53',
      '60', '61', '62', '63', '70', '71', '72', '73',
    ],
    'TELECEL': ['58', '59', '68', '69', '78', '79'],
  };

  /// Cote d'Ivoire (+225) : numero national de 10 chiffres.
  static const Map<String, List<String>> _ciPrefixes = {
    'ORANGE': ['07'],
    'MTN': ['05'],
    'MOOV': ['01'],
  };

  static const List<String> _countryCodes = ['+226', '226', '+225', '225'];

  /// Retire l'indicatif (+226/+225) et la ponctuation -> numero national.
  static String normalizePhone(String value) {
    var phone = value.trim().replaceAll(RegExp(r'[\s\-.()]'), '');
    for (final code in _countryCodes) {
      if (phone.startsWith(code)) {
        return phone.substring(code.length);
      }
    }
    if (phone.startsWith('+')) {
      phone = phone.substring(1);
    }
    return phone;
  }

  /// Valide un numero pour un operateur (code mobile : OM/MOOV/TELECEL/MTN).
  static String? validateOperatorPhone(String? value, String operatorCode) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return 'Le numero est obligatoire.';
    }

    final national = normalizePhone(raw);
    if (!RegExp(r'^\d+$').hasMatch(national)) {
      return 'Le numero ne doit contenir que des chiffres.';
    }

    final backend = OperatorMapping.toBackend(operatorCode);
    final bf = _bfPrefixes[backend];
    final ci = _ciPrefixes[backend];

    final okBf =
        bf != null && national.length == 8 && bf.any(national.startsWith);
    final okCi =
        ci != null && national.length == 10 && ci.any(national.startsWith);

    if (okBf || okCi) {
      return null;
    }
    return 'Numero invalide pour cet operateur (Burkina : 8 chiffres).';
  }

  /// Valide un numero sans operateur precise : accepte s'il correspond a
  /// l'un des operateurs connus (Burkina 8 chiffres / Cote d'Ivoire 10).
  static String? validateAnyPhone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return 'Le numero est obligatoire.';
    }
    final national = normalizePhone(raw);
    if (!RegExp(r'^\d+$').hasMatch(national)) {
      return 'Le numero ne doit contenir que des chiffres.';
    }
    bool matches(Map<String, List<String>> table, int length) =>
        table.values.any(
          (prefixes) =>
              national.length == length &&
              prefixes.any(national.startsWith),
        );
    if (matches(_bfPrefixes, 8) || matches(_ciPrefixes, 10)) {
      return null;
    }
    return 'Numero invalide (Burkina : 8 chiffres).';
  }

  static String? validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Le numero est obligatoire.';
    }

    final phoneRegex = RegExp(r'^(01|05|07)\d{8}$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'Entrez un numero valide de 10 chiffres.';
    }

    return null;
  }

  static String? validateAmount(String? value) {
    final rawValue = value?.trim().replaceAll(' ', '') ?? '';

    if (rawValue.isEmpty) {
      return 'Le montant est obligatoire.';
    }

    final amount = double.tryParse(rawValue.replaceAll(',', '.'));
    if (amount == null) {
      return 'Entrez un montant valide.';
    }

    if (amount < 100) {
      return 'Le montant minimum est 100 FCFA.';
    }

    if (amount > 2000000) {
      return 'Le montant maximum est 2 000 000 FCFA.';
    }

    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est obligatoire.';
    }

    return null;
  }
}
