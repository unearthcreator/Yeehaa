// map_state_manager.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/src/earth_map/gestures/initialize_map_gestures.dart';  // Import gesture functions to apply them on initialization

/// Manages the readiness state and setup of the map, including gestures and annotations.
class MapStateManager {
  final VoidCallback onMapReady;
  final MapboxMap mapboxMap;
  //final AnnotationManager annotationManager;

  MapStateManager({
    required this.onMapReady,
    required this.mapboxMap,
    //required this.annotationManager,
  }) {
    _initializeMap();
  }

  void _initializeMap() async {
    // Apply gesture settings to the map
    applyMapGestures(mapboxMap);

    // Initialize the annotation manager
    //await annotationManager.initializeAnnotationManager(mapboxMap);

    // Call onMapReady callback to notify that setup is complete
    onMapReady();
  }
}