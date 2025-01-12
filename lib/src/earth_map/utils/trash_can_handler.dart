import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrashCanHandler {
  final BuildContext context;
  OverlayEntry? _trashCanOverlayEntry;

  // Adjust these values as needed
  final double _size = 50.0;
  final double _margin = 16.0;

  TrashCanHandler({required this.context});

  void showTrashCan() {
    if (_trashCanOverlayEntry != null) return; // Already shown

    _trashCanOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: _margin,
        right: _margin,
        child: Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ),
    );

    Overlay.of(context)?.insert(_trashCanOverlayEntry!);
  }

  void hideTrashCan() {
    _trashCanOverlayEntry?.remove();
    _trashCanOverlayEntry = null;
  }

  bool isOverTrashCan(ScreenCoordinate screenPoint) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Top-left coordinates of the trash can:
    final double trashCanLeft = screenWidth - _margin - _size;
    final double trashCanTop = screenHeight - _margin - _size;

    return (screenPoint.x >= trashCanLeft &&
            screenPoint.x <= trashCanLeft + _size &&
            screenPoint.y >= trashCanTop &&
            screenPoint.y <= trashCanTop + _size);
  }
}