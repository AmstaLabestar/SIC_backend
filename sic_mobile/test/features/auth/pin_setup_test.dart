import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:sic_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sic_mobile/features/auth/presentation/providers/auth_provider.dart';

const _user = AuthUser(
  id: '1',
  firstName: 'M',
  lastName: 'K',
  phoneNumber: '70123456',
  email: 'a@b.com',
  kycStatus: 'APPROVED',
  isSuspended: false,
  hasPin: false,
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.setupFailure});

  final Failure? setupFailure;
  Map<String, String>? lastSetup;

  @override
  Future<Either<Failure, AuthUser>> login(String u, String p) async =>
      const Right(_user);

  // Session deja active : build() renverra _user directement, sans passer par
  // login() (qui invaliderait les providers dashboard/transactions et
  // toucherait le vrai reseau en test).
  @override
  Future<bool> hasSession() async => true;

  @override
  Future<Either<Failure, Unit>> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async {
    lastSetup = {'password': password, 'pin': pin, 'pin_confirm': pinConfirm};
    return setupFailure != null ? Left(setupFailure!) : const Right(unit);
  }

  @override
  Future<Either<Failure, AuthUser>> getProfile() async => const Right(_user);

  @override
  Future<Either<Failure, Unit>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> logout() async => const Right(unit);
}

void main() {
  test('setupPin succes : etat passe a hasPin=true', () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    expect(container.read(authControllerProvider).value?.hasPin, isFalse);

    final error =
        await container.read(authControllerProvider.notifier).setupPin(
              password: 'password123',
              pin: '1234',
              pinConfirm: '1234',
            );

    expect(error, isNull);
    expect(repo.lastSetup?['pin'], '1234');
    expect(container.read(authControllerProvider).value?.hasPin, isTrue);
  });

  test('setupPin echec : message d\'erreur, etat inchange', () async {
    final repo = _FakeAuthRepository(
      setupFailure: const ValidationFailure('Mot de passe incorrect.'),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final error =
        await container.read(authControllerProvider.notifier).setupPin(
              password: 'wrong',
              pin: '1234',
              pinConfirm: '1234',
            );

    expect(error, 'Mot de passe incorrect.');
    expect(container.read(authControllerProvider).value?.hasPin, isFalse);
  });
}
