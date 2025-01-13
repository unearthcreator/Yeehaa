import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_initialization_dialog.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_form_dialog.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/show_annotation_details_dialog.dart';
import 'package:uuid/uuid.dart';
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_id_linker.dart';
import 'package:map_mvp_project/src/earth_map/utils/trash_can_handler.dart';

typedef AnnotationLongPressCallback = void Function(PointAnnotation annotation, Point annotationPosition);
typedef AnnotationDragUpdateCallback = void Function(PointAnnotation annotation);
typedef DragEndCallback = void Function();
typedef AnnotationRemovedCallback = void Function();

class MyPointAnnotationClickListener extends OnPointAnnotationClickListener {
  final void Function(PointAnnotation) onClick;

  MyPointAnnotationClickListener(this.onClick);

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    onClick(annotation);
    return true; // event handled
  }
}

class MapGestureHandler {
  final MapboxMap mapboxMap;
  final MapAnnotationsManager annotationsManager;
  final BuildContext context;
  final LocalAnnotationsRepository localAnnotationsRepository;
  final AnnotationIdLinker annotationIdLinker;

  // Callbacks to inform EarthMapPage
  final AnnotationLongPressCallback? onAnnotationLongPress;
  final AnnotationDragUpdateCallback? onAnnotationDragUpdate;
  final DragEndCallback? onDragEnd;
  final AnnotationRemovedCallback? onAnnotationRemoved;
  final VoidCallback? onConnectModeDisabled;

  Timer? _placementDialogTimer;
  Point? _longPressPoint;
  bool _isOnExistingAnnotation = false;
  PointAnnotation? _selectedAnnotation;
  final TrashCanHandler _trashCanHandler;
  ScreenCoordinate? _lastDragScreenPoint;
  Point? _originalPoint;

  // Fields used previously for drag logic, now minimal or unused:
  bool _isProcessingDrag = false;

  String? _chosenTitle;
  String? _chosenStartDate;
  String? _chosenEndDate;
  String _chosenIconName = "mapbox-check";
  final uuid = Uuid();

  MapGestureHandler({
    required this.mapboxMap,
    required this.annotationsManager,
    required this.context,
    required this.localAnnotationsRepository,
    required this.annotationIdLinker,
    this.onAnnotationLongPress,
    this.onAnnotationDragUpdate,
    this.onDragEnd,
    this.onAnnotationRemoved,
    this.onConnectModeDisabled,
  }) : _trashCanHandler = TrashCanHandler(context: context) {
    // Listen for user taps on annotations (just for showing details now)
    annotationsManager.pointAnnotationManager.addOnPointAnnotationClickListener(
      MyPointAnnotationClickListener((clickedAnnotation) {
        logger.i('Annotation tapped: ${clickedAnnotation.id}');
        // EarthMapPage likely shows the annotation menu, but from here we can show details:
        final hiveId = annotationIdLinker.getHiveIdForMapId(clickedAnnotation.id);
        if (hiveId != null) {
          _showAnnotationDetailsById(hiveId);
        } else {
          logger.w('No recorded Hive id for tapped annotation ${clickedAnnotation.id}');
        }
      }),
    );
  }

  Future<void> _showAnnotationDetailsById(String id) async {
    final allAnnotations = await localAnnotationsRepository.getAnnotations();
    final ann = allAnnotations.firstWhere(
      (a) => a.id == id,
      orElse: () => Annotation(id: 'notFound'),
    );
    if (ann.id != 'notFound') {
      showAnnotationDetailsDialog(context, ann);
    } else {
      logger.w('No matching Hive annotation found for id: $id');
    }
  }

  /// Handle a long press on the map. If no existing annotation is found, 
  /// start the placement dialog flow. Otherwise, inform EarthMapPage 
  /// that user long-pressed an existing annotation.
  Future<void> handleLongPress(ScreenCoordinate screenPoint) async {
    try {
      final features = await mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [annotationsManager.annotationLayerId]),
      );

      logger.i('Features found: ${features.length}');
      final pressPoint = await mapboxMap.coordinateForPixel(screenPoint);
      if (pressPoint == null) {
        logger.w('Could not convert screen coordinate to map coordinate');
        return;
      }

      _longPressPoint = pressPoint;
      _isOnExistingAnnotation = features.isNotEmpty;

      if (!_isOnExistingAnnotation) {
        logger.i('No existing annotation, will start placement dialog timer.');
        _startPlacementDialogTimer(pressPoint);
      } else {
        logger.i('Long press on existing annotation.');
        final nearest = await annotationsManager.findNearestAnnotation(pressPoint);
        if (nearest != null) {
          _selectedAnnotation = nearest;
          try {
            _originalPoint = Point.fromJson({
              'type': 'Point',
              'coordinates': [
                nearest.geometry.coordinates[0],
                nearest.geometry.coordinates[1],
              ],
            });
            logger.i('Original point stored: ${_originalPoint?.coordinates} for ${nearest.id}');
          } catch (e) {
            logger.e('Error storing original point: $e');
          }
          // Notify EarthMapPage
          onAnnotationLongPress?.call(nearest, _originalPoint!);
        } else {
          logger.w('No annotation found on long-press.');
        }
      }
    } catch (e) {
      logger.e('Error during feature query: $e');
    }
  }

  /// The onPanUpdate or drag logic used to be here, 
  /// but now "move" is handled by annotation_actions.
  /// We keep a minimal handleDrag to support "trash can" if needed.
  Future<void> handleDrag(ScreenCoordinate screenPoint) async {
    // If you still want "trash can" logic, you can keep a minimal version:
    if (_selectedAnnotation == null || _isProcessingDrag) return;
    try {
      _isProcessingDrag = true;
      _lastDragScreenPoint = screenPoint;
      // e.g. check if the annotation is near trash can
      // or do nothing if move logic is in annotation_actions
    } catch (e) {
      logger.e('Error in handleDrag: $e');
    } finally {
      _isProcessingDrag = false;
    }
  }

  /// Called when drag ends
  Future<void> endDrag() async {
    logger.i('Ending drag.');

    // If you want "trash can" removal:
    if (_lastDragScreenPoint != null &&
        _selectedAnnotation != null &&
        _trashCanHandler.isOverTrashCan(_lastDragScreenPoint!)) {
      logger.i('Annotation dropped over trash can. Show removal dialog...');
      final remove = await _showRemoveConfirmationDialog();
      if (remove == true) {
        logger.i('User confirmed removal. Removing annotation...');
        await annotationsManager.removeAnnotation(_selectedAnnotation!);
        onAnnotationRemoved?.call();
      } else {
        // Possibly revert?
        if (_originalPoint != null) {
          logger.i('Reverting annotation ${_selectedAnnotation!.id} to ${_originalPoint?.coordinates}');
          await annotationsManager.updateVisualPosition(_selectedAnnotation!, _originalPoint!);
        }
      }
    }

    onDragEnd?.call();
  }

  Future<bool?> _showRemoveConfirmationDialog() async {
    logger.i('Showing remove confirmation dialog.');
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove Annotation'),
          content: const Text('Do you want to remove this annotation?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                logger.i('User selected NO in remove dialog.');
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                logger.i('User selected YES in remove dialog.');
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  /// The existing code for placing a new annotation if there's no annotation under the long-press
  void _startPlacementDialogTimer(Point point) {
    _placementDialogTimer?.cancel();
    logger.i('Starting placement dialog timer for annotation at $point.');

    _placementDialogTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        logger.i('Attempting to show initial form dialog now.');
        final initialData = await showAnnotationInitializationDialog(context);
        logger.i('Initial form dialog returned: $initialData');
        if (initialData != null) {
          _chosenTitle = initialData['title'] as String?;
          _chosenIconName = initialData['icon'] as String;
          _chosenStartDate = initialData['date'] as String?;
          _chosenEndDate = initialData['endDate'] as String?;
          final bool quickSave = (initialData['quickSave'] == true);

          logger.i(
            'Got title=$_chosenTitle, icon=$_chosenIconName, '
            'startDate=$_chosenStartDate, endDate=$_chosenEndDate, quickSave=$quickSave.'
          );

          if (quickSave) {
            if (_longPressPoint != null) {
              logger.i('Adding annotation (quickSave) at ${_longPressPoint?.coordinates}.');
              final bytes = await rootBundle.load('assets/icons/$_chosenIconName.png');
              final imageData = bytes.buffer.asUint8List();

              final mapAnnotation = await annotationsManager.addAnnotation(
                _longPressPoint!,
                image: imageData,
                title: _chosenTitle ?? '',
                date: _chosenStartDate ?? '',
              );
              logger.i('Annotation added at ${_longPressPoint?.coordinates} with ID: ${mapAnnotation.id}');

              final id = uuid.v4();
              final latitude = _longPressPoint!.coordinates.lat.toDouble();
              final longitude = _longPressPoint!.coordinates.lng.toDouble();

              final annotation = Annotation(
                id: id,
                title: _chosenTitle?.isNotEmpty == true ? _chosenTitle : null,
                iconName: _chosenIconName.isNotEmpty ? _chosenIconName : null,
                startDate: _chosenStartDate?.isNotEmpty == true ? _chosenStartDate : null,
                endDate: _chosenEndDate?.isNotEmpty == true ? _chosenEndDate : null,
                note: null,
                latitude: latitude,
                longitude: longitude,
                imagePath: null,
              );

              await localAnnotationsRepository.addAnnotation(annotation);
              logger.i('Annotation saved to Hive with ID: $id');

              annotationIdLinker.registerAnnotationId(mapAnnotation.id, id);
              logger.i('Linked mapAnnotation.id=${mapAnnotation.id} with hiveUUID=$id');
            } else {
              logger.w('No long press point stored, cannot place annotation (quickSave).');
            }
          } else {
            // Show the final form
            await startFormDialogFlow();
          }
        } else {
          logger.i('User closed the initial form dialog - no annotation added.');
        }
      } catch (e) {
        logger.e('Error in placement dialog timer: $e');
      }
    });
  }

  Future<void> startFormDialogFlow() async {
    logger.i('Showing annotation form dialog now.');
    // ...Same code for final form...
    // This code remains if you still rely on the "final form" for annotation creation.
  }

  /// If you'd like to cancel these timers upon some event:
  void cancelTimer() {
    logger.i('Cancelling timers and resetting state');
    _placementDialogTimer?.cancel();
    _placementDialogTimer = null;
    _longPressPoint = null;
    _selectedAnnotation = null;
    _isOnExistingAnnotation = false;
    _isProcessingDrag = false;
    _originalPoint = null;
  }
}