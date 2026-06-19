import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/app_globals.dart';
import 'core/constants/app_theme.dart';
import 'core/preferences/privacy_provider.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/providers/app_lock_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  await Hive.initFlutter();
  // Preferences applicatives locales (confidentialite des soldes, etc.).
  await Hive.openBox(appPrefsBox);

  runApp(const ProviderScope(child: SicMobileApp()));
}

class SicMobileApp extends ConsumerStatefulWidget {
  const SicMobileApp({super.key});

  @override
  ConsumerState<SicMobileApp> createState() => _SicMobileAppState();
}

class _SicMobileAppState extends ConsumerState<SicMobileApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
        // App en arriere-plan : on memorise l'instant pour reverrouiller plus
        // tard si l'absence se prolonge.
        lock.onPaused();
      case AppLifecycleState.resumed:
        lock.onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SIC Mobile',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
