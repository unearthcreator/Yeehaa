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
import 'package:map_mvp_project/src/earth_map/annotations/annotation_menu.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_actions.dart';


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
  List<String> _hiveUuidsForTimeline = [];
  bool _showTimelineCanvas = false;

  // ---------------------- Annotation Menu Variables ----------------------
  bool _showAnnotationMenu = false;
  PointAnnotation? _annotationMenuAnnotation;
  Offset _annotationMenuOffset = Offset.zero;

  // ---------------------- Dragging & Connect Mode ----------------------
  bool _isDragging = false;
  bool _isConnectMode = false;  // Toggles the "Connect Banner"
  String get _annotationButtonText => _isDragging ? 'Lock' : 'Move';

  // ---------------------- UUID Generator ----------------------
  final uuid = Uuid();

  // 2. Reference to AnnotationActions for domain logic (edit, connect, etc.)
  late AnnotationActions _annotationActions;

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
        logger.e('Failed to create annotation manager', error: error, stackTrace: stackTrace);
        throw Exception('Failed to initialize map annotations');
      });

      // Create a single LocalAnnotationsRepository
      _localRepo = LocalAnnotationsRepository();

      // Create a *single* shared AnnotationIdLinker instance
      final annotationIdLinker = AnnotationIdLinker();

      // Create our MapAnnotationsManager
      _annotationsManager = MapAnnotationsManager(
        annotationManager,
        annotationIdLinker: annotationIdLinker,
        localAnnotationsRepository: _localRepo,
      );

      // Create the gesture handler
      _gestureHandler = MapGestureHandler(
        mapboxMap: mapboxMap,
        annotationsManager: _annotationsManager,
        context: context,
        localAnnotationsRepository: _localRepo,
        annotationIdLinker: annotationIdLinker,
        onAnnotationLongPress: _handleAnnotationLongPress,
        onAnnotationDragUpdate: _handleAnnotationDragUpdate,
        onDragEnd: _handleDragEnd,
        onAnnotationRemoved: _handleAnnotationRemoved,
        onConnectModeDisabled: () {
          // Called if MapGestureHandler had a disableConnectMode() callback
          setState(() {
            _isConnectMode = false;
          });
        },
      );

      // 3. Initialize your AnnotationActions
      _annotationActions = AnnotationActions(
        localRepo: _localRepo,
        annotationsManager: _annotationsManager,
        annotationIdLinker: annotationIdLinker,
      );

      logger.i('Map initialization completed successfully');

      // Once the map is ready, load saved Hive annotations
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
    // Show the annotation menu near the pressed location
    final screenPos = await _mapboxMap.pixelForCoordinate(annotationPosition);
    setState(() {
      _annotationMenuAnnotation = annotation;
      _showAnnotationMenu = true;
      _annotationMenuOffset = Offset(screenPos.x + 30, screenPos.y);
    });
  }

  void _handleAnnotationDragUpdate(PointAnnotation annotation) async {
    // Keep the annotation menu following the annotation during drag
    final screenPos = await _mapboxMap.pixelForCoordinate(annotation.geometry);
    setState(() {
      _annotationMenuAnnotation = annotation;
      _annotationMenuOffset = Offset(screenPos.x + 30, screenPos.y);
    });
  }

  void _handleDragEnd() {
    // Drag ended - no special action needed here
  }

  void _handleAnnotationRemoved() {
    // If an annotation is removed while the menu is open
    setState(() {
      _showAnnotationMenu = false;
      _annotationMenuAnnotation = null;
      _isDragging = false;
    });
  }

  // ---------------------------------------------------------------------
  //                          LONG PRESS HANDLERS
  // ---------------------------------------------------------------------
  void _handleLongPress(LongPressStartDetails details) {
    try {
      logger.i('Long press started at: ${details.localPosition}');
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
    try {
      if (_isDragging) {
        final screenPoint = ScreenCoordinate(
          x: details.localPosition.dx,
          y: details.localPosition.dy,
        );
        _gestureHandler.handleDrag(screenPoint);
      }
    } catch (e, stackTrace) {
      logger.e('Error handling drag update', error: e, stackTrace: stackTrace);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    try {
      logger.i('Long press ended');
      if (_isDragging) {
        _gestureHandler.endDrag();
      }
    } catch (e, stackTrace) {
      logger.e('Error handling long press end', error: e, stackTrace: stackTrace);
    }
  }

  // ---------------------------------------------------------------------
  //                         MENU BUTTON CALLBACKS
  // ---------------------------------------------------------------------
  void _handleMoveOrLockButton() {
    setState(() {
      if (_isDragging) {
        _gestureHandler.hideTrashCanAndStopDragging();
        _isDragging = false;
      } else {
        _gestureHandler.startDraggingSelectedAnnotation();
        _isDragging = true;
      }
    });
  }

  Future<void> _handleEditButton() async {
    if (_annotationMenuAnnotation == null) {
      logger.w('No annotation selected to edit.');
      return;
    }
    // Delegate the edit logic to AnnotationActions
    await _annotationActions.editAnnotation(
      context: context,
      mapAnnotation: _annotationMenuAnnotation!,
    );

    // Possibly refresh or hide the menu
    setState(() {});
  }

  /// "Connect" button callback: enable connect mode & call AnnotationActions
  void _handleConnectButton() {
    logger.i('Connect button clicked');
    setState(() {
      _showAnnotationMenu = false;
      if (_isDragging) {
        _gestureHandler.hideTrashCanAndStopDragging();
        _isDragging = false;
      }
      _isConnectMode = true; // triggers the connect banner
    });

    if (_annotationMenuAnnotation != null) {
      // If you still want to do "low-level connect" in the gesture handler:
      _annotationActions.startConnectMode(_annotationMenuAnnotation!);

      // Also call your domain logic in AnnotationActions
      _annotationActions.startConnectMode(_annotationMenuAnnotation!);
    } else {
      logger.w('No annotation available when Connect pressed');
    }
  }

  void _handleCancelButton() {
    setState(() {
      _showAnnotationMenu = false;
      _annotationMenuAnnotation = null;
      if (_isDragging) {
        _gestureHandler.hideTrashCanAndStopDragging();
        _isDragging = false;
      }
    });
  }

  // ---------------------------------------------------------------------
  //                            UI BUILDERS
  // ---------------------------------------------------------------------
  Widget _buildMapWidget() {
    return GestureDetector(
      onLongPressStart: _handleLongPress,
      onLongPressMoveUpdate: _handleLongPressMoveUpdate,
      onLongPressEnd: _handleLongPressEnd,
      onLongPressCancel: () {
        logger.i('Long press cancelled');
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
  //                            BUILD METHOD
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The main map widget
          _buildMapWidget(),

          // Only show these overlays if the map is ready
          if (_isMapReady) ...[
            // TIMELINE BUTTON
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
                  _hiveUuidsForTimeline = hiveIds;
                });
              },
            ),

            // DEBUG UTILITY BUTTONS
            buildClearAnnotationsButton(annotationsManager: _annotationsManager),
            buildClearImagesButton(),
            buildDeleteImagesFolderButton(),

            // SEARCH WIDGET
            EarthMapSearchWidget(
              mapboxMap: _mapboxMap,
              annotationsManager: _annotationsManager,
              gestureHandler: _gestureHandler,
              localRepo: _localRepo,
              uuid: uuid,
            ),

            // ANNOTATION MENU (Move/Edit/Connect/Cancel)
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

            // CONNECT MODE BANNER from annotation_actions.dart
            _annotationActions.buildConnectModeBanner(
              isConnectMode: _isConnectMode,
              onCancel: () {
                // If the user cancels from the banner:
                setState(() {
                  _isConnectMode = false;
                });
                // Reset domain logic in AnnotationActions
                _annotationActions.cancelConnectMode();
              },
              mapboxMap: _mapboxMap,
            ),

            // TIMELINE CANVAS
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