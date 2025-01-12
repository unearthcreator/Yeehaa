import 'package:flutter/material.dart';

class ZoomIndicator extends StatefulWidget {
  final TransformationController controller; // Use TransformationController directly

  const ZoomIndicator({required this.controller, super.key});

  @override
  ZoomIndicatorState createState() => ZoomIndicatorState();
}

class ZoomIndicatorState extends State<ZoomIndicator> {
  late double _currentZoom;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.controller.value.getMaxScaleOnAxis(); // Initialize zoom level
    widget.controller.addListener(_onZoomChanged); // Add listener for zoom changes
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onZoomChanged); // Clean up the listener
    super.dispose();
  }

  // Method to handle zoom level changes
  void _onZoomChanged() {
    if (!mounted) return; // Ensure the widget is still in the tree before updating

    setState(() {
      _currentZoom = widget.controller.value.getMaxScaleOnAxis(); // Update the zoom level when it changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Zoom: ${_currentZoom.toStringAsFixed(1)}x', // Display zoom level with one decimal point
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}