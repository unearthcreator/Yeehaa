import 'package:flutter/material.dart';
import 'package:map_mvp_project/services/error_handler.dart';

class WorldSelectorButtons extends StatelessWidget {
  /// Callback to invoke when the user taps "Clear All" worlds
  final VoidCallback? onClearAll;

  const WorldSelectorButtons({
    super.key,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    logger.i('Building WorldSelectorButtons widget');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // (A) Back button on the left
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              try {
                Navigator.pop(context);
                logger.i('WorldSelectorButtons: Back button pressed -> pop');
              } catch (e, stackTrace) {
                logger.e(
                  'WorldSelectorButtons: Error navigating back',
                  error: e,
                  stackTrace: stackTrace,
                );
              }
            },
          ),

          // (B) "Clear All" ElevatedButton on the right
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,    // Red background
              foregroundColor: Colors.white,  // White text/icons
            ),
            onPressed: () {
              logger.i('Clear All Worlds button tapped');
              if (onClearAll != null) {
                onClearAll!();  // call the passed-in callback
              }
            },
            child: const Text('Clear all worlds'),
          ),
        ],
      ),
    );
  }
}