import 'dart:typed_data';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_id_linker.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';

class MapAnnotationsManager {
  final PointAnnotationManager _annotationManager;
  final AnnotationIdLinker annotationIdLinker; // Add this field
  final LocalAnnotationsRepository localAnnotationsRepository; // Add this field

  final List<PointAnnotation> _annotations = [];

  // Update the constructor to accept these new parameters as named parameters.
  MapAnnotationsManager(
    this._annotationManager, {
    required this.annotationIdLinker,
    required this.localAnnotationsRepository,
  });

  // Add a getter to access the underlying annotation manager
  PointAnnotationManager get pointAnnotationManager => _annotationManager;

  Future<PointAnnotation> addAnnotation(
    Point mapPoint, {
    Uint8List? image,
    String? title,
    String? date,
  }) async {
    logger.i('Adding annotation at: ${mapPoint.coordinates.lat}, ${mapPoint.coordinates.lng}');

    final hasTitle = title != null && title.isNotEmpty;
    final hasDate = date != null && date.isNotEmpty;

    String? displayText;
    if (hasTitle && hasDate) {
      displayText = "$title\n$date";
    } else if (hasTitle) {
      displayText = title;
    } else if (hasDate) {
      displayText = date;
    } else {
      displayText = null;
    }

    final iconImageName = (image == null) ? "marker-15" : null;

    final annotationOptions = PointAnnotationOptions(
      geometry: mapPoint,
      iconSize: 5.0,
      image: image,
      iconImage: iconImageName,
      textField: displayText,
      textSize: (displayText != null) ? 18.0 : null,
      textAnchor: (displayText != null) ? TextAnchor.BOTTOM : null,
      iconAnchor: IconAnchor.BOTTOM,
      textOffset: (displayText != null) ? [0, -2.1] : null,
      textLineHeight: (hasTitle && hasDate) ? 1.2 : null,
      textColor: (displayText != null) ? 0xFFFFFFFF : null,
      textHaloColor: (displayText != null) ? 0xFF000000 : null,
      textHaloWidth: (displayText != null) ? 1.0 : null,
      textHaloBlur: (displayText != null) ? 0.5 : null,
    );

    logger.i('title=$title, date=$date, displayText="$displayText"');
    final annotation = await _annotationManager.create(annotationOptions);
    _annotations.add(annotation);
    logger.i('Added annotation, total count: ${_annotations.length}');
    return annotation;
  }

  Future<void> removeAnnotation(PointAnnotation annotation) async {
    logger.i('Attempting to remove annotation');
    try {
      await _annotationManager.delete(annotation);
      final removed = _annotations.remove(annotation);
      if (removed) {
        logger.i('Successfully removed annotation from list, remaining: ${_annotations.length}');
      } else {
        logger.w('Annotation was not found in list');
      }
    } catch (e) {
      logger.e('Error during annotation removal: $e');
      throw e;
    }
  }

  Future<void> removeAllAnnotations() async {
  if (_annotations.isNotEmpty) {
    await _annotationManager.deleteAll();  // Removes from the map
    _annotations.clear();                  // Clear our local tracking list
    logger.i('All annotations removed from the map. Current count: ${_annotations.length}');
  } else {
    logger.i('No annotations to remove from the map.');
  }
}

  Future<void> updateVisualPosition(PointAnnotation annotation, Point newPoint) async {
    try {
      annotation.geometry = newPoint;
      await _annotationManager.update(annotation);
      logger.i('Updated annotation visual position to: ${newPoint.coordinates.lat}, ${newPoint.coordinates.lng}');
    } catch (e) {
      logger.e('Error updating annotation visual position: $e');
      throw e;
    }
  }

  Future<PointAnnotation?> findNearestAnnotation(Point tapPoint) async {
    if (_annotations.isEmpty) {
      logger.i('No annotations to search through');
      return null;
    }
    double minDistance = double.infinity;
    PointAnnotation? nearest;

    for (var annotation in _annotations) {
      double distance = _calculateDistance(annotation.geometry, tapPoint);
      logger.i('Checking annotation distance: $distance');
      if (distance < minDistance) {
        minDistance = distance;
        nearest = annotation;
      }
    }

    if (nearest != null) {
      logger.i('Found nearest annotation at distance: $minDistance');
    }

    return minDistance < 2.0 ? nearest : null;
  }

  Future<void> loadAnnotationsFromHive() async {
  logger.i('Loading saved annotations from Hive.');
  
  // Fetch all annotations stored in Hive
  final hiveAnnotations = await localAnnotationsRepository.getAnnotations();

  for (final ann in hiveAnnotations) {
    final lat = ann.latitude;
    final lng = ann.longitude;

    // Skip any annotations that don't have valid coordinates
    if (lat == null || lng == null) {
      logger.w('Annotation ${ann.id} is missing coordinates, skipping.');
      continue;
    }

    // Create a Point from the stored coordinates
    final point = Point(coordinates: Position(lng, lat));

    // Attempt to load a custom icon if specified, otherwise fall back to default
    Uint8List? iconBytes;
    if (ann.iconName != null && ann.iconName!.isNotEmpty) {
      try {
        final iconData = await rootBundle.load('assets/icons/${ann.iconName}.png');
        iconBytes = iconData.buffer.asUint8List();
      } catch (e) {
        logger.w('Failed to load icon ${ann.iconName} for annotation ${ann.id}, using default marker.');
        iconBytes = null;
      }
    }

    // Add the annotation to the map
    final mapAnnotation = await addAnnotation(
      point,
      image: iconBytes,
      title: ann.title,
      date: ann.startDate,
    );

    // Link the Mapbox annotation ID to the Hive annotation ID
    annotationIdLinker.registerAnnotationId(mapAnnotation.id, ann.id);
    logger.i('Linked Hive ID ${ann.id} to Mapbox annotation ID ${mapAnnotation.id}');
  }

  logger.i('Completed loading saved annotations from Hive.');
}

  double _calculateDistance(Point p1, Point p2) {
    double latDiff = (p1.coordinates.lat.toDouble() - p2.coordinates.lat.toDouble()).abs();
    double lngDiff = (p1.coordinates.lng.toDouble() - p2.coordinates.lng.toDouble()).abs();
    return latDiff + lngDiff;
  }

  String get annotationLayerId => _annotationManager.id;
  bool get hasAnnotations => _annotations.isNotEmpty;
  List<PointAnnotation> get annotations => List.unmodifiable(_annotations);
}