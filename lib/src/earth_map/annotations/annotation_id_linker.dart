import 'package:flutter/foundation.dart';

/// A utility class to link Mapbox annotation IDs to Hive annotation IDs.
/// 
/// - `mapAnnotationId` is the ID returned by Mapbox when we create annotations.
/// - `hiveId` is the unique ID of the annotation stored in Hive.
/// 
/// You can register a new link whenever you create a new annotation or 
/// when you load annotations from Hive and place them on the map.
/// Then, if you need to look up which Hive annotation an on-screen annotation 
/// corresponds to, call `getHiveIdForMapId(...)`.

class AnnotationIdLinker {
  /// Internal mapping from mapAnnotationId (String) to hiveId (String).
  final Map<String, String> _idMap = {};

  /// Registers a link between a Mapbox annotation ID and a Hive annotation ID.
  void registerAnnotationId(String mapAnnotationId, String hiveId) {
    _idMap[mapAnnotationId] = hiveId;
    debugPrint('AnnotationIdLinker: Linked $mapAnnotationId to Hive ID: $hiveId');
  }

  /// Retrieves the Hive ID for the given mapAnnotationId, if any.
  String? getHiveIdForMapId(String mapAnnotationId) {
    return _idMap[mapAnnotationId];
  }

  /// Retrieves the Hive IDs for a list of Mapbox annotation IDs, ignoring those
  /// that have no mapping.
  List<String> getHiveIdsForMultipleAnnotations(List<String> mapboxIds) {
    final List<String> result = [];
    for (final mapboxId in mapboxIds) {
      final hiveId = _idMap[mapboxId];
      if (hiveId != null) {
        result.add(hiveId);
      } else {
        // Optionally log or handle the missing mapping
      }
    }
    return result;
  }

  /// Removes the link for a given mapAnnotationId, if it exists.
  void removeLink(String mapAnnotationId) {
    _idMap.remove(mapAnnotationId);
  }

  /// Clears all mappings.
  void clearAll() {
    _idMap.clear();
  }
}