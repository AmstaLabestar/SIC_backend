import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sic_mobile/config/theme.dart';

// Splash Screen
import 'package:sic_mobile/shared/widgets/splash_screen.dart';

// Auth Screens
import 'package:sic_mobile/features/auth/screens/auth_screens.dart';
import 'package:sic_mobile/features/auth/screens/register_screen.dart';
import 'package:sic_mobile/features/auth/screens/biometric_setup_screen.dart';

// Home Screens
import 'package:sic_mobile/features/home/screens/home_screen.dart';

// Transaction Screens
import 'package:sic_mobile/features/transactions/screens/transaction_screens.dart';
import 'package:sic_mobile/features/transactions/screens/conversion_screen.dart';
import 'package:sic_mobile/features/transactions/screens/transaction_detail_screen.dart';

// Puce Screens
import 'package:sic_mobile/features/puces/screens/puce_screens.dart';

// Profile Screens
import 'package:sic_mobile/features/profile/screens/profile_screens.dart';
import 'package:sic_mobile/features/profile/screens/security_screen.dart';
import 'package:sic_mobile/features/profile/screens/kyc_upload_screen.dart';

/// GoRouter configuration for SIC Mobile
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      // Auth Routes
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthPlaceholder(),
        routes: [
          GoRoute(
            path: 'login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'register',
            name: 'register',
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: 'pin-setup',
            name: 'pin-setup',
            builder: (context, state) => const PinSetupScreen(),
          ),
        ],
      ),
      // Main Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/transactions',
            name: 'transactions',
            builder: (context, state) => const TransactionHistoryScreen(),
            routes: [
              GoRoute(
                path: 'deposit',
                name: 'deposit',
                builder: (context, state) => const DepositScreen(),
              ),
              GoRoute(
                path: 'withdraw',
                name: 'withdraw',
                builder: (context, state) => const WithdrawScreen(),
              ),
              GoRoute(
                path: 'conversion',
                name: 'conversion',
                builder: (context, state) => const ConversionScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'transaction-detail',
                builder: (context, state) => TransactionDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/puces',
            name: 'puces',
            builder: (context, state) => const PucesListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-puce',
                builder: (context, state) => const AddPuceScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'security',
                name: 'security',
                builder: (context, state) => const SecurityScreen(),
              ),
              GoRoute(
                path: 'kyc',
                name: 'kyc',
                builder: (context, state) => const KycUploadScreen(),
              ),
            ],
          ),
        ],
      ),
      // Notifications
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page non trouvée',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Navigation Keys
class NavKeys {
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();
}

// ============================================================================
// MAIN SHELL - Bottom Navigation
// ============================================================================

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sim_card_outlined),
            activeIcon: Icon(Icons.sim_card),
            label: 'Puces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/puces')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/transactions');
        break;
      case 2:
        context.go('/puces');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}

// ============================================================================
// PLACEHOLDER SCREENS
// ============================================================================

class AuthPlaceholder extends StatelessWidget {
  const AuthPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Auth')));
  }
}

class RegisterPlaceholder extends StatelessWidget {
  const RegisterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: const Center(child: Text('Inscription - À implémenter')),
    );
  }
}