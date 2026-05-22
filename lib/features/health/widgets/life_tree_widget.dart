import 'package:flutter/material.dart';
import 'dart:math' as math;

class LifeTreeWidget extends StatelessWidget {
  final double growthProgress; // 0.0 to 1.0
  final String message;

  const LifeTreeWidget({
    super.key,
    required this.growthProgress,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow Effect
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.2 * growthProgress),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(200, 200),
                painter: TreePainter(growthProgress: growthProgress),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Progress Bar
        Container(
          width: 150,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: growthProgress,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.greenAccent, Colors.tealAccent]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TreePainter extends CustomPainter {
  final double growthProgress;

  TreePainter({required this.growthProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.shade400
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height * 0.9);
    
    if (growthProgress < 0.2) {
      // Stage 1: Seed/Sprout
      _drawSprout(canvas, center, growthProgress * 5);
    } else if (growthProgress < 0.5) {
      // Stage 2: Small Tree
      _drawSmallTree(canvas, center, (growthProgress - 0.2) / 0.3);
    } else {
      // Stage 3: Full Tree
      _drawFullTree(canvas, center, (growthProgress - 0.5) / 0.5);
    }
  }

  void _drawSprout(Canvas canvas, Offset bottom, double progress) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(bottom.dx, bottom.dy);
    path.quadraticBezierTo(
      bottom.dx - 10, bottom.dy - 20 * progress,
      bottom.dx + 5, bottom.dy - 40 * progress,
    );
    canvas.drawPath(path, paint);

    if (progress > 0.5) {
      final leafPaint = Paint()..color = Colors.greenAccent..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bottom.dx + 5, bottom.dy - 40 * progress), width: 10, height: 6),
        leafPaint,
      );
    }
  }

  void _drawSmallTree(Canvas canvas, Offset bottom, double progress) {
    final trunkPaint = Paint()..color = Colors.brown.shade300..strokeWidth = 6..strokeCap = StrokeCap.round;
    final top = Offset(bottom.dx, bottom.dy - 60 * progress - 40);
    canvas.drawLine(bottom, top, trunkPaint);

    final leafPaint = Paint()..color = Colors.green..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(top.dx - 15, top.dy - 10), 20 * progress, leafPaint);
    canvas.drawCircle(Offset(top.dx + 15, top.dy - 10), 20 * progress, leafPaint);
    canvas.drawCircle(Offset(top.dx, top.dy - 25), 25 * progress, leafPaint);
  }

  void _drawFullTree(Canvas canvas, Offset bottom, double progress) {
    final trunkPaint = Paint()..color = Colors.brown.shade400..strokeWidth = 8..strokeCap = StrokeCap.round;
    final top = Offset(bottom.dx, bottom.dy - 120);
    canvas.drawLine(bottom, top, trunkPaint);

    // Main foliage
    final leafPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.green.shade700, Colors.greenAccent],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, 200, 200));

    canvas.drawCircle(Offset(top.dx - 30, top.dy), 40, leafPaint);
    canvas.drawCircle(Offset(top.dx + 30, top.dy), 40, leafPaint);
    canvas.drawCircle(Offset(top.dx, top.dy - 40), 50, leafPaint);

    // Flowers if progress > 0.8
    if (growthProgress > 0.9) {
      final flowerPaint = Paint()..color = Colors.pinkAccent..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(top.dx - 20, top.dy - 20), 4, flowerPaint);
      canvas.drawCircle(Offset(top.dx + 25, top.dy - 10), 4, flowerPaint);
      canvas.drawCircle(Offset(top.dx + 5, top.dy - 50), 5, flowerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
