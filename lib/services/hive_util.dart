// services/hive_util.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // Assuming you have a logger setup

/// Initializes Hive for local data storage.
Future<void> initializeHive() async {
  try {
    await Hive.initFlutter();
    logger.i('Hive initialized successfully.');
  } catch (e, stackTrace) {
    logger.e('Failed to initialize Hive.', error: e, stackTrace: stackTrace);
    rethrow; // Optionally, rethrow the error to handle it elsewhere
  }
}