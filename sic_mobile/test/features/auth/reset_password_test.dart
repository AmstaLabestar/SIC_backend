import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:sic_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sic_mobile/features/auth/presentation/providers/auth_provider.dart';

/// Repo de test : reset reussi si l'OTP vaut '123456'.
class _FakeAuthRepository implements AuthRepository {
  String? lastIdentifier;
  String? lastOtp;
  String? lastPassword;

  @override
  Future<Either<Failure, Unit>> requestPasswordReset(String identifier) async {
    lastIdentifier = identifier;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> confirmPasswordReset({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    lastOtp = otp;
    lastPassword = newPassword;
    return otp == '123456'
        ? const Right(unit)
        : const Left(ValidationFailure('Code incorrect.'));
  }

  @override
  Future<bool> hasSession() async => false;

  @override
  Future<Either<Failure, AuthUser>> login(String u, String p) async =>
      const Left(AuthFailure());

  @override
  Future<Either<Failure, AuthUser>> verifyDevice({
    required String identifier,
    required String password,
    required String otp,
  }) async =>
      const Left(AuthFailure());

  @override
  Future<Either<Failure, AuthUser>> getProfile() async =>
      const Left(AuthFailure());

  @override
  Future<Either<Failure, AuthUser>> submitKyc({
    required int requestedTier,
    String? idCardFrontPath,
    String? idCardBackPath,
    String? selfiePath,
  }) async =>
      const Left(AuthFailure());

  @override
  Future<Either<Failure, String?>> sendOtp(String email) async => const Right(null);

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
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, String>> verifyPin(String pin) async =>
      const Right('tok');

  @override
  Future<Either<Failure, Unit>> logout() async => const Right(unit);
}

ProviderContainer _container(_FakeAuthRepository repo) {
  final c = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('requestPasswordReset : succes -> null, identifiant transmis', () async {
    final repo = _FakeAuthRepository();
    final c = _container(repo);
    await c.read(authControllerProvider.future);

    final error = await c
        .read(authControllerProvider.notifier)
        .requestPasswordReset('70123456');

    expect(error, isNull);
    expect(repo.lastIdentifier, '70123456');
  });

  test('confirmPasswordReset : bon OTP -> null', () async {
    final repo = _FakeAuthRepository();
    final c = _container(repo);
    await c.read(authControllerProvider.future);

    final error =
        await c.read(authControllerProvider.notifier).confirmPasswordReset(
              identifier: '70123456',
              otp: '123456',
              newPassword: 'NewPassw0rd9',
            );

    expect(error, isNull);
    expect(repo.lastPassword, 'NewPassw0rd9');
  });

  test('confirmPasswordReset : mauvais OTP -> message d\'erreur', () async {
    final repo = _FakeAuthRepository();
    final c = _container(repo);
    await c.read(authControllerProvider.future);

    final error =
        await c.read(authControllerProvider.notifier).confirmPasswordReset(
              identifier: '70123456',
              otp: '000000',
              newPassword: 'NewPassw0rd9',
            );

    expect(error, 'Code incorrect.');
  });
}
