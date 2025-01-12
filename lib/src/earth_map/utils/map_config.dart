// map_config.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Contains various style URIs and default configurations for Mapbox maps
/// used throughout the app.
class MapConfig {
  /// Style for your "Earth" page (existing style).
  static const String styleUriEarth = 
      "https://api.mapbox.com/styles/v1/unearthcreator/cm2jwm74e004j01ny7osa5ve8?access_token=pk.eyJ1IjoidW5lYXJ0aGNyZWF0b3IiLCJhIjoiY20yam4yODlrMDVwbzJrcjE5cW9vcDJmbiJ9.L2tmRAkt0jKLd8-fWaMWfA";

  /// Style for the "Default Globe" or the new globe style you want in EarthCreator
  static const String styleUriGlobe = 
      "mapbox://styles/unearthcreator/cm59tvj11000t01sc8z2c3k0x";

  /// Default camera options, focusing on a wide area (zoom 1, near center of US)
  static CameraOptions defaultCameraOptions = CameraOptions(
    center: Point(coordinates: Position(-98.0, 39.5)),
    zoom: 1.0,
    bearing: 0.0,
    pitch: 0.0,
  );

  /// A helper to provide default annotation options (e.g., an icon).
  static PointAnnotationOptions getDefaultAnnotationOptions(Point geometry) {
    return PointAnnotationOptions(
      geometry: geometry,
      iconSize: 1.0,
      iconImage: "mapbox-check",
    );
  }
}