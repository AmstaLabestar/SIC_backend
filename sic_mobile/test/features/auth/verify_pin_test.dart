import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:sic_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sic_mobile/features/auth/presentation/providers/app_lock_provider.dart';
import 'package:sic_mobile/features/auth/presentation/providers/auth_provider.dart';

const _user = AuthUser(
  id: '1',
  firstName: 'M',
  lastName: 'K',
  phoneNumber: '70123456',
  email: 'a@b.com',
  kycStatus: 'APPROVED',
  isSuspended: false,
  hasPin: true,
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.verifyFailure});

  final Failure? verifyFailure;
  String? lastPin;

  @override
  Future<Either<Failure, String>> verifyPin(String pin) async {
    lastPin = pin;
    return verifyFailure != null ? Left(verifyFailure!) : const Right('tok-123');
  }

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<Either<Failure, AuthUser>> getProfile() async => const Right(_user);

  @override
  Future<Either<Failure, AuthUser>> login(String u, String p) async =>
      const Right(_user);

  @override
  Future<Either<Failure, Unit>> logout() async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> sendOtp(String email) async => const Right(unit);

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
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async =>
      const Right(unit);
}

void main() {
  test('verifyPin succes : retourne le token, pas d\'erreur', () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final result =
        await container.read(authControllerProvider.notifier).verifyPin('1234');

    expect(result.error, isNull);
    expect(result.token, 'tok-123');
    expect(repo.lastPin, '1234');
  });

  test('verifyPin echec : retourne le message, pas de token', () async {
    final repo = _FakeAuthRepository(
      verifyFailure: const ValidationFailure('Code PIN incorrect.'),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final result =
        await container.read(authControllerProvider.notifier).verifyPin('0000');

    expect(result.error, 'Code PIN incorrect.');
    expect(result.token, isNull);
  });

  test('logout reverrouille l\'app', () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    container.read(appLockProvider.notifier).unlock();
    expect(container.read(appLockProvider), isTrue);

    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(appLockProvider), isFalse);
  });
}
