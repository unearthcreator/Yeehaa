import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// ---------------------- Internal / Project Imports ----------------------
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_initialization_dialog.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/show_annotation_details_dialog.dart';
import 'package:uuid/uuid.dart';
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_id_linker.dart';
import 'package:map_mvp_project/src/earth_map/utils/trash_can_handler.dart';

/// Callbacks to notify EarthMapPage (or parent) about various annotation events.
typedef AnnotationLongPressCallback = void Function(PointAnnotation annotation, Point annotationPosition);
typedef AnnotationDragUpdateCallback = void Function(PointAnnotation annotation);
typedef DragEndCallback = void Function();
typedef AnnotationRemovedCallback = void Function();

/// A simple OnPointAnnotationClickListener that calls [onClick] when an annotation is tapped.
class MyPointAnnotationClickListener extends OnPointAnnotationClickListener {
  final void Function(PointAnnotation) onClick;

  MyPointAnnotationClickListener(this.onClick);

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    onClick(annotation);
    return true; // event handled
  }
}

/// Handles map gestures and annotation interactions, such as long-press, dragging, etc.
class MapGestureHandler {
  // --------------------- Constructor Params ---------------------
  final MapboxMap mapboxMap;
  final MapAnnotationsManager annotationsManager;
  final BuildContext context;
  final LocalAnnotationsRepository localAnnotationsRepository;
  final AnnotationIdLinker annotationIdLinker;

  // --------------------- Callbacks to Parent ---------------------
  final AnnotationLongPressCallback? onAnnotationLongPress;
  final AnnotationDragUpdateCallback? onAnnotationDragUpdate;
  final DragEndCallback? onDragEnd;
  final AnnotationRemovedCallback? onAnnotationRemoved;
  final VoidCallback? onConnectModeDisabled;

  // --------------------- Internal State ---------------------
  Timer? _placementDialogTimer;
  Point? _longPressPoint;
  bool _isOnExistingAnnotation = false;
  PointAnnotation? _selectedAnnotation;
  ScreenCoordinate? _lastDragScreenPoint;
  Point? _originalPoint; // for revert if user cancels

  // For minimal drag processing:
  bool _isProcessingDrag = false;

  // Chosen annotation fields during creation:
  String? _chosenTitle;
  String? _chosenStartDate;
  String? _chosenEndDate;
  String _chosenIconName = "mapbox-check";

  // Used for unique IDs
  final uuid = Uuid();

  // A helper for "trash can" logic (deleting annotations)
  final TrashCanHandler _trashCanHandler;

  // ---------------------------------------------------------------------
  //                             Constructor
  // ---------------------------------------------------------------------
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
    // Listen for user taps on annotations.
    // This can show a details dialog or hand control to EarthMapPage.
    annotationsManager.pointAnnotationManager.addOnPointAnnotationClickListener(
      MyPointAnnotationClickListener((clickedAnnotation) {
        logger.i('Annotation tapped: ${clickedAnnotation.id}');

        final hiveId = annotationIdLinker.getHiveIdForMapId(clickedAnnotation.id);
        if (hiveId != null) {
          _showAnnotationDetailsById(hiveId);
        } else {
          logger.w('No recorded Hive id for tapped annotation ${clickedAnnotation.id}');
        }
      }),
    );
  }

  // ---------------------------------------------------------------------
  //                Handling Taps / Annotation Details
  // ---------------------------------------------------------------------
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

  // ---------------------------------------------------------------------
  //                Handling Long Press (Create or Edit)
  // ---------------------------------------------------------------------
  Future<void> handleLongPress(ScreenCoordinate screenPoint) async {
    try {
      final features = await mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [annotationsManager.annotationLayerId]),
      );

      logger.i('Features found at long press: ${features.length}');
      final pressPoint = await mapboxMap.coordinateForPixel(screenPoint);
      if (pressPoint == null) {
        logger.w('Could not convert screen coordinate to map coordinate');
        return;
      }

      _longPressPoint = pressPoint;
      _isOnExistingAnnotation = features.isNotEmpty;

      if (!_isOnExistingAnnotation) {
        logger.i('No existing annotation; starting placement dialog timer...');
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
            logger.i('Stored original point: ${_originalPoint?.coordinates} for ${nearest.id}');
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
      logger.e('Error during feature query in handleLongPress: $e');
    }
  }

  // ---------------------------------------------------------------------
  //                Minimal Drag Handling (Trash Can)
  // ---------------------------------------------------------------------
  Future<void> handleDrag(ScreenCoordinate screenPoint) async {
    // If a user wants a "trash can" approach, partial logic can remain here.
    if (_selectedAnnotation == null || _isProcessingDrag) return;

    try {
      _isProcessingDrag = true;
      _lastDragScreenPoint = screenPoint;
      // Example: check if the annotation is near a trash can, etc.
    } catch (e) {
      logger.e('Error in handleDrag: $e');
    } finally {
      _isProcessingDrag = false;
    }
  }

  Future<void> endDrag() async {
    logger.i('Ending drag.');

    // If "trash can" logic is used:
    if (_lastDragScreenPoint != null &&
        _selectedAnnotation != null &&
        _trashCanHandler.isOverTrashCan(_lastDragScreenPoint!)) {
      logger.i('Annotation dropped over trash can. Prompt removal...');
      final remove = await _showRemoveConfirmationDialog();
      if (remove == true) {
        logger.i('User confirmed removal. Removing annotation...');
        await annotationsManager.removeAnnotation(_selectedAnnotation!);
        onAnnotationRemoved?.call();
      } else {
        // Revert if user cancels
        if (_originalPoint != null) {
          logger.i('Reverting ${_selectedAnnotation!.id} to ${_originalPoint!.coordinates}');
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

  // ---------------------------------------------------------------------
  //       Creating a New Annotation if No Existing Annotation
  // ---------------------------------------------------------------------
  void _startPlacementDialogTimer(Point point) {
    _placementDialogTimer?.cancel();
    logger.i('Starting placement dialog timer at $point.');

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
          final quickSave = (initialData['quickSave'] == true);

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
              logger.i('Annotation added with ID: ${mapAnnotation.id}');

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
              logger.w('No long press point stored; cannot place annotation (quickSave).');
            }
          } else {
            // Show the final form if not quickSave
            await startFormDialogFlow();
          }
        } else {
          logger.i('User closed the initial form dialog; no annotation added.');
        }
      } catch (e) {
        logger.e('Error in placement dialog timer: $e');
      }
    });
  }

  /// If you want a secondary / final form flow:
  Future<void> startFormDialogFlow() async {
    logger.i('Showing annotation form dialog now.');
    // ... code for final form ...
  }

  // ---------------------------------------------------------------------
  //                        PUBLIC UTILS
  // ---------------------------------------------------------------------
  void cancelTimer() {
    logger.i('Cancelling timers & resetting state.');
    _placementDialogTimer?.cancel();
    _placementDialogTimer = null;
    _longPressPoint = null;
    _selectedAnnotation = null;
    _isOnExistingAnnotation = false;
    _isProcessingDrag = false;
    _originalPoint = null;
  }
}