import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // For direct Box usage if needed
import 'package:map_mvp_project/models/world_config.dart';
import 'package:map_mvp_project/repositories/local_worlds_repository.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/widgets/carousel.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/widgets/world_selector_buttons.dart';
import 'package:map_mvp_project/repositories/local_app_preferences.dart'; // For last-used index
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/earth_creator.dart';
import 'package:map_mvp_project/src/earth_map/earth_map_page.dart';

class WorldSelectorPage extends StatefulWidget {
  const WorldSelectorPage({super.key});

  @override
  State<WorldSelectorPage> createState() => _WorldSelectorPageState();
}

class _WorldSelectorPageState extends State<WorldSelectorPage> {
  late LocalWorldsRepository _worldsRepo;
  List<WorldConfig> _worldConfigs = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _carouselInitialIndex = 4;

  @override
  void initState() {
    super.initState();
    logger.i('WorldSelectorPage initState -> initializing');
    _worldsRepo = LocalWorldsRepository();

    _loadWorldsAndPreferences();
  }

  /// Combines fetching worlds and loading the last-used carousel index.
  Future<void> _loadWorldsAndPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch worlds
      final worlds = await _worldsRepo.getAllWorldConfigs();
      logger.i('Fetched ${worlds.length} worlds from Hive');
      _worldConfigs = worlds;

      // Load last-used index
      final lastIndex = await LocalAppPreferences.getLastUsedCarouselIndex();
      _carouselInitialIndex = lastIndex;
      logger.i('Loaded last-used carousel index: $lastIndex');
    } catch (e, stackTrace) {
      logger.e('Error loading worlds or preferences', error: e, stackTrace: stackTrace);
      setState(() => _errorMessage = 'Failed to load data. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleClearAllWorlds() async {
    try {
      await _worldsRepo.clearAllWorldConfigs();
      logger.i('Cleared all worlds from Hive.');
      await LocalAppPreferences.setLastUsedCarouselIndex(4);
      await _loadWorldsAndPreferences();
      _showSnackBar('All worlds cleared.');
    } catch (e, stackTrace) {
      logger.e('Error clearing all worlds', error: e, stackTrace: stackTrace);
      _showSnackBar('Failed to clear all worlds.');
    }
  }

  void _handleCardTap(int index) {
    final world = _worldConfigs.firstWhere(
      (w) => w.carouselIndex == index,
      orElse: () => WorldConfig.defaultConfig(index),
    );

    if (world.name.isEmpty) {
      logger.i('Navigating to EarthCreatorPage for index $index');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EarthCreatorPage(carouselIndex: index),
        ),
      ).then((didSave) async {
        if (didSave == true) {
          logger.i('User created a new world. Reloading data.');
          await _loadWorldsAndPreferences();
        }
      });
    } else {
      logger.i('Navigating to EarthMapPage for world: ${world.name}');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EarthMapPage(worldConfig: world),
        ),
      );
    }
  }

  /// Displays a snackbar message.
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 56 - 40;
    logger.d('ScreenHeight=$screenHeight, availableHeight=$availableHeight');

    return Scaffold(
      body: Column(
        children: [
          WorldSelectorButtons(
            onClearAll: _handleClearAllWorlds,
          ),
          Expanded(
            child: Center(
              child: CarouselWidget(
                key: ValueKey(_carouselInitialIndex),
                availableHeight: availableHeight,
                initialIndex: _carouselInitialIndex,
                worldConfigs: _worldConfigs,
                onCenteredCardTapped: _handleCardTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}