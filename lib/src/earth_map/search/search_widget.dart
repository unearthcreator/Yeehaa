import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/services/error_handler.dart';  // for logger
import 'package:map_mvp_project/services/geocoding_service.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/gestures/map_gesture_handler.dart';

class EarthMapSearchWidget extends StatefulWidget {
  final MapboxMap? mapboxMap;
  final MapAnnotationsManager annotationsManager;
  final MapGestureHandler gestureHandler;
  final LocalAnnotationsRepository localRepo;
  final Uuid uuid;

  const EarthMapSearchWidget({
    Key? key,
    required this.mapboxMap,
    required this.annotationsManager,
    required this.gestureHandler,
    required this.localRepo,
    required this.uuid,
  }) : super(key: key);

  @override
  _EarthMapSearchWidgetState createState() => _EarthMapSearchWidgetState();
}

class _EarthMapSearchWidgetState extends State<EarthMapSearchWidget> {
  bool _showSearchBar = false;  
  final TextEditingController _addressController = TextEditingController();
  List<String> _suggestions = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Debounce the user's typing to fetch suggestions.
  void _onAddressChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final query = _addressController.text.trim();
      if (query.isNotEmpty) {
        final suggestions = await GeocodingService.fetchAddressSuggestions(query);
        setState(() {
          _suggestions = suggestions;
        });
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    });
  }

  /// The always-visible button (top-left). Tapping toggles the search bar.
  Widget _buildSearchToggleButton() {
    return Positioned(
      top: 40,
      left: 10,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(8),
        ),
        onPressed: () {
          setState(() {
            _showSearchBar = !_showSearchBar;
            if (!_showSearchBar) {
              _suggestions.clear();
            }
          });
        },
        child: const Icon(Icons.search),
      ),
    );
  }

  /// The search bar (TextField + suggestions), shown if _showSearchBar == true.
  Widget _buildSearchBar() {
    if (!_showSearchBar) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 140,
      left: 10,
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Container for text field & search button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      hintText: 'Enter address',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSearchPressed,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          // Suggestions dropdown
          if (_suggestions.isNotEmpty)
            Container(
              width: 250,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _suggestions.map((s) {
                  return InkWell(
                    onTap: () {
                      _addressController.text = s;
                      _suggestions.clear();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(s),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// Called when the user presses "Search."
  Future<void> _onSearchPressed() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    if (widget.mapboxMap == null) return;

    final coords = await GeocodingService.fetchCoordinatesFromAddress(address);
    if (coords != null) {
      logger.i('Coordinates received: $coords');
      final lat = coords['lat']!;
      final lng = coords['lng']!;

      final geometry = Point(coordinates: Position(lng, lat));
      final bytes = await rootBundle.load('assets/icons/cross.png');
      final imageData = bytes.buffer.asUint8List();

      // Create a new Hive annotation
      final annotationId = widget.uuid.v4();
      final annotation = Annotation(
        id: annotationId,
        title: address.isNotEmpty ? address : null,
        iconName: "cross",
        startDate: null,
        endDate: null,
        note: null,
        latitude: lat,
        longitude: lng,
        imagePath: null,
      );

      // Add to Hive
      await widget.localRepo.addAnnotation(annotation);
      logger.i('Searched annotation saved to Hive with id: $annotationId');

      // Place on the map
      final mapAnnotation = await widget.annotationsManager.addAnnotation(
        geometry,
        image: imageData,
        title: annotation.title ?? '',
        date: annotation.startDate ?? '',
      );
      logger.i('Annotation placed at searched location. Mapbox ID: ${mapAnnotation.id}');

      // **IMPORTANT**: Link the Mapbox annotation ID to the Hive ID
      widget.gestureHandler.annotationIdLinker.registerAnnotationId(
        mapAnnotation.id,
        annotationId,
      );

      // Move camera
      await widget.mapboxMap!.setCamera(
        CameraOptions(
          center: geometry,
          zoom: 14.0,
        ),
      );
    } else {
      logger.w('No coordinates found for the given address.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No coordinates found for the given address.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Just a debug print to see if the widget rebuilds
    print('EarthMapSearchWidget build() is running...');

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          _buildSearchToggleButton(), 
          _buildSearchBar(),
        ],
      ),
    );
  }
}