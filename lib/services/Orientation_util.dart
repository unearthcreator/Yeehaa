// orientation_util.dart
import 'package:flutter/services.dart';
import 'package:map_mvp_project/services/error_handler.dart';   // Import logger for logging

Future<void> lockOrientation() async {
  try {
    logger.i('Locking orientation to landscape modes');
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    logger.i('Orientation locked successfully');
  } catch (e, stackTrace) {
    logger.e('Error setting orientation', error: e, stackTrace: stackTrace);
  }
}