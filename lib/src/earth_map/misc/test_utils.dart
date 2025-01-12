// File: testing_utils.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // For logger
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Returns a Positioned button that clears all annotations from Hive + the map.
/// [annotationsManager] is needed to remove all map annotations.
Widget buildClearAnnotationsButton({
  required MapAnnotationsManager annotationsManager,
}) {
  return Positioned(
    top: 40,
    right: 10,
    child: ElevatedButton(
      onPressed: () async {
        logger.i('Clear button pressed - clearing all annotations from Hive and from the map.');

        // 1) Remove all from Hive
        final box = await Hive.openBox<Map>('annotationsBox');
        await box.clear();
        logger.i('After clearing, the "annotationsBox" has ${box.length} items.');
        await box.close();
        logger.i('Annotations cleared from Hive.');

        // 2) Remove all from the map visually
        await annotationsManager.removeAllAnnotations();
        logger.i('All annotations removed from the map.');
        logger.i('Done clearing. You can now add new annotations.');
      },
      child: const Text('Clear Annotations'),
    ),
  );
}

/// Returns a Positioned button that clears all image files in the app's images folder.
Widget buildClearImagesButton() {
  return Positioned(
    top: 90,
    right: 10,
    child: ElevatedButton(
      onPressed: () async {
        logger.i('Clear images button pressed - clearing images folder files.');
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(appDir.path, 'images'));

        if (await imagesDir.exists()) {
          final files = imagesDir.listSync();
          for (var file in files) {
            if (file is File) {
              await file.delete();
            }
          }
          logger.i('All image files cleared from ${imagesDir.path}');
        } else {
          logger.i('Images directory does not exist, nothing to clear.');
        }
      },
      child: const Text('Clear Images'),
    ),
  );
}

/// Returns a Positioned button that deletes the entire images folder in the app directory.
Widget buildDeleteImagesFolderButton() {
  return Positioned(
    top: 140,
    right: 10,
    child: ElevatedButton(
      onPressed: () async {
        logger.i('Delete images folder button pressed - deleting entire images folder.');
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(appDir.path, 'images'));

        if (await imagesDir.exists()) {
          await imagesDir.delete(recursive: true);
          logger.i('Images directory deleted.');
        } else {
          logger.i('Images directory does not exist, nothing to delete.');
        }
      },
      child: const Text('Delete Images Folder'),
    ),
  );
}