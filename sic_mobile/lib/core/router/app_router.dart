import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/sim_management/presentation/screens/sim_management_screen.dart';
import '../../features/stats/presentation/screens/stats_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/dashboard',
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
