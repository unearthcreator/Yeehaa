// annotation_actions.dart
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

class AnnotationActions {
  final LocalAnnotationsRepository localRepo;
  final MapAnnotationsManager annotationsManager;
  final AnnotationIdLinker annotationIdLinker;

  AnnotationActions({
    required this.localRepo,
    required this.annotationsManager,
    required this.annotationIdLinker,
  });

  /// Edits the given map annotation by retrieving its data from Hive,
  /// showing the form dialog, and updating it.
  Future<void> editAnnotation({
    required BuildContext context,
    required PointAnnotation? mapAnnotation,
  }) async {
    if (mapAnnotation == null) {
      logger.w('No annotation given, cannot edit.');
      return;
    }

    logger.i('Attempting to edit annotation with map ID: ${mapAnnotation.id}');

    // 1. Get the Hive ID from the linker
    final hiveId = annotationIdLinker.getHiveIdForMapId(mapAnnotation.id);
    logger.i('Hive ID from annotationIdLinker: $hiveId');

    if (hiveId == null) {
      logger.w('No hive ID found for this annotation.');
      return;
    }

    // 2. Load from Hive
    final allHiveAnnotations = await localRepo.getAnnotations();
    logger.i('Total annotations retrieved from Hive: ${allHiveAnnotations.length}');

    final ann = allHiveAnnotations.firstWhere(
      (a) => a.id == hiveId,
      orElse: () {
        logger.w('Annotation with hiveId: $hiveId not found in the list.');
        return Annotation(id: 'notFound');
      },
    );

    if (ann.id == 'notFound') {
      logger.w('Annotation not found in Hive.');
      return;
    } else {
      logger.i('Found annotation in Hive: $ann');
    }

    // 3. Show edit form
    final title = ann.title ?? '';
    final startDate = ann.startDate ?? '';
    final note = ann.note ?? '';
    final iconName = ann.iconName ?? 'cross';
    IconData chosenIcon = Icons.star;  // or however you pick an icon

    final result = await showAnnotationFormDialog(
      context,
      title: title,
      chosenIcon: chosenIcon,
      date: startDate,
      note: note,
    );

    if (result != null) {
      // 4. Build updated annotation
      final updatedNote = result['note'] ?? '';
      final updatedImagePath = result['imagePath'];

      logger.i('User edited note: $updatedNote, imagePath: $updatedImagePath');

      final updatedAnnotation = Annotation(
        id: ann.id,
        title: title.isNotEmpty ? title : null,
        iconName: iconName.isNotEmpty ? iconName : null,
        startDate: startDate.isNotEmpty ? startDate : null,
        endDate: ann.endDate,
        note: updatedNote.isNotEmpty ? updatedNote : null,
        latitude: ann.latitude ?? 0.0,
        longitude: ann.longitude ?? 0.0,
        imagePath: (updatedImagePath != null && updatedImagePath.isNotEmpty) 
            ? updatedImagePath 
            : ann.imagePath,
      );

      // 5. Update in Hive
      await localRepo.updateAnnotation(updatedAnnotation);
      logger.i('Annotation updated in Hive with id: ${ann.id}');

      // 6. Remove the old annotation visually & add the updated one
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

      // 7. Re-link the updated annotation
      annotationIdLinker.registerAnnotationId(
        newMapAnnotation.id,
        updatedAnnotation.id,
      );

      logger.i('Annotation visually updated on map.');
    } else {
      logger.i('User cancelled edit.');
    }
  }
}