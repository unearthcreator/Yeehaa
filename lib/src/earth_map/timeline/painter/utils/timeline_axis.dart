import 'dart:ui'; // For Canvas, Size, Offset, etc.
import 'package:flutter/material.dart';

/// This utility will handle drawing the bottom axis line for the timeline.
void drawTimelineAxis(Canvas canvas, Size size) {
  // Let's assume 1cm ~ 38px as before. We'll place the line about 1cm above the bottom.
  // We'll also leave 1cm from the sides. That means:
  // Left margin: ~38px
  // Right margin: ~38px
  // Vertical position: size.height - 38px

  const double cmInPx = 38.0;
  final double leftMargin = cmInPx;
  final double rightMargin = cmInPx;
  final double verticalPos = size.height - cmInPx;

  final linePaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2.0; // a small line thickness

  canvas.drawLine(
    Offset(leftMargin, verticalPos),
    Offset(size.width - rightMargin, verticalPos),
    linePaint,
  );
}