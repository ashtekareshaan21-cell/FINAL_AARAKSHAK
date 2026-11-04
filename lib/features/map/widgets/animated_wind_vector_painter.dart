import 'dart:math' as math;

import 'package:flutter/material.dart';

class WindParticle {
  double x;
  double y;
  double speed;
  double life;
  double maxLife;
  double size;

  WindParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.life,
    required this.maxLife,
    required this.size,
  });
}

class AnimatedWindVectorPainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0
  final double windSpeedKmh;
  final double windBearingDegrees;
  final int cloudCoveragePercent;
  final double cloudOpacity;
  final bool showWindParticles;
  final bool showWindVectors;
  final bool showCloudOverlay;

  final List<WindParticle> particles;

  AnimatedWindVectorPainter({
    required this.animationValue,
    required this.windSpeedKmh,
    required this.windBearingDegrees,
    required this.cloudCoveragePercent,
    required this.cloudOpacity,
    required this.showWindParticles,
    required this.showWindVectors,
    required this.showCloudOverlay,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Convert bearing (0° N, 90° E) to standard math angle in radians
    final mathAngle = (windBearingDegrees - 90) * math.pi / 180.0;
    final dirX = math.cos(mathAngle);
    final dirY = math.sin(mathAngle);

    // 1. Draw Cloud Moisture Overlay
    if (showCloudOverlay && cloudOpacity > 0.01) {
      _drawCloudLayer(canvas, size, dirX, dirY);
    }

    // 2. Draw Grid Wind Direction Vector Arrows
    if (showWindVectors) {
      _drawWindVectorGrid(canvas, size, dirX, dirY);
    }

    // 3. Draw Animated Flowing Wind Particles
    if (showWindParticles && particles.isNotEmpty) {
      _drawWindParticles(canvas, size, dirX, dirY);
    }
  }

  void _drawCloudLayer(Canvas canvas, Size size, double dirX, double dirY) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: (cloudCoveragePercent / 100.0 * 0.28 * cloudOpacity).clamp(
          0.0,
          0.45,
        ),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    final shift = animationValue * 40.0;
    final path = Path();

    // Create organic cloud wisps
    final numClouds = (cloudCoveragePercent / 15).clamp(3, 10).toInt();
    for (int i = 0; i < numClouds; i++) {
      final cx =
          (size.width * (0.15 + (i * 0.18)) + (dirX * shift * (i + 1))) %
              (size.width + 100) -
          50;
      final cy =
          (size.height * (0.2 + ((i * 37) % 60) / 100.0) +
                  (dirY * shift * (i + 1))) %
              (size.height + 100) -
          50;
      final radius = 50.0 + (i * 12.0);

      path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    }

    canvas.drawPath(path, cloudPaint);
  }

  void _drawWindVectorGrid(Canvas canvas, Size size, double dirX, double dirY) {
    const gridSpacing = 65.0;
    final mathAngle = math.atan2(dirY, dirX);
    final arrowColor = _getWindColor(windSpeedKmh).withValues(alpha: 0.45);

    final arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrowLength = (12.0 + (windSpeedKmh * 0.25)).clamp(10.0, 24.0);

    for (double x = gridSpacing / 2; x < size.width; x += gridSpacing) {
      for (double y = gridSpacing / 2; y < size.height; y += gridSpacing) {
        final start = Offset(x, y);
        final end = Offset(x + (dirX * arrowLength), y + (dirY * arrowLength));

        canvas.drawLine(start, end, arrowPaint);

        // Arrow head
        final headAngle1 = mathAngle + math.pi - 0.4;
        final headAngle2 = mathAngle + math.pi + 0.4;
        const headLen = 5.0;

        final p1 = Offset(
          end.dx + math.cos(headAngle1) * headLen,
          end.dy + math.sin(headAngle1) * headLen,
        );
        final p2 = Offset(
          end.dx + math.cos(headAngle2) * headLen,
          end.dy + math.sin(headAngle2) * headLen,
        );

        canvas.drawLine(end, p1, arrowPaint);
        canvas.drawLine(end, p2, arrowPaint);
      }
    }
  }

  void _drawWindParticles(Canvas canvas, Size size, double dirX, double dirY) {
    final speedMultiplier = (windSpeedKmh / 20.0).clamp(0.6, 3.5);
    final particleColor = _getWindColor(windSpeedKmh);

    for (var p in particles) {
      // Advance particle position
      p.x += dirX * p.speed * speedMultiplier * 1.5;
      p.y += dirY * p.speed * speedMultiplier * 1.5;
      p.life += 0.016;

      // Wrap around canvas edges
      if (p.x < -20) p.x = size.width + 10;
      if (p.x > size.width + 20) p.x = -10;
      if (p.y < -20) p.y = size.height + 10;
      if (p.y > size.height + 20) p.y = -10;

      if (p.life >= p.maxLife) {
        p.life = 0;
        p.x = math.Random().nextDouble() * size.width;
        p.y = math.Random().nextDouble() * size.height;
      }

      // Draw particle trail & head
      final fade = math.sin((p.life / p.maxLife) * math.pi);
      final alpha = (fade * 0.75).clamp(0.1, 0.9);

      final trailPaint = Paint()
        ..color = particleColor.withValues(alpha: alpha * 0.6)
        ..strokeWidth = p.size
        ..strokeCap = StrokeCap.round;

      final tailLength = 12.0 * speedMultiplier;
      final tail = Offset(p.x - (dirX * tailLength), p.y - (dirY * tailLength));
      final head = Offset(p.x, p.y);

      canvas.drawLine(tail, head, trailPaint);

      final headPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(head, p.size * 0.7, headPaint);
    }
  }

  Color _getWindColor(double speedKmh) {
    if (speedKmh < 15.0) return Colors.cyanAccent;
    if (speedKmh < 30.0) return const Color(0xFF10B981); // Emerald
    if (speedKmh < 50.0) return Colors.amberAccent;
    if (speedKmh < 75.0) return Colors.orangeAccent;
    return const Color(0xFFFF2E4C); // Storm Red
  }

  @override
  bool shouldRepaint(covariant AnimatedWindVectorPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.windSpeedKmh != windSpeedKmh ||
        oldDelegate.windBearingDegrees != windBearingDegrees ||
        oldDelegate.cloudCoveragePercent != cloudCoveragePercent ||
        oldDelegate.cloudOpacity != cloudOpacity ||
        oldDelegate.showWindParticles != showWindParticles ||
        oldDelegate.showWindVectors != showWindVectors ||
        oldDelegate.showCloudOverlay != showCloudOverlay;
  }
}
