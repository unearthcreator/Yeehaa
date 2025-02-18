import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// ---------------------- External & Project Imports ----------------------
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/gestures/map_gesture_handler.dart';
import 'package:map_mvp_project/src/earth_map/utils/map_config.dart';
import 'package:uuid/uuid.dart'; // for unique IDs

import 'package:map_mvp_project/src/earth_map/timeline/timeline.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_id_linker.dart';
import 'package:map_mvp_project/models/world_config.dart';
import 'package:map_mvp_project/src/earth_map/search/search_widget.dart';
import 'package:map_mvp_project/src/earth_map/misc/test_utils.dart';

// Our new code for annotation actions & the annotation menu:
import 'package:map_mvp_project/src/earth_map/annotations/annotations_menu/annotation_menu_actions.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotations_menu/annotation_menu_buttons.dart';

/// The main EarthMapPage, which sets up the map, annotations, and various UI widgets.
class EarthMapPage extends StatefulWidget {
  final WorldConfig worldConfig;

  const EarthMapPage({Key? key, required this.worldConfig}) : super(key: key);

  @override
  EarthMapPageState createState() => EarthMapPageState();
}

class EarthMapPageState extends State<EarthMapPage> {
  // ---------------------- Map-Related Variables ----------------------
  late MapboxMap _mapboxMap;
  late MapAnnotationsManager _annotationsManager;
  late MapGestureHandler _gestureHandler;
  late LocalAnnotationsRepository _localRepo;
  bool _isMapReady = false;

  // ---------------------- Timeline / Canvas UI ----------------------
  final List<String> _hiveUuidsForTimeline = [];
  bool _showTimelineCanvas = false;

  // ---------------------- Annotation Menu Variables ----------------------
  bool _showAnnotationMenu = false;
  PointAnnotation? _annotationMenuAnnotation;
  Offset _annotationMenuOffset = Offset.zero;

  // ---------------------- Dragging & Connect Mode ----------------------
  bool _isDragging = false; // "Move" mode toggle
  bool _isConnectMode = false;

  // If we’re in dragging mode, button says "Lock," else "Move."
  String get _annotationButtonText => _isDragging ? 'Lock' : 'Move';

  // ---------------------- UUID Generator ----------------------
  final uuid = Uuid();

  // ---------------------- Domain Logic (Actions) ----------------------
  late AnnotationActions _annotationActions;

  // ---------------------------------------------------------------------
  //                            LIFECYCLE
  // ---------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    logger.i('Initializing EarthMapPage');
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------
  //                       MAP CREATION / INIT
  // ---------------------------------------------------------------------
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    try {
      logger.i('Starting map initialization');
      _mapboxMap = mapboxMap;

      // Create the underlying Mapbox annotation manager
      final annotationManager = await mapboxMap.annotations
          .createPointAnnotationManager()
          .onError((error, stackTrace) {
        logger.e('Failed to create annotation manager',
            error: error, stackTrace: stackTrace);
        throw Exception('Failed to initialize map annotations');
      });

      // Local repo + annotation linker
      _localRepo = LocalAnnotationsRepository();
      final annotationIdLinker = AnnotationIdLinker();

      // MapAnnotationsManager
      _annotationsManager = MapAnnotationsManager(
        annotationManager,
        annotationIdLinker: annotationIdLinker,
        localAnnotationsRepository: _localRepo,
      );

      // MapGestureHandler
      _gestureHandler = MapGestureHandler(
        mapboxMap: _mapboxMap,
        annotationsManager: _annotationsManager,
        context: context,
        localAnnotationsRepository: _localRepo,
        annotationIdLinker: annotationIdLinker,
        onAnnotationLongPress: _handleAnnotationLongPress,
        onAnnotationDragUpdate: _handleAnnotationDragUpdate,
        onDragEnd: _handleDragEnd,
        onAnnotationRemoved: _handleAnnotationRemoved,
        onConnectModeDisabled: () {
          setState(() {
            _isConnectMode = false;
          });
        },
      );

      // Domain logic: editing, connecting, moving, etc.
      _annotationActions = AnnotationActions(
        localRepo: _localRepo,
        annotationsManager: _annotationsManager,
        annotationIdLinker: annotationIdLinker,
      );

      logger.i('Map initialization completed successfully');

      if (mounted) {
        setState(() => _isMapReady = true);
        await _annotationsManager.loadAnnotationsFromHive();
      }

    } catch (e, stackTrace) {
      logger.e('Error during map initialization', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {});
      }
    }
  }

  // ---------------------------------------------------------------------
  //                 ANNOTATION UI & CALLBACKS
  // ---------------------------------------------------------------------
  void _handleAnnotationLongPress(PointAnnotation annotation, Point annotationPosition) async {
    final screenPos = await _mapboxMap.pixelForCoordinate(annotationPosition);
    setState(() {
      _annotationMenuAnnotation = annotation;
      _showAnnotationMenu = true;
      _annotationMenuOffset = Offset(screenPos.x + 30, screenPos.y);
    });
  }

  void _handleAnnotationDragUpdate(PointAnnotation annotation) async {
    final screenPos = await _mapboxMap.pixelForCoordinate(annotation.geometry);
    setState(() {
      _annotationMenuAnnotation = annotation;
      _annotationMenuOffset = Offset(screenPos.x + 30, screenPos.y);
    });
  }

  void _handleDragEnd() {
    // Called when user lifts finger from a drag
  }

  void _handleAnnotationRemoved() {
    setState(() {
      _showAnnotationMenu = false;
      _annotationMenuAnnotation = null;
      _isDragging = false;
    });
  }

  // ---------------------------------------------------------------------
  //                        LONG PRESS HANDLERS
  // ---------------------------------------------------------------------
  void _handleLongPress(LongPressStartDetails details) {
    try {
      final screenPoint = ScreenCoordinate(
        x: details.localPosition.dx,
        y: details.localPosition.dy,
      );
      _gestureHandler.handleLongPress(screenPoint);
    } catch (e, stackTrace) {
      logger.e('Error handling long press', error: e, stackTrace: stackTrace);
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_isDragging) {
      final screenPoint = ScreenCoordinate(
        x: details.localPosition.dx,
        y: details.localPosition.dy,
      );
      _gestureHandler.handleDrag(screenPoint);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (_isDragging) {
      _gestureHandler.endDrag();
    }
  }

  // ---------------------------------------------------------------------
  //                         MENU BUTTON CALLBACKS
  // ---------------------------------------------------------------------
  void _handleMoveOrLockButton() {
    setState(() {
      // If we aren't dragging => user clicks "Move"
      if (!_isDragging) {
        if (_annotationMenuAnnotation != null) {
          _annotationActions.startMoveAnnotation(_annotationMenuAnnotation!);
        }
        _isDragging = true;
      } else {
        // If we are dragging => user clicks "Lock"
        // We can finalize or just cancel.
        if (_annotationMenuAnnotation != null) {
          // Example: finalize the location in Hive
          _annotationActions.finishMoveAnnotation(_annotationMenuAnnotation!.geometry);
        }
        _isDragging = false;
      }
    });
  }

  Future<void> _handleEditButton() async {
    if (_annotationMenuAnnotation == null) {
      logger.w('No annotation selected to edit.');
      return;
    }
    await _annotationActions.editAnnotation(
      context: context,
      mapAnnotation: _annotationMenuAnnotation!,
    );
    setState(() {});
  }

  void _handleConnectButton() {
    setState(() {
      _showAnnotationMenu = false;
      if (_isDragging) {
        _annotationActions.cancelMoveAnnotation();
        _isDragging = false;
      }
      _isConnectMode = true;
    });

    if (_annotationMenuAnnotation != null) {
      _annotationActions.startConnectMode(_annotationMenuAnnotation!);
    } else {
      logger.w('No annotation to connect');
    }
  }

  void _handleCancelButton() {
    setState(() {
      _showAnnotationMenu = false;
      _annotationMenuAnnotation = null;
      if (_isDragging) {
        _annotationActions.cancelMoveAnnotation();
        _isDragging = false;
      }
    });
  }

  // ---------------------------------------------------------------------
  //                         UI BUILDERS
  // ---------------------------------------------------------------------
  Widget _buildMapWidget() {
    return GestureDetector(
      onLongPressStart: _handleLongPress,
      onLongPressMoveUpdate: _handleLongPressMoveUpdate,
      onLongPressEnd: _handleLongPressEnd,
      onLongPressCancel: () {
        if (_isDragging) {
          _gestureHandler.endDrag();
        }
      },
      child: MapWidget(
        cameraOptions: MapConfig.defaultCameraOptions,
        styleUri: MapConfig.styleUriEarth,
        onMapCreated: _onMapCreated,
      ),
    );
  }

  // ---------------------------------------------------------------------
  //                           BUILD METHOD
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // -------------------- Main Map --------------------
          _buildMapWidget(),

          // Only show the rest if the map is ready
          if (_isMapReady) ...[
            // -------------------- Timeline --------------------
            buildTimelineButton(
              isMapReady: _isMapReady,
              context: context,
              mapboxMap: _mapboxMap,
              annotationsManager: _annotationsManager,
              onToggleTimeline: () {
                setState(() {
                  _showTimelineCanvas = !_showTimelineCanvas;
                });
              },
              onHiveIdsFetched: (List<String> hiveIds) {
                setState(() {
                  _hiveUuidsForTimeline.clear();
                  _hiveUuidsForTimeline.addAll(hiveIds);
                });
              },
            ),

            // Debug utility buttons
            buildClearAnnotationsButton(annotationsManager: _annotationsManager),
            buildClearImagesButton(),
            buildDeleteImagesFolderButton(),

            // -------------------- Search Widget --------------------
            EarthMapSearchWidget(
              mapboxMap: _mapboxMap,
              annotationsManager: _annotationsManager,
              gestureHandler: _gestureHandler,
              localRepo: _localRepo,
              uuid: uuid,
            ),

            // -------------------- Annotation Menu --------------------
            AnnotationMenu(
              show: _showAnnotationMenu,
              annotation: _annotationMenuAnnotation,
              offset: _annotationMenuOffset,
              isDragging: _isDragging, 
              annotationButtonText: _annotationButtonText,
              onMoveOrLock: _handleMoveOrLockButton,
              onEdit: _handleEditButton,
              onConnect: _handleConnectButton,
              onCancel: _handleCancelButton,
            ),

            // -------------------- Connect Banner --------------------
            _annotationActions.buildConnectModeBanner(
              isConnectMode: _isConnectMode,
              onCancel: () {
                setState(() => _isConnectMode = false);
                _annotationActions.cancelConnectMode();
              },
              mapboxMap: _mapboxMap,
            ),

            // -------------------- "Move" Overlay --------------------
            _annotationActions.buildMoveOverlay(
              isMoveMode: _isDragging,
              mapboxMap: _mapboxMap,
            ),

            // -------------------- Timeline Canvas --------------------
            buildTimelineCanvas(
              showTimelineCanvas: _showTimelineCanvas,
              hiveUuids: _hiveUuidsForTimeline,
            ),
          ],
        ],
      ),
    );
  }
}
