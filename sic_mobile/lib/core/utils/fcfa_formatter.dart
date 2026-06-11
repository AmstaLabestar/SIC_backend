import 'package:intl/intl.dart';

class FcfaFormatter {
  const FcfaFormatter._();

  static final NumberFormat _fullFormat = NumberFormat.decimalPattern('fr_FR');

  static String format(double amount) {
    return '${_fullFormat.format(amount.round())} FCFA';
  }

  static String formatCompact(double amount) {
    if (amount.abs() >= 1000000) {
      final value = amount / 1000000;
      return '${_formatCompactValue(value)}M FCFA';
    }

    if (amount.abs() >= 1000) {
      final value = amount / 1000;
      return '${_formatCompactValue(value)}K FCFA';
    }

    return format(amount);
  }

  static String formatBenefit(double amount) {
    final sign = amount >= 0 ? '+ ' : '- ';
    return '$sign${format(amount.abs())}';
  }

  static String _formatCompactValue(double value) {
    final hasNoDecimal = value.truncateToDouble() == value;
    final formatted = value.toStringAsFixed(hasNoDecimal ? 0 : 2);
    return formatted.replaceAll('.', ',');
  }
}
