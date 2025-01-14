// annotation_menu.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class AnnotationMenu extends StatelessWidget {
  final bool show;
  final PointAnnotation? annotation;
  final Offset offset;
  final bool isDragging;              // <-- Tells us if "Move mode" is active
  final String annotationButtonText;

  // Callbacks for actions in the menu
  final VoidCallback onMoveOrLock;
  final VoidCallback onEdit;
  final VoidCallback onConnect;
  final VoidCallback onCancel;

  const AnnotationMenu({
    Key? key,
    required this.show,
    required this.annotation,
    required this.offset,
    required this.isDragging,
    required this.annotationButtonText,
    required this.onMoveOrLock,
    required this.onEdit,
    required this.onConnect,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If we shouldn't show or no annotation, return nothing
    if (!show || annotation == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // -----------------------------------------------------------
          // 1) Move/Lock button (always visible)
          // -----------------------------------------------------------
          ElevatedButton(
            onPressed: onMoveOrLock,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: Text(annotationButtonText), 
            // e.g. "Move" when isDragging == false, "Lock" when isDragging == true
          ),

          // -----------------------------------------------------------
          // 2) The other three buttons
          // Only show them if isDragging == false
          // -----------------------------------------------------------
          if (!isDragging) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onEdit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('Edit'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('Connect'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onCancel,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}