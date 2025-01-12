import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Applies general gesture settings to the provided MapboxMap instance.
void applyMapGestures(MapboxMap mapboxMap) {
  mapboxMap.gestures.updateSettings(
    GesturesSettings(
      pinchToZoomEnabled: true,
      quickZoomEnabled: true,
      scrollEnabled: true,
    ),
  );
}