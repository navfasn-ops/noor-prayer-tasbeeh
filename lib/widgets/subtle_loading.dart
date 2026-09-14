import 'dart:math' as math;

import 'package:flutter/material.dart';

class SubtleLoading extends StatelessWidget {
  final double progress;

  const SubtleLoading({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(
        painter: _GoldLoadingPainter(
          progress: progress,
        ),
      ),
    );
  }
}

class _GoldLoadingPainter extends CustomPainter {
  final double progress;

  const _GoldLoadingPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - 4;

    final glowPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        4,
      );

    final arcPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    const arcLength = math.pi * 0.72;
    final startAngle =
        (-math.pi / 2) + (progress * math.pi * 2);

    canvas.drawArc(
      rect,
      startAngle,
      arcLength,
      false,
      glowPaint,
    );

    canvas.drawArc(
      rect,
      startAngle,
      arcLength,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
