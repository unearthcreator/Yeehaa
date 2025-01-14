import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_id_linker.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_form_dialog.dart';
import 'package:map_mvp_project/services/error_handler.dart';

/// A class that handles various 'annotation actions', like connecting 
/// two annotations, moving an annotation, or editing it.
class AnnotationActions {
  final LocalAnnotationsRepository localRepo;
  final MapAnnotationsManager annotationsManager;
  final AnnotationIdLinker annotationIdLinker;

  // ---------------------------------------------------------------
  //         STATE FOR "CONNECT MODE"
  // ---------------------------------------------------------------
  bool _isInConnectMode = false;
  PointAnnotation? _firstConnectAnnotation;

  // ---------------------------------------------------------------
  //         STATE FOR "MOVE MODE"
  // ---------------------------------------------------------------
  bool _isInMoveMode = false;
  PointAnnotation? _movingAnnotation;
  Point? _movingAnnotationOriginalPoint;

  // ---------------------------------------------------------------
  //                      CONSTRUCTOR
  // ---------------------------------------------------------------
  AnnotationActions({
    required this.localRepo,
    required this.annotationsManager,
    required this.annotationIdLinker,
  });

  // ---------------------------------------------------------------
  //                  CONNECT MODE METHODS
  // ---------------------------------------------------------------
  void startConnectMode(PointAnnotation firstAnnotation) {
    logger.i('AnnotationActions: startConnectMode with annotation: ${firstAnnotation.id}');
    _isInConnectMode = true;
    _firstConnectAnnotation = firstAnnotation;
  }

  void cancelConnectMode() {
    logger.i('AnnotationActions: cancelConnectMode.');
    _isInConnectMode = false;
    _firstConnectAnnotation = null;
  }

  Future<void> finishConnectMode(PointAnnotation secondAnnotation) async {
    if (!_isInConnectMode || _firstConnectAnnotation == null) {
      logger.w('finishConnectMode called but we are not in connect mode or missing the first annotation.');
      return;
    }
    logger.i(
      'AnnotationActions: finishConnectMode connecting '
      '${_firstConnectAnnotation!.id} with ${secondAnnotation.id}.'
    );

    // Implement your linking/drawing lines logic here

    _isInConnectMode = false;
    _firstConnectAnnotation = null;
    logger.i('AnnotationActions: connect mode finished, returning to normal mode.');
  }

  // ---------------------------------------------------------------
  //                  MOVE (DRAG) METHODS
  // ---------------------------------------------------------------
  void startMoveAnnotation(PointAnnotation annotation) {
    logger.i('AnnotationActions: startMoveAnnotation for ${annotation.id}');
    _isInMoveMode = true;
    _movingAnnotation = annotation;
    _movingAnnotationOriginalPoint = annotation.geometry;
  }

  /// Cancels the move, returning the annotation to the original spot
  Future<void> cancelMoveAnnotation() async {
    if (!_isInMoveMode || _movingAnnotation == null) {
      logger.w('cancelMoveAnnotation called but not in move mode or no annotation selected.');
      return;
    }
    logger.i('AnnotationActions: cancelMoveAnnotation for ${_movingAnnotation!.id}');

    if (_movingAnnotationOriginalPoint != null) {
      // Revert the position visually
      await annotationsManager.updateVisualPosition(
        _movingAnnotation!,
        _movingAnnotationOriginalPoint!,
      );
    }

    _isInMoveMode = false;
    _movingAnnotation = null;
    _movingAnnotationOriginalPoint = null;
  }

  /// Finalize the new location in Hive, then exit move mode
  /// (We're no longer calling this automatically onPanEnd.)
  Future<void> finishMoveAnnotation(Point newLocation) async {
    if (!_isInMoveMode || _movingAnnotation == null) {
      logger.w('finishMoveAnnotation called but not in move mode or annotation was null.');
      return;
    }

    final movedAnnotation = _movingAnnotation!;
    logger.i('AnnotationActions: finishMoveAnnotation for ${movedAnnotation.id} to $newLocation');

    // 1. Update annotation in Hive
    final hiveId = annotationIdLinker.getHiveIdForMapId(movedAnnotation.id);
    if (hiveId == null) {
      logger.w('No hive ID found for the moving annotation. Cannot update Hive.');
    } else {
      final allAnnotations = await localRepo.getAnnotations();
      final ann = allAnnotations.firstWhere(
        (a) => a.id == hiveId,
        orElse: () => Annotation(id: 'notFound'),
      );

      if (ann.id == 'notFound') {
        logger.w('Moving annotation not found in Hive, cannot update.');
      } else {
        logger.i('finishMoveAnnotation: found in Hive => $ann');

        // Build updated version
        final updated = Annotation(
          id: ann.id,
          title: ann.title,
          iconName: ann.iconName,
          startDate: ann.startDate,
          endDate: ann.endDate,
          note: ann.note,
          // Cast num? to double
          latitude: (newLocation.coordinates[1] as num).toDouble(),
          longitude: (newLocation.coordinates[0] as num).toDouble(),
          imagePath: ann.imagePath,
        );

        // Save to Hive
        await localRepo.updateAnnotation(updated);
        logger.i('finishMoveAnnotation: updated lat/lng in Hive => $updated');
      }
    }

    // 2. Clear "move mode"
    _isInMoveMode = false;
    _movingAnnotation = null;
    _movingAnnotationOriginalPoint = null;
  }

  /// Returns a widget that draws a transparent overlay + draggable circle
  /// for the user to move the annotation around on the map.
  Widget buildMoveOverlay({
    required bool isMoveMode,
    required MapboxMap mapboxMap,
  }) {
    // 1. If move mode is off or no annotation to move, do nothing
    if (!isMoveMode || _movingAnnotation == null || _movingAnnotation!.geometry == null) {
      return const SizedBox.shrink();
    }

    // 2. If geometry is also non-null:
    final initialPoint = _movingAnnotation!.geometry;
    if (initialPoint == null) {
      return const SizedBox.shrink(); 
    }

    return _DraggableAnnotationOverlay(
      initialPosition: initialPoint,
      mapboxMap: mapboxMap,
      onDragUpdate: (Point newPoint) async {
        // Keep updating the annotation visually as the user drags
        if (_movingAnnotation != null) {
          await annotationsManager.updateVisualPosition(_movingAnnotation!, newPoint);
        }
      },
      onDragEnd: () {
        // NO LONGER finalize here, so the user can keep dragging if they want
        logger.i('User lifted finger, but staying in move mode. No finalization yet.');
      },
    );
  }

  // ---------------------------------------------------------------
  //                  EDIT ANNOTATION LOGIC
  // ---------------------------------------------------------------
  Future<void> editAnnotation({
    required BuildContext context,
    required PointAnnotation? mapAnnotation,
  }) async {
    if (mapAnnotation == null) {
      logger.w('No annotation given, cannot edit.');
      return;
    }

    logger.i('Attempting to edit annotation with map ID: ${mapAnnotation.id}');

    final hiveId = annotationIdLinker.getHiveIdForMapId(mapAnnotation.id);
    logger.i('Hive ID: $hiveId');
    if (hiveId == null) {
      logger.w('No hive ID found for this annotation.');
      return;
    }

    // Load from Hive
    final allAnnotations = await localRepo.getAnnotations();
    logger.i('Total annotations from Hive: ${allAnnotations.length}');
    final ann = allAnnotations.firstWhere(
      (a) => a.id == hiveId,
      orElse: () => Annotation(id: 'notFound'),
    );

    if (ann.id == 'notFound') {
      logger.w('Annotation not found in Hive.');
      return;
    } else {
      logger.i('Found annotation in Hive: $ann');
    }

    // Show form dialog
    final title = ann.title ?? '';
    final note = ann.note ?? '';
    final startDate = ann.startDate ?? '';
    final iconName = ann.iconName ?? 'cross';
    IconData chosenIcon = Icons.star;

    final result = await showAnnotationFormDialog(
      context,
      title: title,
      chosenIcon: chosenIcon,
      date: startDate,
      note: note,
    );

    if (result != null) {
      // Build updated
      final updatedNote = result['note'] ?? '';
      final updatedImagePath = result['imagePath'];

      logger.i('User edited note: $updatedNote, imagePath: $updatedImagePath');

      final updatedAnnotation = Annotation(
        id: ann.id,
        title: title.isNotEmpty ? title : null,
        iconName: iconName.isNotEmpty ? iconName : null,
        startDate: ann.startDate,
        endDate: ann.endDate,
        note: updatedNote.isNotEmpty ? updatedNote : null,
        latitude: ann.latitude ?? 0.0,
        longitude: ann.longitude ?? 0.0,
        imagePath: (updatedImagePath != null && updatedImagePath.isNotEmpty)
            ? updatedImagePath
            : ann.imagePath,
      );

      // Update in Hive
      await localRepo.updateAnnotation(updatedAnnotation);
      logger.i('Annotation updated in Hive with id: ${ann.id}');

      // Remove old & add updated
      await annotationsManager.removeAnnotation(mapAnnotation);

      final iconBytes = await rootBundle.load('assets/icons/${updatedAnnotation.iconName ?? 'cross'}.png');
      final imageData = iconBytes.buffer.asUint8List();

      final newMapAnnotation = await annotationsManager.addAnnotation(
        Point(coordinates: Position(
          updatedAnnotation.longitude ?? 0.0,
          updatedAnnotation.latitude ?? 0.0,
        )),
        image: imageData,
        title: updatedAnnotation.title ?? '',
        date: updatedAnnotation.startDate ?? '',
      );

      // Re-link
      annotationIdLinker.registerAnnotationId(newMapAnnotation.id, updatedAnnotation.id);

      logger.i('Annotation visually updated on map.');
    } else {
      logger.i('User cancelled edit.');
    }
  }

  // ---------------------------------------------------------------
  //      The connect_banner "UI" code
  // ---------------------------------------------------------------
  Widget buildConnectModeBanner({
    required bool isConnectMode,
    required VoidCallback onCancel,
    required MapboxMap mapboxMap,
  }) {
    if (!isConnectMode) return const SizedBox.shrink();

    return Positioned(
      top: 50,
      left: null,
      right: null,
      child: Center(
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
                  onCancel();     // EarthMapPage callback
                  cancelConnectMode(); // domain logic
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Inline _DraggableAnnotationOverlay code
// ---------------------------------------------------------------------
class _DraggableAnnotationOverlay extends StatefulWidget {
  final Point initialPosition;
  final Function(Point) onDragUpdate;
  final VoidCallback onDragEnd;
  final MapboxMap mapboxMap;

  const _DraggableAnnotationOverlay({
    Key? key,
    required this.initialPosition,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.mapboxMap,
  }) : super(key: key);

  @override
  State<_DraggableAnnotationOverlay> createState() => _DraggableAnnotationOverlayState();
}

class _DraggableAnnotationOverlayState extends State<_DraggableAnnotationOverlay> {
  Offset _position = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initializePosition();
  }

  Future<void> _initializePosition() async {
    // Convert the annotation's map coordinate to screen coordinate
    final screenPoint = await widget.mapboxMap.pixelForCoordinate(widget.initialPosition);
    setState(() {
      // Place the circle so its center is exactly at screenPoint
      _position = Offset(screenPoint.x, screenPoint.y);
    });
  }

  @override
  void didUpdateWidget(_DraggableAnnotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPosition != widget.initialPosition) {
      _initializePosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          // If you want the circle’s center exactly on the annotation:
          left: _position.dx - 15,
          top: _position.dy - 30, // or -15 if that anchors better for your icon
          child: GestureDetector(
            onPanUpdate: (details) async {
              // 1) Update local offset
              final newPosition = Offset(
                _position.dx + details.delta.dx,
                _position.dy + details.delta.dy,
              );

              // 2) Convert newPosition -> map coordinates
              final screenCoord = ScreenCoordinate(
                x: newPosition.dx,
                y: newPosition.dy,
              );
              final mapPoint = await widget.mapboxMap.coordinateForPixel(screenCoord);
              if (mapPoint != null) {
                widget.onDragUpdate(mapPoint);
              }

              // 3) Rebuild overlay at the new offset
              setState(() {
                _position = newPosition;
              });
            },
            onPanEnd: (details) {
              // We do NOT finalize here, so the user can pick it up again
              widget.onDragEnd();
            },
            child: _buildDragWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildDragWidget() {
    // A 30×30 semi-transparent circle with a white border
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}