import 'package:flutter/widgets.dart';

class MapTransformationController {
  final TransformationController _controller = TransformationController();

  TransformationController get controller => _controller;

  double getZoomLevel() {
    // Extract the scale value from the transformation matrix
    return _controller.value.getMaxScaleOnAxis();
  }

  void reset() {
    // Resets the controller to the default state
    _controller.value = Matrix4.identity();
  }

  void dispose() {
    // Disposes of the controller when no longer needed
    _controller.dispose();
  }
}