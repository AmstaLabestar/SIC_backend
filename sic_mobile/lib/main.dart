import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/app_globals.dart';
import 'core/constants/app_theme.dart';
import 'core/preferences/privacy_provider.dart';
import 'core/realtime/realtime_provider.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/providers/app_lock_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  await Hive.initFlutter();
  // Preferences applicatives locales (confidentialite des soldes, etc.).
  await Hive.openBox(appPrefsBox);

  // Monitoring d'erreurs : actif uniquement si un DSN est fourni dans .env.
  // Sans DSN (dev par defaut), on demarre l'app normalement (aucun surcout).
  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (sentryDsn.isEmpty) {
    runApp(const ProviderScope(child: SicMobileApp()));
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.environment = dotenv.env['SENTRY_ENVIRONMENT'] ??
          (kReleaseMode ? 'production' : 'development');
      options.tracesSampleRate =
          double.tryParse(dotenv.env['SENTRY_TRACES_SAMPLE_RATE'] ?? '') ?? 0.0;
      // Fintech : ne pas transmettre d'informations personnelles par defaut.
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(const ProviderScope(child: SicMobileApp())),
  );
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
    final realtime = ref.read(realtimeServiceProvider);
    switch (state) {
      case AppLifecycleState.paused:
        // App en arriere-plan : on memorise l'instant pour reverrouiller plus
        // tard si l'absence se prolonge, et on coupe le temps reel.
        lock.onPaused();
        realtime.stop();
      case AppLifecycleState.resumed:
        lock.onResumed();
        // Retour au premier plan : reconnexion (+ re-sync) si connecte.
        if (ref.read(authControllerProvider).valueOrNull != null) {
          realtime.start();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Pilote le temps reel selon l'etat d'authentification : connexion au login,
    // coupure au logout / expiration de session.
    ref.listen(authControllerProvider, (previous, next) {
      final realtime = ref.read(realtimeServiceProvider);
      if (next.valueOrNull != null) {
        realtime.start();
      } else {
        realtime.stop();
      }
    });

    return MaterialApp.router(
      title: 'SIC Mobile',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
