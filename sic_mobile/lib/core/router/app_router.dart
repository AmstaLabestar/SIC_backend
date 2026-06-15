import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/auth/presentation/providers/app_lock_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/device_verify_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/lock_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/pin_setup_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
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
  // Le verrou app fait aussi partie de l'etat de navigation.
  ref.listen(appLockProvider, (_, __) => refresh.value++);

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

      final user = auth.value;
      final isLoggedIn = user != null;
      final onAuthScreen = location == '/login' ||
          location == '/register' ||
          location == '/splash';

      if (!isLoggedIn) {
        const loggedOutOk = {
          '/login',
          '/register',
          '/verify-device',
          '/forgot-password',
        };
        return loggedOutOk.contains(location) ? null : '/login';
      }
      // Connecte mais sans code PIN -> creation obligatoire avant tout acces.
      if (!user.hasPin) {
        return location == '/pin-setup' ? null : '/pin-setup';
      }
      // Connecte + PIN configure mais app verrouillee -> ecran de deverrouillage
      // (ouverture a froid ou retour d'arriere-plan).
      final isUnlocked = ref.read(appLockProvider);
      if (!isUnlocked) {
        return location == '/lock' ? null : '/lock';
      }
      // App deverrouillee : les ecrans d'auth, de setup et de lock ne sont plus
      // accessibles.
      if (onAuthScreen || location == '/pin-setup' || location == '/lock') {
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
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-device',
        builder: (context, state) {
          final extra = (state.extra as Map?) ?? const {};
          return DeviceVerifyScreen(
            identifier: (extra['identifier'] as String?) ?? '',
            password: (extra['password'] as String?) ?? '',
            email: (extra['email'] as String?) ?? '',
          );
        },
      ),
      GoRoute(
        path: '/pin-setup',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
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
