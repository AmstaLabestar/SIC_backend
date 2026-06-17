import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:sic_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sic_mobile/features/auth/presentation/providers/auth_provider.dart';

const _submitted = AuthUser(
  id: '1',
  firstName: 'M',
  lastName: 'K',
  phoneNumber: '70123456',
  email: 'a@b.com',
  kycStatus: 'SUBMITTED',
  isSuspended: false,
  kycTier: 0,
  kycRequestedTier: 1,
  hasPin: true,
);

class _FakeAuthRepository implements AuthRepository {
  int? lastRequestedTier;
  Failure? submitFailure;

  @override
  Future<Either<Failure, AuthUser>> submitKyc({
    required int requestedTier,
    String? idCardFrontPath,
    String? idCardBackPath,
    String? selfiePath,
  }) async {
    lastRequestedTier = requestedTier;
    return submitFailure != null ? Left(submitFailure!) : const Right(_submitted);
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
  Future<Either<Failure, String?>> sendOtp(String email) async => const Right(null);

  @override
  Future<Either<Failure, Unit>> requestPasswordReset(String identifier) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> confirmPasswordReset({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async =>
      const Right(unit);

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

void main() {
  test('submitKyc succes : etat passe a SUBMITTED', () async {
    final repo = _FakeAuthRepository();
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    await c.read(authControllerProvider.future);

    final error = await c
        .read(authControllerProvider.notifier)
        .submitKyc(requestedTier: 1, idCardFrontPath: '/tmp/x.jpg');

    expect(error, isNull);
    expect(repo.lastRequestedTier, 1);
    final user = c.read(authControllerProvider).value;
    expect(user?.kycSubmitted, isTrue);
    expect(user?.kycRequestedTier, 1);
  });

  test('submitKyc echec : message d\'erreur', () async {
    final repo = _FakeAuthRepository()
      ..submitFailure = const ValidationFailure("Piece d'identite requise.");
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    await c.read(authControllerProvider.future);

    final error = await c
        .read(authControllerProvider.notifier)
        .submitKyc(requestedTier: 1);

    expect(error, "Piece d'identite requise.");
  });
}
