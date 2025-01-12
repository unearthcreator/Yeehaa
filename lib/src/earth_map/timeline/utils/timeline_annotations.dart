import 'package:flutter/foundation.dart';
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // for logger

/// A small utility class for timeline logic related to annotations.
class TimelineAnnotations {
  // For simplicity, you can create a static LocalAnnotationsRepository here.
  // Alternatively, you could accept it as a parameter if you prefer a more flexible design.
  static final LocalAnnotationsRepository _localRepo = LocalAnnotationsRepository();

  /// Given a list of Hive IDs (annotation UUIDs), fetch those annotations
  /// from Hive and return them as a List.
  /// 
  /// - This is a static method for convenience, so you can call:
  ///   `TimelineAnnotations.fetchAnnotationsByUuids(hiveUuids)`
  ///   without instantiating TimelineAnnotations.
  static Future<List<Annotation>> fetchAnnotationsByUuids(List<String> hiveIds) async {
    logger.i('TimelineAnnotations: Received Hive IDs: $hiveIds');

    // Early return if empty
    if (hiveIds.isEmpty) {
      logger.i('No annotation IDs passed in; returning empty list.');
      return <Annotation>[];
    }

    // Fetch *all* annotations from Hive (or create a specialized method in
    // your LocalAnnotationsRepository that fetches only the requested IDs).
    final allAnnotations = await _localRepo.getAnnotations();

    // Filter the annotations so we only keep those matching the given IDs.
    final relevant = allAnnotations.where((ann) => hiveIds.contains(ann.id)).toList();

    if (relevant.isEmpty) {
      logger.w('No matching annotations found in Hive for these IDs: $hiveIds');
    } else {
      // Optionally log out the fields you care about:
      for (final ann in relevant) {
        final title = ann.title ?? '(no title)';
        final date  = ann.startDate ?? '(no startDate)';
        final icon  = ann.iconName ?? '(no icon)';
        logger.i('TimelineAnnotation => Title: $title, Date: $date, Icon: $icon');
      }
    }

    return relevant;
  }

  // You can still keep other helper methods here if needed:
  static Future<void> debugLogAnnotations(List<String> hiveIds) async {
    final results = await fetchAnnotationsByUuids(hiveIds);
    // We already log inside fetchAnnotationsByUuids, so this might be redundant.
  }
}