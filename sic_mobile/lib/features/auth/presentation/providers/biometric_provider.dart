import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/services/biometric_service.dart';
import '../../data/datasources/biometric_remote_datasource.dart';
import '../../data/repositories/biometric_repository_impl.dart';
import '../../domain/repositories/biometric_repository.dart';

/// Capteur biometrique natif (cle materielle + signature + invite).
final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => BiometricService(),
);

final biometricRemoteDatasourceProvider =
    Provider<BiometricRemoteDatasource>(
  (ref) => BiometricRemoteDatasource(ref.watch(dioProvider)),
);

final biometricRepositoryProvider = Provider<BiometricRepository>(
  (ref) => BiometricRepositoryImpl(
    ref.watch(biometricAuthenticatorProvider),
    ref.watch(biometricRemoteDatasourceProvider),
    ref.watch(tokenStorageProvider),
  ),
);
