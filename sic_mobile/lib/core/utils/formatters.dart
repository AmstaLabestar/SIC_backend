import 'package:intl/intl.dart';

/// Formatters for SIC Mobile
class Formatters {
  // ============================================================================
  // CURRENCY
  // ============================================================================

  /// Format amount as FCFA currency
  /// Example: 10000 -> "10 000 FCFA"
  static String currency(double amount, {String symbol = 'FCFA'}) {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return '${formatter.format(amount)} $symbol';
  }

  /// Format amount without symbol
  /// Example: 10000 -> "10 000"
  static String amount(double amount) {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return formatter.format(amount);
  }

  /// Format compact amount
  /// Example: 5000000 -> "5M", 1500000 -> "1,5M"
  static String compactAmount(double amount) {
    if (amount >= 1000000) {
      final value = amount / 1000000;
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}M';
    } else if (amount >= 1000) {
      final value = amount / 1000;
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // ============================================================================
  // PHONE NUMBER
  // ============================================================================

  /// Format phone number for display
  /// Example: "+224621234567" -> "62 12 34 567"
  static String phoneNumber(String phone) {
    // Remove any non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    // Format with spaces every 2 digits
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 2 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  /// Clean phone number for API
  /// Example: "62 12 34 567" -> "621234567"
  static String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  // ============================================================================
  // DATE & TIME
  // ============================================================================

  /// Format date for display
  /// Example: "31/05/2024"
  static String date(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  /// Format date with time
  /// Example: "31/05/2024 à 14:30"
  static String dateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(dateTime);
  }

  /// Format time only
  /// Example: "14:30"
  static String time(DateTime dateTime) {
    return DateFormat('HH:mm', 'fr_FR').format(dateTime);
  }

  /// Format relative date
  /// Example: "Aujourd'hui", "Hier", "Il y a 3 jours"
  static String relativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) {
      return "Aujourd'hui";
    } else if (difference == 1) {
      return 'Hier';
    } else if (difference == 2) {
      return 'Avant-hier';
    } else if (difference < 7) {
      return 'Il y a $difference jours';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return weeks == 1 ? 'Il y a 1 semaine' : 'Il y a $weeks semaines';
    } else if (difference < 365) {
      final months = (difference / 30).floor();
      return months == 1 ? 'Il y a 1 mois' : 'Il y a $months mois';
    } else {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(dateTime);
    }
  }

  /// Format relative date with time
  static String relativeDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return relativeDate(dateTime);
    }
  }

  // ============================================================================
  // TRANSACTION TYPE
  // ============================================================================

  /// Get French label for transaction type
  static String transactionTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'DEPOT':
        return 'Dépôt';
      case 'RETRAIT':
        return 'Retrait';
      case 'TRANSFERT':
        return 'Transfert';
      case 'SWAP':
        return 'Conversion';
      default:
        return type;
    }
  }

  /// Get icon name for transaction type
  static String transactionTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'DEPOT':
        return 'arrow_downward';
      case 'RETRAIT':
        return 'arrow_upward';
      case 'TRANSFERT':
        return 'swap_horiz';
      case 'SWAP':
        return 'swap_horiz';
      default:
        return 'receipt';
    }
  }

  // ============================================================================
  // STATUS
  // ============================================================================

  /// Get French label for transaction status
  static String statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'En attente';
      case 'COMPLETED':
        return 'Complété';
      case 'FAILED':
        return 'Échoué';
      case 'SUCCESS':
        return 'Succès';
      case 'REFUNDED':
        return 'Remboursé';
      default:
        return status;
    }
  }

  /// Get color for status
  static int statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 0xFFF59E0B; // Warning
      case 'COMPLETED':
      case 'SUCCESS':
        return 0xFF10B981; // Success
      case 'FAILED':
      case 'REFUNDED':
        return 0xFFEF4444; // Error
      default:
        return 0xFF64748B; // Gray
    }
  }

  // ============================================================================
  // OPERATOR
  // ============================================================================

  /// Get French label for operator
  static String operatorLabel(String operator) {
    switch (operator.toUpperCase()) {
      case 'ORANGE':
        return 'Orange';
      case 'MOOV':
        return 'Moov';
      case 'TELECEL':
        return 'Togocel';
      case 'CORIS':
        return 'Coris';
      default:
        return operator;
    }
  }

  /// Get color for operator
  static int operatorColor(String operator) {
    switch (operator.toUpperCase()) {
      case 'ORANGE':
        return 0xFFFF6600;
      case 'MOOV':
        return 0xFF1E88E5;
      case 'TELECEL':
        return 0xFFFF6F00;
      case 'CORIS':
        return 0xFF4CAF50;
      default:
        return 0xFF6366F1;
    }
  }

  // ============================================================================
  // KYC STATUS
  // ============================================================================

  /// Get French label for KYC status
  static String kycStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'En attente';
      case 'APPROVED':
        return 'Approuvé';
      case 'REJECTED':
        return 'Rejeté';
      default:
        return status;
    }
  }

  /// Get color for KYC status
  static int kycStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 0xFFF59E0B;
      case 'APPROVED':
        return 0xFF10B981;
      case 'REJECTED':
        return 0xFFEF4444;
      default:
        return 0xFF64748B;
    }
  }
}