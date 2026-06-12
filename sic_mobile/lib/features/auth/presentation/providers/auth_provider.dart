import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDatasourceProvider),
    ref.watch(tokenStorageProvider),
  );
});

/// Etat d'authentification : `AuthUser` si connecte, `null` sinon.
/// `loading` au demarrage le temps de verifier la session.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    try {
      if (!await repo.hasSession()) {
        return null;
      }
      final result = await repo.getProfile();
      return result.fold((_) => null, (user) => user);
    } catch (_) {
      // Stockage indisponible / erreur inattendue -> considere deconnecte.
      return null;
    }
  }

  /// Retourne un message d'erreur en cas d'echec, `null` si succes.
  Future<String?> login(String username, String password) async {
    // On ne passe pas l'etat en `loading` ici : le bouton gere son propre
    // spinner, et l'etat global doit rester "deconnecte" pour que la garde de
    // route maintienne l'ecran de login (pas de flash vers le splash).
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(username, password);
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (user) {
        state = AsyncValue.data(user);
        return null;
      },
    );
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncValue.data(null);
  }

  /// Appele par l'intercepteur quand le refresh echoue (session expiree).
  void onExpired() {
    state = const AsyncValue.data(null);
  }
}
