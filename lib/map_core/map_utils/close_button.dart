import 'package:flutter/material.dart';

class CloseButtonWidget extends StatelessWidget {
  final VoidCallback onPressed;

  const CloseButtonWidget({required this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5), // Set a background color for visibility
          shape: BoxShape.circle, // Make it circular for better aesthetics
        ),
        child: IconButton(
          icon: const Icon(Icons.close),
          color: Colors.white, // Make the icon white for contrast
          onPressed: onPressed,
        ),
      ),
    );
  }
}