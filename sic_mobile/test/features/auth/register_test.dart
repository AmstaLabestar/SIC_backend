import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:sic_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sic_mobile/features/auth/presentation/providers/auth_provider.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.registerFailure});

  final Failure? registerFailure;
  Map<String, String>? lastRegister;

  @override
  Future<Either<Failure, Unit>> sendOtp(String email) async => const Right(unit);

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
  }) async {
    lastRegister = {
      'username': username,
      'phone': phoneNumber,
      'otp': otp,
    };
    return registerFailure != null ? Left(registerFailure!) : const Right(unit);
  }

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
  Future<Either<Failure, Unit>> logout() async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, String>> verifyPin(String pin) async =>
      const Right('pin-token');

  @override
  Future<bool> hasSession() async => false;
}

void main() {
  test('register : succes -> null, l\'etat reste deconnecte', () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    // build() initial (pas de session) -> null
    await container.read(authControllerProvider.future);

    final error = await container.read(authControllerProvider.notifier).register(
          username: 'agent_test',
          email: 'a@b.com',
          password: 'password123',
          passwordConfirm: 'password123',
          phoneNumber: '70123456',
          firstName: 'M',
          lastName: 'K',
          otp: '123456',
        );

    expect(error, isNull);
    expect(repo.lastRegister?['username'], 'agent_test');
    expect(container.read(authControllerProvider).value, isNull);
  });

  test('register : echec -> message d\'erreur', () async {
    final repo = _FakeAuthRepository(
      registerFailure: const ValidationFailure('Ce numero est deja utilise.'),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final error = await container.read(authControllerProvider.notifier).register(
          username: 'agent_test',
          email: 'a@b.com',
          password: 'password123',
          passwordConfirm: 'password123',
          phoneNumber: '70123456',
          firstName: 'M',
          lastName: 'K',
          otp: '123456',
        );

    expect(error, 'Ce numero est deja utilise.');
  });
}
