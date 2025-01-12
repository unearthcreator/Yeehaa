import 'package:flutter/material.dart';
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/src/earth_map/timeline/painter/timeline_painter.dart';
import 'package:map_mvp_project/src/earth_map/timeline/utils/timeline_annotations.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // for logger
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/utils/map_queries.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// The main TimelineView that paints a timeline based on fetched annotations
class TimelineView extends StatelessWidget {
  /// Make this nullable or provide a default empty list.
  final List<String>? hiveUuids;

  const TimelineView({
    Key? key,
    this.hiveUuids, // not required
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely handle the case where hiveUuids is null or empty
    final localUuids = hiveUuids ?? [];
    if (localUuids.isEmpty) {
      // 1) If no UUIDs, just paint an empty timeline canvas (skips fetching).
      return CustomPaint(
        painter: TimelinePainter(annotationList: const []),
      );
    }

    // 2) Otherwise, fetch the annotations via a FutureBuilder.
    return FutureBuilder<List<Annotation>>(
      future: TimelineAnnotations.fetchAnnotationsByUuids(localUuids),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Still loading, show a spinner or placeholder
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          // No matching annotations or fetch returned empty
          return CustomPaint(
            painter: TimelinePainter(annotationList: const []),
          );
        }

        final annotationList = snapshot.data!;
        // Pass them into your painter
        return CustomPaint(
          painter: TimelinePainter(annotationList: annotationList),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
//                ADDITIONAL HELPER FUNCTIONS BELOW
// ---------------------------------------------------------------------

/// A helper function to build the **timeline button** (Positioned).
///
/// [onToggleTimeline] is a callback to toggle `_showTimelineCanvas`.
/// [onHiveIdsFetched] is a callback that returns the new list of Hive IDs so
/// EarthMapPage can store them (e.g., in `_hiveUuidsForTimeline`).
Widget buildTimelineButton({
  required bool isMapReady,
  required BuildContext context,
  required MapboxMap mapboxMap,
  required MapAnnotationsManager annotationsManager,
  required VoidCallback onToggleTimeline,
  required Function(List<String>) onHiveIdsFetched,
}) {
  return Positioned(
    top: 90,
    left: 10,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(8),
      ),
      onPressed: () async {
        logger.i('Timeline button clicked');

        // 1) Query visible Mapbox annotation IDs
        final annotationIds = await queryVisibleFeatures(
          context: context,
          isMapReady: isMapReady,
          mapboxMap: mapboxMap,
          annotationsManager: annotationsManager,
        );
        logger.i('Received annotationIds from map_queries: $annotationIds');
        logger.i('Number of IDs returned: ${annotationIds.length}');

        // 2) Convert those mapbox IDs -> Hive IDs
        final hiveIds = annotationsManager.annotationIdLinker
            .getHiveIdsForMultipleAnnotations(annotationIds);

        logger.i('Got these Hive IDs from annotationIdLinker: $hiveIds');
        logger.i('Number of Hive IDs: ${hiveIds.length}');

        // 3) Let EarthMapPage know which Hive IDs we fetched
        onHiveIdsFetched(hiveIds);

        // 4) Toggle the timeline in EarthMapPage
        onToggleTimeline();
      },
      child: const Icon(Icons.timeline),
    ),
  );
}

/// A helper function to build the **timeline canvas** overlay (Positioned).
Widget buildTimelineCanvas({
  required bool showTimelineCanvas,
  required List<String> hiveUuids,
}) {
  if (!showTimelineCanvas) {
    return const SizedBox.shrink();
  }

  return Positioned(
    left: 76,
    right: 76,
    top: 19,
    bottom: 19,
    child: IgnorePointer(
      ignoring: false,
      child: Container(
        // Pass the Hive IDs to the TimelineView
        child: TimelineView(hiveUuids: hiveUuids),
      ),
    ),
  );
}
