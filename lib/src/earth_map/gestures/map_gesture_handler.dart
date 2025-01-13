import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_initialization_dialog.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_form_dialog.dart';
import 'package:map_mvp_project/src/earth_map/dialogs/show_annotation_details_dialog.dart';
import 'package:uuid/uuid.dart'; // for unique IDs
import 'package:map_mvp_project/models/annotation.dart'; // Your Annotation model
import 'package:map_mvp_project/repositories/local_annotations_repository.dart'; // Your local repo
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

  final AnnotationLongPressCallback? onAnnotationLongPress;
  final AnnotationDragUpdateCallback? onAnnotationDragUpdate;
  final DragEndCallback? onDragEnd;
  final AnnotationRemovedCallback? onAnnotationRemoved;

  // If you no longer need to notify about connect mode changes,
  // you could remove this entirely. Otherwise, keep it if the UI expects it.
  final VoidCallback? onConnectModeDisabled;

  Timer? _longPressTimer;
  Timer? _placementDialogTimer;
  Point? _longPressPoint;
  bool _isOnExistingAnnotation = false;
  PointAnnotation? _selectedAnnotation;
  bool _isDragging = false;
  bool _isProcessingDrag = false;
  final TrashCanHandler _trashCanHandler;
  ScreenCoordinate? _lastDragScreenPoint;
  Point? _originalPoint;

  String? _chosenTitle;
  String? _chosenStartDate;
  String? _chosenEndDate; 
  String _chosenIconName = "mapbox-check"; 
  final uuid = Uuid();

  // -----------------------------------------------------
  //  Removed _isConnectMode, _firstConnectAnnotation, 
  //  enableConnectMode(), disableConnectMode(), 
  //  _handleConnectModeClick() for the new approach.
  // -----------------------------------------------------

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
    // Listen for user taps on annotations
    annotationsManager.pointAnnotationManager.addOnPointAnnotationClickListener(
      MyPointAnnotationClickListener((clickedAnnotation) {
        logger.i('Annotation tapped: ${clickedAnnotation.id}');

        // Normal flow: attempt to show details
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
      orElse: () => Annotation(id: 'notFound')
    );
    if (ann.id != 'notFound') {
      showAnnotationDetailsDialog(context, ann);
    } else {
      logger.w('No matching Hive annotation found for id: $id');
    }
  }

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
        _selectedAnnotation = await annotationsManager.findNearestAnnotation(pressPoint);
        if (_selectedAnnotation != null) {
          try {
            _originalPoint = Point.fromJson({
              'type': 'Point',
              'coordinates': [
                _selectedAnnotation!.geometry.coordinates[0],
                _selectedAnnotation!.geometry.coordinates[1],
              ],
            });
            logger.i('Original point stored: ${_originalPoint?.coordinates} for annotation ${_selectedAnnotation?.id}');
          } catch (e) {
            logger.e('Error storing original point: $e');
          }
          onAnnotationLongPress?.call(_selectedAnnotation!, _originalPoint!);
        } else {
          logger.w('No annotation found on long-press.');
        }
      }
    } catch (e) {
      logger.e('Error during feature query: $e');
    }
  }

  Future<void> handleDrag(ScreenCoordinate screenPoint) async {
    if (!_isDragging || _selectedAnnotation == null || _isProcessingDrag) return;
    final annotationToUpdate = _selectedAnnotation;
    if (annotationToUpdate == null) return;

    try {
      _isProcessingDrag = true;
      _lastDragScreenPoint = screenPoint;
      final newPoint = await mapboxMap.coordinateForPixel(screenPoint);
      if (!_isDragging || _selectedAnnotation == null) return;

      if (newPoint != null) {
        logger.i('Updating annotation ${annotationToUpdate.id} position to $newPoint');
        await annotationsManager.updateVisualPosition(annotationToUpdate, newPoint);
        onAnnotationDragUpdate?.call(annotationToUpdate);
      }
    } catch (e) {
      logger.e('Error during drag: $e');
    } finally {
      _isProcessingDrag = false;
    }
  }

  Future<void> endDrag() async {
    logger.i('Ending drag.');
    logger.i('Original point at end drag: ${_originalPoint?.coordinates}');
    final annotationToRemove = _selectedAnnotation;

    if (annotationToRemove != null &&
        _lastDragScreenPoint != null &&
        _trashCanHandler.isOverTrashCan(_lastDragScreenPoint!)) {
      logger.i('Annotation ${annotationToRemove.id} dropped over trash can. Showing removal dialog.');
      final shouldRemove = await _showRemoveConfirmationDialog();
      if (shouldRemove == true) {
        logger.i('User confirmed removal - removing annotation ${annotationToRemove.id}.');
        await annotationsManager.removeAnnotation(annotationToRemove);
        onAnnotationRemoved?.call();
      } else {
        logger.i('User cancelled removal - revert annotation to original position.');
        if (_originalPoint != null) {
          logger.i('Reverting annotation ${annotationToRemove.id} to ${_originalPoint?.coordinates}');
          await annotationsManager.updateVisualPosition(annotationToRemove, _originalPoint!);
        } else {
          logger.w('No original point stored, cannot revert.');
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
            // QUICK-SAVE path
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

              // Link map annotation ID → Hive ID using annotationIdLinker
              annotationIdLinker.registerAnnotationId(mapAnnotation.id, id);
              logger.i('Linked mapAnnotation.id=${mapAnnotation.id} with hiveUUID=$id');
            } else {
              logger.w('No long press point stored, cannot place annotation (quickSave).');
            }
          } else {
            // Continue: show the final form
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
    final result = await showAnnotationFormDialog(
      context,
      title: _chosenTitle ?? '',
      chosenIcon: Icons.star,
      chosenIconName: _chosenIconName,
      date: _chosenStartDate ?? '',
      endDate: _chosenEndDate ?? '',
    );
    logger.i('Annotation form dialog returned: $result');

    if (result != null) {
      if (result['action'] == 'change') {
        // The user wants to go back & modify initial fields
        final changedTitle = result['title'] ?? '';
        final changedIcon = result['icon'] ?? 'cross';
        final changedStartDate = result['date'] ?? '';
        final changedEndDate = result['endDate'] ?? '';

        logger.i('User chose to change initial fields.');
        final secondInitResult = await showAnnotationInitializationDialog(
          context,
          initialTitle: changedTitle,
          initialIconName: changedIcon,
          initialDate: changedStartDate,
          initialEndDate: changedEndDate,
        );

        logger.i('Second initialization dialog returned: $secondInitResult');
        if (secondInitResult != null) {
          _chosenTitle = secondInitResult['title'] as String?;
          _chosenIconName = secondInitResult['icon'] as String;
          _chosenStartDate = secondInitResult['date'] as String?;
          _chosenEndDate = secondInitResult['endDate'] as String?;

          final bool newQuickSave = (secondInitResult['quickSave'] == true);
          if (newQuickSave) {
            // QuickSave after they changed fields
            if (_longPressPoint != null) {
              logger.i('Adding annotation (quickSave after change) at ${_longPressPoint?.coordinates}.');

              final bytes = await rootBundle.load('assets/icons/$_chosenIconName.png');
              final imageData = bytes.buffer.asUint8List();

              final mapAnnotation = await annotationsManager.addAnnotation(
                _longPressPoint!,
                image: imageData,
                title: _chosenTitle ?? '',
                date: _chosenStartDate ?? '',
              );
              logger.i('Annotation added at ${_longPressPoint?.coordinates}, ID: ${mapAnnotation.id}');

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

              // Link the map annotation to the Hive ID
              annotationIdLinker.registerAnnotationId(mapAnnotation.id, id);
              logger.i('Linked mapAnnotation.id=${mapAnnotation.id} with hiveUUID=$id');
            } else {
              logger.w('No long press point stored, cannot place annotation (quickSave after change).');
            }
          } else {
            // Show final form again
            await startFormDialogFlow();
          }
        } else {
          logger.i('User cancelled after choosing change - no annotation added.');
        }
      } else {
        // =========== FINAL SAVE or CANCEL ===========
        final note = result['note'] ?? '';
        final imagePath = result['imagePath'];
        final filePath = result['filePath'];
        final endDate = result['endDate'] ?? '';

        logger.i('User entered note: $note, imagePath: $imagePath, filePath: $filePath');

        if (_longPressPoint != null) {
          logger.i('Adding annotation at ${_longPressPoint?.coordinates} with chosen data.');
          final bytes = await rootBundle.load('assets/icons/$_chosenIconName.png');
          final imageData = bytes.buffer.asUint8List();

          final mapAnnotation = await annotationsManager.addAnnotation(
            _longPressPoint!,
            image: imageData,
            title: _chosenTitle ?? '',
            date: _chosenStartDate ?? '',
          );
          logger.i('Annotation added at ${_longPressPoint?.coordinates}, MapboxID=${mapAnnotation.id}');

          final id = uuid.v4();
          final latitude = _longPressPoint!.coordinates.lat.toDouble();
          final longitude = _longPressPoint!.coordinates.lng.toDouble();

          final annotation = Annotation(
            id: id,
            title: _chosenTitle?.isNotEmpty == true ? _chosenTitle : null,
            iconName: _chosenIconName.isNotEmpty ? _chosenIconName : null,
            startDate: _chosenStartDate?.isNotEmpty == true ? _chosenStartDate : null,
            endDate: endDate.isNotEmpty ? endDate : null,
            note: note.isNotEmpty ? note : null,
            latitude: latitude,
            longitude: longitude,
            imagePath: (imagePath != null && imagePath.isNotEmpty) ? imagePath : null,
          );

          await localAnnotationsRepository.addAnnotation(annotation);
          logger.i('Annotation saved to Hive with id: $id');

          // Link map annotation → Hive ID
          annotationIdLinker.registerAnnotationId(mapAnnotation.id, id);
          logger.i('Linked mapAnnotation.id=${mapAnnotation.id} with hiveUUID=$id');
        } else {
          logger.i('User cancelled or no long press point stored - no annotation added.');
        }
      }
    } else {
      logger.i('User cancelled the annotation form dialog - no annotation added.');
    }
  }

  void cancelTimer() {
    logger.i('Cancelling timers and resetting state');
    _longPressTimer?.cancel();
    _placementDialogTimer?.cancel();
    _longPressTimer = null;
    _placementDialogTimer = null;
    _longPressPoint = null;
    _selectedAnnotation = null;
    _isOnExistingAnnotation = false;
    _isDragging = false;
    _isProcessingDrag = false;
    _originalPoint = null;
  }

  /// Start dragging
  void startDraggingSelectedAnnotation() {
    logger.i('User chose to move annotation. Starting drag mode.');
    _isDragging = true;
    _isProcessingDrag = false;
    _trashCanHandler.showTrashCan();
  }

  /// Stop dragging
  void hideTrashCanAndStopDragging() {
    logger.i('Locking annotation in place and hiding trash can.');
    _isDragging = false;
    _isProcessingDrag = false;
    _trashCanHandler.hideTrashCan();
  }
}