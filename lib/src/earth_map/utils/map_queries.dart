import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // for logger
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';

Future<List<String>> queryVisibleFeatures({
  required BuildContext context,
  required bool isMapReady,
  required MapboxMap mapboxMap,
  required MapAnnotationsManager annotationsManager,
}) async {
  if (!isMapReady) {
    return <String>[]; // Return an empty list if the map isn't ready
  }

  final width = MediaQuery.of(context).size.width;
  final height = MediaQuery.of(context).size.height;

  final queriedRenderedFeatures = await mapboxMap.queryRenderedFeatures(
    RenderedQueryGeometry.fromScreenBox(
      ScreenBox(
        min: ScreenCoordinate(x: 0, y: 0),
        max: ScreenCoordinate(x: width, y: height),
      ),
    ),
    RenderedQueryOptions(
      layerIds: [annotationsManager.annotationLayerId],
      filter: null,
    ),
  );

  logger.i('Viewport features found: ${queriedRenderedFeatures.length}');

  // We'll collect the Mapbox annotation IDs in this list.
  final annotationIds = <String>[];

  for (final qRenderedFeature in queriedRenderedFeatures) {
    if (qRenderedFeature == null) {
      // If the item is null, skip
      continue;
    }

    // `qRenderedFeature.queriedFeature.feature` is the raw map
    // containing the geometry/properties/etc.
    final featureMap = qRenderedFeature.queriedFeature.feature;

    // We expect `'id'` to be the annotation's unique ID if it's set.
    final maybeId = featureMap['id'];

    if (maybeId != null && maybeId is String) {
      logger.i('Got a String feature ID: $maybeId');
      annotationIds.add(maybeId);
    } else {
      logger.w('Feature has no valid String id. Found id=$maybeId');
    }

    // If you want geometry or other properties, you can do something like:
    //
    // final geometry = featureMap['geometry'];
    // final properties = featureMap['properties'];
    //
    // These might be nested maps depending on your version of the plugin.
  }

  logger.i('Mapbox annotation IDs in viewport: $annotationIds');
  return annotationIds;
}