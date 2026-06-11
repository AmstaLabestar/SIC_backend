import 'package:intl/intl.dart';

class DateFormatter {
  const DateFormatter._();

  static String formatFull(DateTime date) {
    return DateFormat("d MMM y 'a' HH'h'mm", 'fr_FR').format(date);
  }

  static String formatDate(DateTime date) {
    return DateFormat('d MMM y', 'fr_FR').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'A l instant';
    }

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    }

    if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    }

    if (difference.inDays == 1) {
      return 'Hier';
    }

    if (difference.inDays <= 2) {
      return 'Il y a ${difference.inDays} jours';
    }

    return formatDate(date);
  }
}
