class Validators {
  const Validators._();

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
