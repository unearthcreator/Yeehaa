import 'package:flutter/material.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // For logging

class MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const MenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Log when the widget is built
    logger.i('Rendering MenuButton: $label');

    // Check for an empty label and log a warning
    if (label.isEmpty) {
      logger.w('MenuButton has an empty label.');
    }

    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: Colors.blueGrey[700], // Background color of button
          foregroundColor: Colors.white,         // General text/icon color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Rounded corners
          ),
        ),
        icon: Icon(
          icon,
          size: 24,
          color: Colors.white,
        ),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          try {
            onPressed();
          } catch (e, stackTrace) {
            // Log any errors that occur during the button press
            logger.e('Error occurred in MenuButton "$label" onPressed', error: e, stackTrace: stackTrace);
          }
        },
      ),
    );
  }
}