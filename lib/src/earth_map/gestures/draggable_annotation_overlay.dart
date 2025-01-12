import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DraggableAnnotationOverlay extends StatefulWidget {
  final Point initialPosition;
  final Function(Point) onDragUpdate;
  final VoidCallback onDragEnd;
  final MapboxMap mapboxMap;

  const DraggableAnnotationOverlay({
    Key? key,
    required this.initialPosition,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.mapboxMap,
  }) : super(key: key);

  @override
  State<DraggableAnnotationOverlay> createState() => _DraggableAnnotationOverlayState();
}

class _DraggableAnnotationOverlayState extends State<DraggableAnnotationOverlay> {
  Offset _position = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initializePosition();
  }

  Future<void> _initializePosition() async {
    final screenPoint = await widget.mapboxMap.pixelForCoordinate(widget.initialPosition);
    setState(() {
      _position = Offset(screenPoint.x, screenPoint.y);
    });
  }

  @override
  void didUpdateWidget(DraggableAnnotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPosition != widget.initialPosition) {
      _initializePosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _position.dx - 15, // Center the widget on the position
          top: _position.dy - 15,
          child: GestureDetector(
            onPanUpdate: (details) async {
              final newPosition = Offset(
                _position.dx + details.delta.dx,
                _position.dy + details.delta.dy,
              );
              
              final screenCoord = ScreenCoordinate(
                x: newPosition.dx,
                y: newPosition.dy,
              );
              
              final mapPoint = await widget.mapboxMap.coordinateForPixel(screenCoord);
              widget.onDragUpdate(mapPoint);
              
              setState(() {
                _position = newPosition;
              });
            },
            onPanEnd: (details) {
              widget.onDragEnd();
            },
            child: _buildDragWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildDragWidget() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}