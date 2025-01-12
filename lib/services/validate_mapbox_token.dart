// services/mapbox_util.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // Assuming you have a logger setup

/// Validates the Mapbox Access Token.
/// Logs an error if the token is missing or invalid.
void validateMapboxAccessToken() {
  const String ACCESS_TOKEN = String.fromEnvironment("ACCESS_TOKEN");

  if (ACCESS_TOKEN.isEmpty) {
    logger.e('Mapbox Access Token is missing or invalid. The app might not function properly.');
  } else {
    try {
      // Set the token if valid
      MapboxOptions.setAccessToken(ACCESS_TOKEN);
      logger.i('Mapbox Access Token successfully set.');
    } catch (e, stackTrace) {
      logger.e('Error while setting Mapbox Access Token', error: e, stackTrace: stackTrace);
    }
  }
}