import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/services/error_handler.dart';

// Reverts an annotation to a given original point.
Future<void> revertAnnotationPosition(
  MapAnnotationsManager manager,
  PointAnnotation annotation,
  Point originalPoint
) async {
  try {
    logger.i('Reverting annotation ${annotation.id} to ${originalPoint.coordinates}');
    await manager.updateVisualPosition(annotation, originalPoint);
    logger.i('Annotation ${annotation.id} reverted successfully.');
  } catch (e) {
    logger.e('Error reverting annotation position: $e');
  }
}

// Removes an annotation from the map.
Future<void> removeAnnotation(
  MapAnnotationsManager manager,
  PointAnnotation annotation
) async {
  try {
    logger.i('User confirmed removal - removing annotation ${annotation.id}.');
    await manager.removeAnnotation(annotation);
    logger.i('Annotation ${annotation.id} removed successfully');
  } catch (e) {
    logger.e('Error removing annotation: $e');
  }
}