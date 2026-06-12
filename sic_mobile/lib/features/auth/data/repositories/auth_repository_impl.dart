import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_failure.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource, this._storage);

  final AuthRemoteDatasource _datasource;
  final TokenStorage _storage;

  @override
  Future<Either<Failure, AuthUser>> login(
    String username,
    String password,
  ) async {
    try {
      final tokens = await _datasource.login(username, password);
      await _storage.saveTokens(
        access: tokens.access,
        refresh: tokens.refresh,
      );
      final profile = await _datasource.getProfile();
      return Right(profile);
    } catch (error) {
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
  Future<Either<Failure, Unit>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
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
      );
      return const Right(unit);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> getProfile() async {
    try {
      return Right(await _datasource.getProfile());
    } catch (error) {
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
