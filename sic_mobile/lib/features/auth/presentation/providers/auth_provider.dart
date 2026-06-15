import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'app_lock_provider.dart';
import 'biometric_provider.dart';

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

  /// Connexion. Retourne `(error, deviceEmail)` :
  /// - `error` non nul -> echec a afficher ;
  /// - `deviceEmail` non nul -> nouvel appareil (lot A4) : rediriger vers la
  ///   verification OTP appareil (l'email masque est fourni) ;
  /// - les deux nuls -> connexion reussie.
  Future<({String? error, String? deviceEmail})> login(
    String username,
    String password,
  ) async {
    // On ne passe pas l'etat en `loading` ici : le bouton gere son propre
    // spinner, et l'etat global doit rester "deconnecte" pour que la garde de
    // route maintienne l'ecran de login (pas de flash vers le splash).
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(username, password);
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        if (failure is DeviceVerificationFailure) {
          return (error: null, deviceEmail: failure.email);
        }
        return (error: failure.message, deviceEmail: null);
      },
      (user) {
        _onAuthenticated(user);
        return (error: null, deviceEmail: null);
      },
    );
  }

  /// Verifie un nouvel appareil par OTP email puis connecte (lot A4).
  /// Retourne un message d'erreur, ou `null` si succes.
  Future<String?> verifyDevice({
    required String identifier,
    required String password,
    required String otp,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyDevice(
      identifier: identifier,
      password: password,
      otp: otp,
    );
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (user) {
        _onAuthenticated(user);
        return null;
      },
    );
  }

  /// Finalise une connexion reussie : purge les donnees de l'ancien compte,
  /// deverrouille l'app et publie l'utilisateur.
  void _onAuthenticated(AuthUser user) {
    // Nouvel utilisateur connecte : on purge les donnees de l'eventuel compte
    // precedent (dashboard, historique) pour eviter un affichage perime.
    _invalidateUserData();
    // L'agent vient de saisir ses identifiants -> app deverrouillee.
    ref.read(appLockProvider.notifier).unlock();
    state = AsyncValue.data(user);
  }

  /// Soumet un dossier KYC (lot C3). Met a jour l'etat avec le profil renvoye
  /// (statut SUBMITTED). Retourne un message d'erreur, ou `null` si succes.
  Future<String?> submitKyc({
    required int requestedTier,
    String? idCardFrontPath,
    String? idCardBackPath,
    String? selfiePath,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.submitKyc(
      requestedTier: requestedTier,
      idCardFrontPath: idCardFrontPath,
      idCardBackPath: idCardBackPath,
      selfiePath: selfiePath,
    );
    return result.fold((failure) => failure.message, (user) {
      state = AsyncValue.data(user);
      return null;
    });
  }

  /// Reinitialise les providers de donnees liees a l'utilisateur courant.
  void _invalidateUserData() {
    ref.invalidate(dashboardNotifierProvider);
    ref.invalidate(transactionsNotifierProvider);
  }

  /// Etape 1 de l'inscription : envoie le code OTP a l'email. Retourne un
  /// message d'erreur, ou `null` si succes.
  Future<String?> sendOtp(String email) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.sendOtp(email);
    return result.fold((failure) => failure.message, (_) => null);
  }

  /// Reinitialisation (etape 1) : demande un code par email (lot A5).
  /// Retourne un message d'erreur, ou `null` si succes.
  Future<String?> requestPasswordReset(String identifier) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.requestPasswordReset(identifier);
    return result.fold((failure) => failure.message, (_) => null);
  }

  /// Reinitialisation (etape 2) : verifie l'OTP et applique le nouveau mot de
  /// passe (lot A5). Retourne un message d'erreur, ou `null` si succes.
  Future<String?> confirmPasswordReset({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.confirmPasswordReset(
      identifier: identifier,
      otp: otp,
      newPassword: newPassword,
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  /// Inscription (etape 2). Retourne un message d'erreur, ou `null` si succes.
  /// N'authentifie pas automatiquement (compte en attente de validation KYC).
  Future<String?> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String otp,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.register(
      username: username,
      email: email,
      password: password,
      passwordConfirm: passwordConfirm,
      phoneNumber: phoneNumber,
      firstName: firstName,
      lastName: lastName,
      otp: otp,
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  /// Configure le code PIN. Retourne un message d'erreur, ou `null` si succes.
  /// En cas de succes, l'etat passe a `hasPin = true` (le JWT courant porte
  /// encore `has_pin=false` mais sera rafraichi au prochain login).
  Future<String?> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.setupPin(
      password: password,
      pin: pin,
      pinConfirm: pinConfirm,
    );
    return result.fold((failure) => failure.message, (_) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(hasPin: true));
      }
      // Le PIN vient d'etre cree apres saisie du mot de passe -> deverrouille.
      ref.read(appLockProvider.notifier).unlock();
      return null;
    });
  }

  /// Verifie le code PIN (verrou app, et bientot chaque operation).
  /// Retourne `(error, token)` : `error` non nul si echec, sinon `token`
  /// porte le `pin_token` temporaire (~5 min).
  Future<({String? error, String? token})> verifyPin(String pin) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyPin(pin);
    return result.fold(
      (failure) => (error: failure.message, token: null),
      (token) => (error: null, token: token),
    );
  }

  /// Connexion par empreinte (palier P1). Les jetons sont persistes par le
  /// repository biometrique ; on charge ensuite le profil comme un login
  /// classique. Retourne un message d'erreur, ou `null` si succes.
  Future<String?> loginWithBiometric() async {
    final bio = ref.read(biometricRepositoryProvider);
    final result = await bio.loginWithBiometric();
    return result.fold(
      (failure) async {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (_) async {
        final profile = await ref.read(authRepositoryProvider).getProfile();
        return profile.fold(
          (failure) {
            state = const AsyncValue.data(null);
            return failure.message;
          },
          (user) {
            _invalidateUserData();
            ref.read(appLockProvider.notifier).unlock();
            state = AsyncValue.data(user);
            return null;
          },
        );
      },
    );
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    _invalidateUserData();
    ref.read(appLockProvider.notifier).lock();
    state = const AsyncValue.data(null);
  }

  /// Appele par l'intercepteur quand le refresh echoue (session expiree).
  void onExpired() {
    _invalidateUserData();
    ref.read(appLockProvider.notifier).lock();
    state = const AsyncValue.data(null);
  }
}
