import 'package:flutter/material.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:map_mvp_project/repositories/local_worlds_repository.dart';
import 'package:map_mvp_project/models/world_config.dart';
import 'package:map_mvp_project/repositories/local_app_preferences.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/widgets/toggle_row.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/widgets/back_button.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/widgets/world_name_input_field.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/widgets/theme_dropdown.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/widgets/theme_preview.dart';

class EarthCreatorPage extends StatefulWidget {
  final int carouselIndex;

  const EarthCreatorPage({Key? key, required this.carouselIndex}) : super(key: key);

  @override
  State<EarthCreatorPage> createState() => _EarthCreatorPageState();
}

class _EarthCreatorPageState extends State<EarthCreatorPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSatellite = false;
  bool _adjustAfterTime = false;
  String _selectedTheme = 'Day';

  late LocalWorldsRepository _worldConfigsRepo;

  @override
  void initState() {
    super.initState();
    logger.i('EarthCreatorPage initState; carouselIndex = ${widget.carouselIndex}');
    _worldConfigsRepo = LocalWorldsRepository();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _determineTimeBracket() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 7) return 'Dawn';
    if (hour >= 7 && hour < 17) return 'Day';
    if (hour >= 17 && hour < 20) return 'Dusk';
    return 'Night';
  }

  String get _currentBracket {
    return _adjustAfterTime ? _determineTimeBracket() : _selectedTheme;
  }

  String get _themeImagePath {
    final bracket = _currentBracket;
    return _isSatellite
        ? 'assets/earth_snapshot/Satellite-$bracket.png'
        : 'assets/earth_snapshot/$bracket.png';
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();

    if (!RegExp(r"^[a-zA-Z0-9\s]{3,20}$").hasMatch(name)) {
      _showNameErrorDialog();
      return;
    }

    final bracket = _currentBracket;
    final mapType = _isSatellite ? 'satellite' : 'standard';
    final timeMode = _adjustAfterTime ? 'auto' : 'manual';
    final manualTheme = timeMode == 'manual' ? bracket : null;

    final worldId = const Uuid().v4();

    final newWorldConfig = WorldConfig(
      id: worldId,
      name: name,
      mapType: mapType,
      timeMode: timeMode,
      manualTheme: manualTheme,
      carouselIndex: widget.carouselIndex,
    );

    try {
      await _worldConfigsRepo.addWorldConfig(newWorldConfig);
      logger.i('Saved new WorldConfig with ID=$worldId: $newWorldConfig');
      await LocalAppPreferences.setLastUsedCarouselIndex(widget.carouselIndex);
      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      logger.e('Error saving new WorldConfig', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: failed to save world config')),
      );
    }
  }

  void _showNameErrorDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Invalid Title'),
          content: const Text('World Name must be between 3 and 20 characters.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    logger.i('Building EarthCreatorPage');

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            BackButtonWidget(),
            WorldNameInputField(controller: _nameController),
            Positioned(
              top: 60.0,
              right: 16.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ToggleRow(
                    label: _isSatellite ? 'Satellite' : 'Standard',
                    value: _isSatellite,
                    onChanged: (newVal) {
                      setState(() => _isSatellite = newVal);
                      logger.i('Map type toggled -> ${_isSatellite ? "Satellite" : "Standard"}');
                    },
                  ),
                  ToggleRow(
                    label: _adjustAfterTime ? 'Style follows time' : 'Choose own style',
                    value: _adjustAfterTime,
                    onChanged: (newVal) {
                      setState(() => _adjustAfterTime = newVal);
                      logger.i('Adjust after time toggled -> $_adjustAfterTime');
                    },
                  ),
                ],
              ),
            ),
            if (!_adjustAfterTime)
              Positioned(
                top: 140.0,
                right: 16.0,
                child: ThemeDropdown(
                  selectedTheme: _selectedTheme,
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() => _selectedTheme = newValue);
                      logger.i('User selected theme: $newValue');
                    }
                  },
                ),
              ),
            Positioned(
              top: (screenHeight - screenHeight * 0.4) / 2,
              left: (screenWidth - screenWidth * 0.4) / 2,
              child: ThemePreviewWidget(imagePath: _themeImagePath),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Center(
                child: ElevatedButton(
                  onPressed: _handleSave,
                  child: const Text('Save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}