import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:sic_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sic_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:sic_mobile/features/transactions/domain/entities/agent_transaction.dart';
import 'package:sic_mobile/features/transactions/presentation/providers/transaction_providers.dart';

// Une connexion reussie invalide les providers de donnees (dashboard/historique).
// En test, on les neutralise pour ne pas tirer le reseau natif : leur build
// echoue (AsyncError), ce qui suffit, le test ne verifie que l'etat d'auth.
class _StubDashboard extends DashboardNotifier {
  @override
  Future<AgentSummary> build() async => throw 'stub';
}

class _StubTransactions extends TransactionsNotifier {
  @override
  Future<List<AgentTransaction>> build() async => const [];
}

List<Override> get _dataStubs => [
      dashboardNotifierProvider.overrideWith(_StubDashboard.new),
      transactionsNotifierProvider.overrideWith(_StubTransactions.new),
    ];

const _user = AuthUser(
  id: '1',
  firstName: 'M',
  lastName: 'K',
  phoneNumber: '70123456',
  email: 'a@b.com',
  kycStatus: 'PENDING',
  isSuspended: false,
  hasPin: true,
);

/// Repo de test : le login exige une verification d'appareil, la verification
/// reussit si l'OTP vaut '123456'.
class _FakeAuthRepository implements AuthRepository {
  String? lastOtp;

  @override
  Future<Either<Failure, AuthUser>> login(String u, String p) async =>
      const Left(DeviceVerificationFailure('a***b@b.com'));

  @override
  Future<Either<Failure, AuthUser>> verifyDevice({
    required String identifier,
    required String password,
    required String otp,
  }) async {
    lastOtp = otp;
    return otp == '123456'
        ? const Right(_user)
        : const Left(ValidationFailure('Code de verification invalide.'));
  }

  @override
  Future<bool> hasSession() async => false;

  @override
  Future<Either<Failure, AuthUser>> getProfile() async => const Right(_user);

  @override
  Future<Either<Failure, AuthUser>> submitKyc({
    required int requestedTier,
    String? idCardFrontPath,
    String? idCardBackPath,
    String? selfiePath,
  }) async =>
      const Right(_user);

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
  test('login sur nouvel appareil : remonte deviceEmail, pas d\'erreur',
      () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo), ..._dataStubs],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final result = await container
        .read(authControllerProvider.notifier)
        .login('70123456', 'pw');

    expect(result.error, isNull);
    expect(result.deviceEmail, 'a***b@b.com');
    // Toujours deconnecte tant que l'appareil n'est pas verifie.
    expect(container.read(authControllerProvider).value, isNull);
  });

  test('verifyDevice avec bon OTP : connecte', () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo), ..._dataStubs],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final error = await container
        .read(authControllerProvider.notifier)
        .verifyDevice(identifier: '70123456', password: 'pw', otp: '123456');

    expect(error, isNull);
    expect(repo.lastOtp, '123456');
    expect(container.read(authControllerProvider).value, _user);
  });

  test('verifyDevice avec mauvais OTP : message d\'erreur, reste deconnecte',
      () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo), ..._dataStubs],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final error = await container
        .read(authControllerProvider.notifier)
        .verifyDevice(identifier: '70123456', password: 'pw', otp: '000000');

    expect(error, 'Code de verification invalide.');
    expect(container.read(authControllerProvider).value, isNull);
  });
}
