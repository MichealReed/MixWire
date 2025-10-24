import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConnectionPainter extends CustomPainter {
  final Map<String, Offset> inputPositions;
  final Map<String, Offset> outputPositions;
  final Map<String, Set<String>> connections;
  final String? draggingFrom;
  final Offset? dragPosition;
  final double animationValue;

  ConnectionPainter({
    required this.inputPositions,
    required this.outputPositions,
    required this.connections,
    this.draggingFrom,
    this.dragPosition,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw established connections
    for (final entry in connections.entries) {
      final inputId = entry.key;
      final outputIds = entry.value;
      final inputPos = inputPositions[inputId];

      if (inputPos != null) {
        for (final outputId in outputIds) {
          final outputPos = outputPositions[outputId];
          if (outputPos != null) {
            _drawElectricCable(canvas, inputPos, outputPos, Colors.cyan, true);
          }
        }
      }
    }

    // Draw dragging cable
    if (draggingFrom != null && dragPosition != null) {
      final startPos = inputPositions[draggingFrom];
      if (startPos != null) {
        _drawElectricCable(
          canvas,
          startPos,
          dragPosition!,
          Colors.purple.withOpacity(0.8),
          false,
        );
      }
    }
  }

  void _drawElectricCable(
    Canvas canvas,
    Offset start,
    Offset end,
    Color baseColor,
    bool isConnected,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Calculate control points for a smooth S-curve
    final distance = (end.dx - start.dx).abs();
    final controlOffset = distance * 0.4;

    final controlPoint1 = Offset(start.dx + controlOffset, start.dy);
    final controlPoint2 = Offset(end.dx - controlOffset, end.dy);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      end.dx,
      end.dy,
    );

    // Outer glow (widest)
    final glowPaint = Paint()
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..color = baseColor.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, glowPaint);

    // Middle glow
    final midGlowPaint = Paint()
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..color = baseColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, midGlowPaint);

    // Core cable
    final corePaint = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..color = baseColor
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, corePaint);

    // Animated energy pulse for connected cables
    if (isConnected) {
      _drawEnergyPulse(canvas, path, baseColor);
    }

    // Inner bright line
    final brightPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.9)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, brightPaint);

    // Draw connection endpoints (plugs)
    _drawPlug(canvas, start, baseColor, true);
    _drawPlug(canvas, end, baseColor, false);
  }

  void _drawPlug(Canvas canvas, Offset position, Color color, bool isOutput) {
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(position, 8, glowPaint);

    // Plug body
    final plugPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 4, plugPaint);

    // Bright center
    final brightPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 2, brightPaint);
  }

  void _drawEnergyPulse(Canvas canvas, Path path, Color color) {
    final metrics = path.computeMetrics().first;
    final pulseCount = 3;

    for (int i = 0; i < pulseCount; i++) {
      final offset = (animationValue + (i / pulseCount)) % 1.0;
      final position = metrics
          .getTangentForOffset(metrics.length * offset)
          ?.position;

      if (position != null) {
        // Outer glow
        final glowPaint = Paint()
          ..color = color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(position, 6, glowPaint);

        // Energy particle
        final particlePaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(position, 3, particlePaint);

        // Bright center
        final brightParticlePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(position, 1.5, brightParticlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(ConnectionPainter oldDelegate) => true;
}
