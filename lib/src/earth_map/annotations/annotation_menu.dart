// annotation_menu.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // for logger

/// A function returning the annotation menu widget. We pass in booleans, offsets,
/// and callbacks from EarthMapPage so we can keep all UI code here, but still let
/// EarthMapPage handle setState and actual logic changes.
Widget buildAnnotationMenu({
  required bool showAnnotationMenu,
  required bool isDragging,
  required PointAnnotation? annotationMenuAnnotation,
  required Offset annotationMenuOffset,
  required String annotationButtonText,
  required VoidCallback onToggleDragging,
  required Future<void> Function() onEditAnnotation,
  required VoidCallback onConnect,
  required VoidCallback onCancel,
}) {
  // If we shouldn't show the menu or there's no current annotation, return empty
  if (!showAnnotationMenu || annotationMenuAnnotation == null) {
    return const SizedBox.shrink();
  }

  return Positioned(
    left: annotationMenuOffset.dx,
    top: annotationMenuOffset.dy,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onToggleDragging,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: Text(annotationButtonText),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onEditAnnotation,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Edit'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            logger.i('Connect button clicked');
            onConnect(); // Let EarthMapPage handle setState + logic
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Connect'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onCancel,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}