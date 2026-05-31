import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/config/routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SicMobileApp(),
    ),
  );
}

/// SIC Mobile Application
class SicMobileApp extends ConsumerWidget {
  const SicMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SIC Mobile',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: SicTheme.lightTheme,
      darkTheme: SicTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Router
      routerConfig: router,
    );
  }
}