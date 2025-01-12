// File: connect_banner.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // if needed
import 'package:map_mvp_project/src/earth_map/gestures/map_gesture_handler.dart';

/// Builds a banner at the top-center of the screen to indicate "Connect Mode."
/// 
/// [isConnectMode] decides whether or not to show the banner.
/// [onCancel] is called when the user cancels connect mode.
/// [gestureHandler] is needed to disable connect mode if you want to do so here.
Widget buildConnectModeBanner({
  required bool isConnectMode,
  required VoidCallback onCancel,
  required MapGestureHandler gestureHandler,
}) {
  // If connect mode is off, return an empty widget
  if (!isConnectMode) return const SizedBox.shrink();

  return Positioned(
    top: 50,
    // This is an example of horizontally centering the banner on the screen.
    // If you need a dynamic approach, pass in the MediaQuery width from EarthMapPage
    left: null,
    right: null,
    child: Center(
      // Wrapping the container in Center ensures the container is horizontally centered 
      // if you place the widget in a Stack with Positioned.fill or similar. 
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const Text(
              'Click another annotation to connect, or cancel.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // EarthMapPage told us how to handle cancellation
                onCancel();
                // Also disable connect mode on the gesture handler
                gestureHandler.disableConnectMode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}