import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/sim_management/presentation/screens/sim_management_screen.dart';
import '../../features/stats/presentation/screens/stats_screen.dart';
import '../../features/transactions/presentation/screens/money_operation_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/screens/transfer_screen.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Rafraichit la garde de route a chaque changement d'etat d'auth.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // Verification de session en cours -> ecran de splash.
      if (auth.isLoading || !auth.hasValue) {
        return location == '/splash' ? null : '/splash';
      }

      final isLoggedIn = auth.value != null;
      final onAuthScreen = location == '/login' || location == '/splash';

      if (!isLoggedIn) {
        return location == '/login' ? null : '/login';
      }
      if (onAuthScreen) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/operations/depot',
        builder: (context, state) =>
            const MoneyOperationScreen(isDeposit: true),
      ),
      GoRoute(
        path: '/operations/retrait',
        builder: (context, state) =>
            const MoneyOperationScreen(isDeposit: false),
      ),
      GoRoute(
        path: '/operations/transfert',
        builder: (context, state) => const TransferScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/compte',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: '/dashboard/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/dashboard/sims',
            builder: (context, state) => const SimManagementScreen(),
          ),
          GoRoute(
            path: '/dashboard/alerts',
            builder: (context, state) => const AlertsScreen(),
          ),
          GoRoute(
            path: '/dashboard/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
