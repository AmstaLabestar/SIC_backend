import 'dart:io' show Platform;

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_failure.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource, this._storage);

  final AuthRemoteDatasource _datasource;
  final TokenStorage _storage;

  /// Nom lisible de l'appareil (affiche dans la liste des appareils de confiance).
  String get _deviceName => Platform.operatingSystem;

  @override
  Future<Either<Failure, AuthUser>> login(
    String username,
    String password,
  ) async {
    try {
      final deviceId = await _storage.getOrCreateDeviceId();
      final tokens = await _datasource.login(
        username,
        password,
        deviceId: deviceId,
        deviceName: _deviceName,
      );
      await _storage.saveTokens(
        access: tokens.access,
        refresh: tokens.refresh,
      );
      final profile = await _datasource.getProfile();
      return Right(profile.copyWith(hasPin: jwtHasPin(tokens.access)));
    } catch (error) {
      // Nouvel appareil (lot A4) : le backend renvoie 403 + un OTP par email.
      if (error is DioException && error.response?.statusCode == 403) {
        final data = error.response?.data;
        if (data is Map && data['device_verification_required'] == true) {
          return Left(
            DeviceVerificationFailure((data['email'] as String?) ?? ''),
          );
        }
      }
      // Sur le login, un 401 signifie "identifiants incorrects",
      // pas "session expiree".
      if (error is DioException && error.response?.statusCode == 401) {
        return const Left(
          ValidationFailure(
            'Identifiants incorrects. Verifiez votre identifiant et votre mot de passe.',
          ),
        );
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> verifyDevice({
    required String identifier,
    required String password,
    required String otp,
  }) async {
    try {
      final deviceId = await _storage.getOrCreateDeviceId();
      final tokens = await _datasource.verifyDevice(
        identifier: identifier,
        password: password,
        otp: otp,
        deviceId: deviceId,
        deviceName: _deviceName,
      );
      await _storage.saveTokens(
        access: tokens.access,
        refresh: tokens.refresh,
      );
      final profile = await _datasource.getProfile();
      return Right(profile.copyWith(hasPin: jwtHasPin(tokens.access)));
    } catch (error) {
      if (error is DioException) {
        final code = error.response?.statusCode;
        if (code == 400) {
          // OTP invalide : le backend renvoie {'otp': ['...']}.
          final data = error.response?.data;
          String? msg;
          if (data is Map && data['otp'] is List && (data['otp'] as List).isNotEmpty) {
            msg = (data['otp'] as List).first.toString();
          }
          return Left(ValidationFailure(msg ?? 'Code de verification invalide.'));
        }
        if (code == 401) {
          return const Left(
            ValidationFailure('Identifiants incorrects.'),
          );
        }
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendOtp(String email) async {
    try {
      await _datasource.sendOtp(email);
      return const Right(unit);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> requestPasswordReset(String identifier) async {
    try {
      await _datasource.requestPasswordReset(identifier);
      return const Right(unit);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> confirmPasswordReset({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _datasource.confirmPasswordReset(
        identifier: identifier,
        otp: otp,
        newPassword: newPassword,
      );
      return const Right(unit);
    } catch (error) {
      // 400 = OTP invalide ({'otp': [...]}) ou mot de passe faible
      // ({'new_password': [...]}). On restitue un message lisible.
      if (error is DioException && error.response?.statusCode == 400) {
        final data = error.response?.data;
        if (data is Map) {
          for (final key in ['otp', 'new_password', 'error']) {
            final v = data[key];
            if (v is List && v.isNotEmpty) return Left(ValidationFailure(v.first.toString()));
            if (v is String) return Left(ValidationFailure(v));
          }
        }
        return const Left(ValidationFailure('Code invalide ou mot de passe trop faible.'));
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String otp,
    required String accountType,
    String merchantCode = '',
  }) async {
    try {
      await _datasource.register(
        username: username,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
        otp: otp,
        accountType: accountType,
        merchantCode: merchantCode,
      );
      return const Right(unit);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> submitKyc({
    required int requestedTier,
    String? idCardFrontPath,
    String? idCardBackPath,
    String? selfiePath,
  }) async {
    try {
      final profile = await _datasource.submitKyc(
        requestedTier: requestedTier,
        idCardFrontPath: idCardFrontPath,
        idCardBackPath: idCardBackPath,
        selfiePath: selfiePath,
      );
      // `/kyc/submit/` ne renvoie pas `has_pin` : on le lit dans le JWT courant.
      final access = await _storage.readAccess();
      return Right(profile.copyWith(hasPin: jwtHasPin(access)));
    } catch (error) {
      // 400 = validation (palier/documents) : restituer le message lisible.
      if (error is DioException && error.response?.statusCode == 400) {
        final data = error.response?.data;
        if (data is Map) {
          for (final v in data.values) {
            if (v is List && v.isNotEmpty) return Left(ValidationFailure(v.first.toString()));
            if (v is String) return Left(ValidationFailure(v));
          }
        }
        return const Left(ValidationFailure('Dossier KYC invalide.'));
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> getProfile() async {
    try {
      final profile = await _datasource.getProfile();
      // `/auth/profile/` ne renvoie pas `has_pin` : on le lit dans le JWT.
      final access = await _storage.readAccess();
      return Right(profile.copyWith(hasPin: jwtHasPin(access)));
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async {
    try {
      await _datasource.setupPin(
        password: password,
        pin: pin,
        pinConfirm: pinConfirm,
      );
      return const Right(unit);
    } catch (error) {
      // Le backend renvoie 403 "Mot de passe incorrect." : le mapping generique
      // le masquerait en "Acces refuse", on le restitue ici.
      if (error is DioException && error.response?.statusCode == 403) {
        return const Left(ValidationFailure('Mot de passe incorrect.'));
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, String>> verifyPin(String pin) async {
    try {
      final token = await _datasource.verifyPin(pin);
      return Right(token);
    } catch (error) {
      // 401 = PIN incorrect, 429 = compte verrouille : le backend renvoie un
      // message explicite (tentatives restantes / duree) qu'on restitue tel quel.
      if (error is DioException) {
        final code = error.response?.statusCode;
        if (code == 401 || code == 429 || code == 400) {
          final data = error.response?.data;
          final message = data is Map ? data['error'] as String? : null;
          return Left(
            ValidationFailure(message ?? 'Code PIN incorrect.'),
          );
        }
      }
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      final refresh = await _storage.readRefresh();
      if (refresh != null) {
        await _datasource.logout(refresh);
      }
      return const Right(unit);
    } catch (_) {
      // On ignore l'echec reseau : la session locale doit etre purgee.
      return const Right(unit);
    } finally {
      await _storage.clear();
    }
  }

  @override
  Future<bool> hasSession() => _storage.hasSession();
}
