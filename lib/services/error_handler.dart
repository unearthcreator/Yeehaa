// error_handler.dart
import 'dart:async'; // For runZonedGuarded
import 'package:flutter/foundation.dart'; // For FlutterError
import 'package:logger/logger.dart'; // Import logger

// Create the logger instance here
final logger = Logger(
  level: kReleaseMode ? Level.error : Level.debug, // Debug level in dev, error level in production
);

// Setup for Flutter framework error handling
void setupErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.e(
      'Flutter Error: ${details.exceptionAsString()}', 
      error: details.exception, 
      stackTrace: details.stack,
    );
  };
}

// Function to wrap app initialization with runZonedGuarded for async error handling
void runAppWithErrorHandling(Function() appInitialization) {
  runZonedGuarded(() {
    appInitialization();  // Call the app initialization passed as a function
  }, (error, stackTrace) {
    logger.e(
      'Uncaught error: $error', 
      error: error, 
      stackTrace: stackTrace,
    );
  });
}