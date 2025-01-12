import 'package:flutter/material.dart';
import 'dart:ui' as ui; // We'll use ui.Size for clarity
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // for logger
import 'package:map_mvp_project/src/earth_map/timeline/painter/utils/timeline_axis.dart';

// Adjust the above imports according to your actual folder structure

class TimelinePainter extends CustomPainter {
  final List<Annotation> annotationList;

  TimelinePainter({required this.annotationList});

  @override
  void paint(Canvas canvas, ui.Size size) {
    // White background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw the bottom axis line using your utility function
    drawTimelineAxis(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class TimelineView extends StatelessWidget {
  final List<Annotation> annotationList;

  const TimelineView({
    Key? key,
    required this.annotationList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TimelinePainter(annotationList: annotationList),
      // The parent (earth_map_page) will size this widget as needed.
    );
  }
}