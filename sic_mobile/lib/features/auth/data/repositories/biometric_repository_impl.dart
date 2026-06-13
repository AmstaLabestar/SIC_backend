import 'dart:io' show Platform;

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_failure.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/repositories/biometric_repository.dart';
import '../datasources/biometric_remote_datasource.dart';

class BiometricRepositoryImpl implements BiometricRepository {
  const BiometricRepositoryImpl(
    this._authenticator,
    this._datasource,
    this._storage,
  );

  final BiometricAuthenticator _authenticator;
  final BiometricRemoteDatasource _datasource;
  final TokenStorage _storage;

  @override
  Future<bool> isAvailable() => _authenticator.isAvailable();

  @override
  Future<bool> isEnabled() async {
    if (!await _storage.isBiometricEnabled()) return false;
    // La cle peut avoir ete invalidee par l'OS (nouvelle empreinte enrolee).
    return _authenticator.hasKeys();
  }

  @override
  Future<Either<Failure, Unit>> enable() async {
    if (!await _authenticator.isAvailable()) {
      return const Left(
        ValidationFailure(
          'Aucune biometrie configuree sur cet appareil. '
          'Ajoutez une empreinte ou un visage dans les reglages.',
        ),
      );
    }
    final publicKey = await _authenticator.createKeys();
    if (publicKey == null) {
      return const Left(ValidationFailure('Activation biometrique annulee.'));
    }
    try {
      final deviceId = await _storage.getOrCreateDeviceId();
      await _datasource.register(
        deviceId: deviceId,
        deviceName: _deviceName(),
        publicKey: publicKey,
      );
      await _storage.setBiometricEnabled(true);
      return const Right(unit);
    } catch (error) {
      // Enregistrement backend echoue -> on supprime les cles orphelines.
      await _authenticator.deleteKeys();
      if (error is DioException && error.response?.statusCode == 409) {
        return const Left(
          ValidationFailure(
            'Cet appareil est deja enregistre sur un autre compte.',
          ),
        );
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> loginWithBiometric() async {
    final deviceId = await _storage.getOrCreateDeviceId();
    // Timestamp en SECONDES (le backend reconstruit `deviceId:ts` sur cette base).
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = await _authenticator.sign('$deviceId:$timestamp');
    if (signature == null) {
      return const Left(ValidationFailure('Authentification annulee.'));
    }
    try {
      final tokens = await _datasource.login(
        deviceId: deviceId,
        signature: signature,
        timestamp: timestamp,
      );
      await _storage.saveTokens(
        access: tokens.access,
        refresh: tokens.refresh,
      );
      return const Right(unit);
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 401) {
        return const Left(
          ValidationFailure(
            'Connexion biometrique echouee. Reessayez ou utilisez votre mot de passe.',
          ),
        );
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<bool> unlock() =>
      _authenticator.prompt('Deverrouillez SIC avec votre empreinte');

  @override
  Future<void> disable() async {
    await _authenticator.deleteKeys();
    await _storage.setBiometricEnabled(false);
  }

  String _deviceName() {
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isAndroid) return 'Android';
    return 'Appareil';
  }
}
