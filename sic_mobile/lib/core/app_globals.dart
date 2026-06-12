import 'package:flutter/material.dart';

/// Cle globale du ScaffoldMessenger : permet d'afficher un SnackBar depuis
/// l'exterieur de l'arbre (ex. intercepteur reseau a l'expiration de session).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
