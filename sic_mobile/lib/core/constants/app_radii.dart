import 'package:flutter/widgets.dart';

/// Rayons d'arrondi du design system.
///
/// Coins genereux (24 -> 36) pour une sensation soft UI. Les petits rayons
/// (16/20) restent pour les puces et controles compacts.
class AppRadii {
  const AppRadii._();

  static const double xs = 12;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double hero = 36;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius action = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sim = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius heroCard = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}
