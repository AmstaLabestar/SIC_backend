import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../features/transactions/presentation/providers/transaction_providers.dart';
import '../app_globals.dart';
import '../constants/api_constants.dart';
import '../network/network_providers.dart';
import 'realtime_service.dart';

/// Service temps reel de l'app (singleton). Le cycle de vie (start/stop selon
/// l'auth et le premier plan) est pilote depuis `main.dart`.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  Timer? resyncTimer;

  // Re-synchronisation debouncee : la base via REST reste la source de verite.
  // Une rafale d'evenements (plusieurs transactions confirmees coup sur coup)
  // ne declenche qu'un seul re-fetch. On invalide (re-fetch paresseux) plutot
  // que de patcher l'etat depuis le payload socket.
  void scheduleResync() {
    resyncTimer?.cancel();
    resyncTimer = Timer(const Duration(milliseconds: 400), () {
      ref.invalidate(dashboardNotifierProvider);
      ref.invalidate(transactionsNotifierProvider);
    });
  }

  final service = RealtimeService(
    tokenReader: () => ref.read(tokenStorageProvider).readAccess(),
    baseWsUrl: () => ApiConstants.wsNotificationsUrl,
    onConnected: scheduleResync,
    onEvent: (event) {
      final type = (event['type'] as String?) ?? '';
      if (!type.startsWith('tx.')) return;
      scheduleResync();
      _notify(event);
    },
  );

  ref.onDispose(() {
    resyncTimer?.cancel();
    service.stop();
  });
  return service;
});

void _notify(Map<String, dynamic> event) {
  final message = switch (event['status'] as String?) {
    'COMPLETED' => 'Transaction confirmee.',
    'FAILED' => 'Transaction echouee.',
    _ => 'Transaction en cours...',
  };
  scaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
}
