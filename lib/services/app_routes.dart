// services/app_routes.dart

import 'package:flutter/material.dart';
import 'package:map_mvp_project/src/starting_pages/main_menu/main_menu.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/world_selector.dart';
import 'package:map_mvp_project/src/starting_pages/main_menu/options/options.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/earth_creator.dart';
import 'package:map_mvp_project/services/error_handler.dart';

/// A centralized map of all app routes for easy management and scaling.
final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const MainMenuPage(),
  '/world_selector': (context) => const WorldSelectorPage(),
  '/options': (context) => const OptionsPage(),

  // EarthCreator route expects an `int` as `arguments`, e.g. from:
  //   Navigator.pushNamed(context, '/earth_creator', arguments: someIndex);
  '/earth_creator': (context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is int) {
      return EarthCreatorPage(carouselIndex: args);
    } else {
      logger.w(
        'No valid carousel index passed to /earth_creator. Defaulting to 0.',
      );
      return const EarthCreatorPage(carouselIndex: 0);
    }
  },
};