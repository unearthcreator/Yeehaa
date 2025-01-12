import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/services/app_routes.dart'; // Extracted routes
import 'package:map_mvp_project/styles/theme.dart'; // Extracted theme
import 'package:map_mvp_project/l10n/app_localizations.dart'; // Use existing localization configuration
import 'package:map_mvp_project/providers/locale_provider.dart';

/// The root widget of the application.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for lifecycle monitoring
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Log lifecycle changes for debugging or analytics
    logger.i('App lifecycle state changed: $state');
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentLocale = ref.watch(localeProvider);

        try {
          return MaterialApp(
            title: 'Map MVP Project',
            theme: appTheme(),
            initialRoute: '/',
            routes: appRoutes,
            debugShowCheckedModeBanner: !kReleaseMode, // Hide debug banner in production
            locale: currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        } catch (e, stackTrace) {
          logger.e(
            'Error while building MyApp widget. Current Locale: $currentLocale, Initial Route: /',
            error: e,
            stackTrace: stackTrace,
          );

          // Fallback UI in case of errors
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(
                  'Something went wrong. Please restart the app.',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer on dispose
    super.dispose();
  }
}