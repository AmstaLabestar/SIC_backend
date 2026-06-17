// Verifie le routage pilote par le role (lot D1-2) : a /dashboard, un CLIENT
// atterrit sur l'accueil client, un AGENT sur le dashboard agent.
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/core/network/network_providers.dart';
import 'package:sic_mobile/core/storage/token_storage.dart';
import 'package:sic_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:sic_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sic_mobile/features/auth/presentation/providers/app_lock_provider.dart';
import 'package:sic_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:sic_mobile/features/transactions/domain/entities/agent_transaction.dart';
import 'package:sic_mobile/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:sic_mobile/main.dart';

AuthUser _user(String accountType) => AuthUser(
      id: '1',
      firstName: 'M',
      lastName: 'K',
      phoneNumber: '70123456',
      email: 'a@b.com',
      kycStatus: 'APPROVED',
      isSuspended: false,
      accountType: accountType,
      hasPin: true,
    );

class _EmptyTokenStorage extends TokenStorage {
  _EmptyTokenStorage() : super(const FlutterSecureStorage());
  @override
  Future<bool> hasSession() async => true;
}

/// Repo de test : session active, profil = role demande.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.accountType);
  final String accountType;

  @override
  Future<bool> hasSession() async => true;
  @override
  Future<Either<Failure, AuthUser>> getProfile() async =>
      Right(_user(accountType));
  @override
  Future<Either<Failure, AuthUser>> login(String u, String p) async =>
      Right(_user(accountType));
  @override
  Future<Either<Failure, AuthUser>> verifyDevice({
    required String identifier,
    required String password,
    required String otp,
  }) async =>
      Right(_user(accountType));
  @override
  Future<Either<Failure, String?>> sendOtp(String email) async =>
      const Right(null);
  @override
  Future<Either<Failure, Unit>> requestPasswordReset(String id) async =>
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
  Future<Either<Failure, AuthUser>> submitKyc({
    required int requestedTier,
    String? idCardFrontPath,
    String? idCardBackPath,
    String? selfiePath,
  }) async =>
      Right(_user(accountType));
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

class _UnlockedLock extends AppLockController {
  @override
  bool build() => true; // app deverrouillee
}

class _StubDashboard extends DashboardNotifier {
  @override
  Future<AgentSummary> build() async => throw 'stub';
}

class _StubTransactions extends TransactionsNotifier {
  @override
  Future<List<AgentTransaction>> build() async => const [];
}

Future<void> _pumpApp(WidgetTester tester, String accountType) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(_EmptyTokenStorage()),
        authRepositoryProvider
            .overrideWithValue(_FakeAuthRepository(accountType)),
        appLockProvider.overrideWith(_UnlockedLock.new),
        dashboardNotifierProvider.overrideWith(_StubDashboard.new),
        transactionsNotifierProvider.overrideWith(_StubTransactions.new),
      ],
      child: const SicMobileApp(),
    ),
  );
  // Splash -> verif session -> redirection /dashboard + animations.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('CLIENT -> accueil client', (tester) async {
    await _pumpApp(tester, 'CLIENT');
    expect(find.text('Compte SIC'), findsOneWidget); // marqueur ClientHomeScreen
  });

  testWidgets('AGENT -> dashboard agent (pas l\'accueil client)',
      (tester) async {
    await _pumpApp(tester, 'AGENT');
    expect(find.text('Compte SIC'), findsNothing);
  });
}
