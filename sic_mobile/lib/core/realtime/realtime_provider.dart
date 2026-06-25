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
  final service = RealtimeService(
    tokenReader: () => ref.read(tokenStorageProvider).readAccess(),
    baseWsUrl: () => ApiConstants.wsNotificationsUrl,
    onConnected: () => _resync(ref),
    onEvent: (event) => _handleEvent(ref, event),
  );
  ref.onDispose(service.stop);
  return service;
});

/// Re-synchronisation : la base via REST reste la source de verite. On invalide
/// (re-fetch paresseux) plutot que de patcher l'etat depuis le socket.
void _resync(Ref ref) {
  ref.invalidate(dashboardNotifierProvider);
  ref.invalidate(transactionsNotifierProvider);
}

void _handleEvent(Ref ref, Map<String, dynamic> event) {
  final type = (event['type'] as String?) ?? '';
  if (!type.startsWith('tx.')) return;

  // Evenement de transaction : on re-fetch (verite serveur) puis on notifie.
  _resync(ref);

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
