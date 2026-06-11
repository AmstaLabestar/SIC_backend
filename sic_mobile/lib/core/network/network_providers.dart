import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'dio_client.dart';

/// Stockage securise des tokens (singleton).
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Client Dio configure avec l'intercepteur JWT.
///
/// Sur expiration de session (refresh echoue), on notifie le controleur d'auth
/// qui repassera l'app a l'etat deconnecte (la garde de route renverra au login).
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return createDioClient(
    storage: storage,
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onExpired(),
  );
});
