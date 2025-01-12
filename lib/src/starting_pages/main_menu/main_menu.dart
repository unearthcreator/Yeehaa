import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/l10n/app_localizations.dart';
import 'package:map_mvp_project/src/starting_pages/main_menu/widgets/menu_button.dart';

class MainMenuPage extends ConsumerWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Building MainMenuPage');
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuButton(
              icon: Icons.public,
              label: loc.goToWorlds,
              onPressed: () {
                logger.i('Navigating to World Selector Page');
                Navigator.pushNamed(context, '/world_selector').catchError((error, stackTrace) {
                  logger.e('Failed to navigate to /world_selector', error: error, stackTrace: stackTrace);
                });
              },
            ),
            const SizedBox(height: 20),

            // Button 2: Options
            MenuButton(
              icon: Icons.settings,
              label: loc.options,
              onPressed: () {
                logger.i('Options button clicked');
                Navigator.pushNamed(context, '/options').catchError((error, stackTrace) {
                  logger.e('Failed to navigate to /options', error: error, stackTrace: stackTrace);
                });
              },
            ),
            const SizedBox(height: 20),

            // Button 3: Subscription
            MenuButton(
              icon: Icons.star,
              label: loc.subscription,
              onPressed: () {
                logger.i('Subscription button clicked');
                // Future: subscription logic
              },
            ),
            const SizedBox(height: 20),

            // Button 4: Exit
            MenuButton(
              icon: Icons.exit_to_app,
              label: loc.exit,
              onPressed: () {
                logger.i('Exit button clicked');
                // Future: exit logic (e.g., confirm before closing)
              },
            ),
          ],
        ),
      ),
    );
  }
}