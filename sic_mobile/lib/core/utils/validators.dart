/// Validators for SIC Mobile
class Validators {
  // ============================================================================
  // USERNAME
  // ============================================================================

  /// Validate username
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le nom d\'utilisateur est requis';
    }
    if (value.length < 3) {
      return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
    }
    if (value.length > 150) {
      return 'Le nom d\'utilisateur ne peut pas dépasser 150 caractères';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Le nom d\'utilisateur ne peut contenir que des lettres, chiffres et _';
    }
    return null;
  }

  // ============================================================================
  // EMAIL
  // ============================================================================

  /// Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer un email valide';
    }
    return null;
  }

  // ============================================================================
  // PASSWORD
  // ============================================================================

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une minuscule';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    return null;
  }

  /// Validate password confirmation
  static String? validatePasswordConfirm(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'La confirmation est requise';
    }
    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  // ============================================================================
  // PHONE NUMBER
  // ============================================================================

  /// Validate phone number for West Africa
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }

    // Clean the phone number
    final phone = value.replaceAll(RegExp(r'[\s\-\.]'), '');

    // Pattern for West African numbers (+224, +226, +228, +229)
    final phoneRegex = RegExp(r'^(\+224|\+226|\+228|\+229)?[0-9]{8,9}$');

    if (!phoneRegex.hasMatch(phone)) {
      return 'Format invalide. Ex: +224621234567';
    }

    return null;
  }

  /// Validate phone number format for a specific operator
  static String? validateOperatorPhone(String? value, String operator) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }

    final phone = value.replaceAll(RegExp(r'[\s\-\.]'), '');

    // Remove country code for validation
    final digits = phone.replaceAll(RegExp(r'^\+\d{3}'), '');

    if (digits.length != 8) {
      return 'Le numéro doit contenir 8 chiffres';
    }

    // Check prefix based on operator
    final prefix = digits.substring(0, 2);

    switch (operator.toUpperCase()) {
      case 'ORANGE':
        // Orange Guinea typically starts with 62, 64, 66
        if (!['62', '64', '66', '67'].contains(prefix)) {
          return 'Numéro Orange invalide';
        }
        break;
      case 'MOOV':
        // Moov typically starts with 65, 66
        if (!['65', '66'].contains(prefix)) {
          return 'Numéro Moov invalide';
        }
        break;
      case 'TELECEL':
        // Telécel typically starts with 67, 68
        if (!['67', '68'].contains(prefix)) {
          return 'Numéro Togocel invalide';
        }
        break;
      case 'CORIS':
        // Coris starts with 60-69
        if (int.tryParse(prefix) == null) {
          return 'Numéro Coris invalide';
        }
        break;
    }

    return null;
  }

  // ============================================================================
  // PIN
  // ============================================================================

  /// Validate PIN code
  static String? validatePin(String? value, {int minLength = 4, int maxLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Le code PIN est requis';
    }
    if (value.length < minLength) {
      return 'Le code PIN doit contenir au moins $minLength chiffres';
    }
    if (value.length > maxLength) {
      return 'Le code PIN ne peut pas dépasser $maxLength chiffres';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Le code PIN doit contenir uniquement des chiffres';
    }
    // Check for simple patterns
    if (RegExp(r'^(\d)\1+$').hasMatch(value)) {
      return 'Évitez les chiffres répétés';
    }
    if (_isSequential(value)) {
      return 'Évitez les suites de chiffres';
    }
    return null;
  }

  /// Check if pin is sequential (1234, 4321, etc.)
  static bool _isSequential(String pin) {
    if (pin.length < 4) return false;

    // Check ascending sequence
    bool ascending = true;
    for (int i = 1; i < pin.length; i++) {
      if (int.parse(pin[i]) != int.parse(pin[i - 1]) + 1) {
        ascending = false;
        break;
      }
    }
    if (ascending) return true;

    // Check descending sequence
    bool descending = true;
    for (int i = 1; i < pin.length; i++) {
      if (int.parse(pin[i]) != int.parse(pin[i - 1]) - 1) {
        descending = false;
        break;
      }
    }
    return descending;
  }

  // ============================================================================
  // AMOUNT
  // ============================================================================

  /// Validate transaction amount
  static String? validateAmount(
    String? value, {
    double min = 100,
    double max = 5000000,
    double? balance,
  }) {
    if (value == null || value.isEmpty) {
      return 'Le montant est requis';
    }

    // Clean and parse amount
    final amountStr = value.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(amountStr);

    if (amount == null) {
      return 'Montant invalide';
    }

    if (amount < min) {
      return 'Montant minimum: ${min.toStringAsFixed(0)} FCFA';
    }

    if (amount > max) {
      return 'Montant maximum: ${max.toStringAsFixed(0)} FCFA';
    }

    if (balance != null && amount > balance) {
      return 'Solde insuffisant';
    }

    // Check for valid decimal places (max 2)
    if (amountStr.contains('.')) {
      final parts = amountStr.split('.');
      if (parts.length > 1 && parts[1].length > 2) {
        return 'Maximum 2 décimales autorisées';
      }
    }

    return null;
  }

  // ============================================================================
  // OPERATOR
  // ============================================================================

  /// Validate operator
  static String? validateOperator(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'opérateur est requis';
    }

    const validOperators = ['ORANGE', 'MOOV', 'TELECEL', 'CORIS'];
    if (!validOperators.contains(value.toUpperCase())) {
      return 'Opérateur invalide. Options: ${validOperators.join(', ')}';
    }

    return null;
  }

  // ============================================================================
  // GENERAL
  // ============================================================================

  /// Check if field is empty
  static String? required(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  /// Check minimum length
  static String? minLength(String? value, int min, {String fieldName = 'Ce champ'}) {
    if (value == null || value.length < min) {
      return '$fieldName doit contenir au moins $min caractères';
    }
    return null;
  }

  /// Check maximum length
  static String? maxLength(String? value, int max, {String fieldName = 'Ce champ'}) {
    if (value != null && value.length > max) {
      return '$fieldName ne peut pas dépasser $max caractères';
    }
    return null;
  }
}