// lib/features/dietplan/PRESENTATION/widgets/animated_step_meter.dart
import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedStepMeter extends StatefulWidget {
  final int currentSteps;
  final int goalSteps;
  final Animation<double> continuousAnimation;

  const AnimatedStepMeter({
    super.key,
    required this.currentSteps,
    required this.goalSteps,
    required this.continuousAnimation,
  });

  @override
  State<AnimatedStepMeter> createState() => _AnimatedStepMeterState();
}

class _AnimatedStepMeterState extends State<AnimatedStepMeter> {
  @override
  Widget build(BuildContext context) {
    final double progress = (widget.goalSteps == 0 ? 0 : widget.currentSteps / widget.goalSteps).clamp(0.0, 1.0).toDouble();

    return AspectRatio(
      aspectRatio: 2.0, // 🎯 Made it wider (less tall)
      child: AnimatedBuilder(
        animation: widget.continuousAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _StepMeterPainter(
              progress: progress,
              animationValue: widget.continuousAnimation.value,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.currentSteps.toString(),
                    style: TextStyle(
                        fontSize: 32, // 🎯 Reduced font size
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        shadows: [
                          Shadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: Offset(1,1))
                        ]
                    ),
                  ),
                  Text(
                    'Goal: ${widget.goalSteps} Steps',
                    style: const TextStyle(
                        fontSize: 12, // 🎯 Reduced font size
                        color: Colors.black54,
                        fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Custom Painter for the Meter ---
class _StepMeterPainter extends CustomPainter {
  final double progress;
  final double animationValue;

  _StepMeterPainter({required this.progress, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    final Paint progressPaint = Paint()..style = PaintingStyle.fill;

    final Paint milestonePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final RRect fullRRect = RRect.fromRectAndRadius(rect, const Radius.circular(15)); // 🎯 Softer curve

    // 1. Draw the background
    canvas.clipRRect(fullRRect);
    canvas.drawRRect(fullRRect, backgroundPaint);

    // 2. Define the multi-color gradient for levels
    final List<Color> colors = [
      Colors.orange.shade300,
      Colors.amber.shade500,
      Colors.green.shade400,
      Colors.green.shade700,
    ];
    final List<double> stops = [0.0, 0.4, 0.8, 1.0];

    progressPaint.shader = LinearGradient(
      colors: colors,
      stops: stops,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(rect);

    // 3. Draw the animated progress
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
      progressPaint,
    );

    // 4. Draw Milestones (25%, 50%, 75%)
    for (int i = 1; i <= 3; i++) {
      final double milestoneX = size.width * (i * 0.25);
      canvas.drawLine(
        Offset(milestoneX, 0),
        Offset(milestoneX, size.height),
        milestonePaint,
      );
    }

    // 5. Draw continuous "shimmer" animation
    final double shimmerPos = size.width * animationValue;
    final Paint shimmerPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(shimmerPos, size.height / 2), radius: 30));

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
      progressPaint,
    );
    canvas.drawRect(rect, shimmerPaint..blendMode = BlendMode.srcATop);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StepMeterPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.animationValue != animationValue;
  }
}