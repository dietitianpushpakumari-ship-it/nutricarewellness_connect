import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class EyeYogaSheet extends StatefulWidget {
  const EyeYogaSheet({super.key});

  @override
  State<EyeYogaSheet> createState() => _EyeYogaSheetState();
}

class _EyeYogaSheetState extends State<EyeYogaSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _mode = "Infinity";
  bool _isPlaying = true;
  final _audio = WellnessAudioService();

  // 🎯 Expanded Clinical Patterns
  final List<String> _modes = ["Infinity", "Circle", "Box", "Horizontal", "Vertical", "Diagonal", "Saccades", "Convergence"];

  int _lastSaccadeQuadrant = -1;

  @override
  void initState() {
    super.initState();
    // 🎯 10 seconds for a full smooth cycle
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    _controller.addListener(() {
      // 🎯 Audio logic for Saccades (Ticks every time the dot jumps)
      if (_mode == "Saccades" && _isPlaying) {
        int currentQuadrant = (_controller.value * 4).floor();
        if (currentQuadrant != _lastSaccadeQuadrant) {
          _audio.playTick();
          _lastSaccadeQuadrant = currentQuadrant;
        }
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (_isPlaying && _mode != "Saccades") _audio.playTick();
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) _controller.repeat();
      else _controller.stop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90, // 🎯 Pushed to 90% of screen height
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),

            // 🎯 COMPACT HEADER (Title + Controls in one row to save space)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Icon(Icons.visibility_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text("EYE YOGA", style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const Spacer(),
                  // Play/Pause Button
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: colorScheme.primary, size: 32),
                    onPressed: _togglePlay,
                  ),
                  // Close Button
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.hintColor),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),

            // 🎯 COMPACT MODE SELECTOR
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _modes.map((m) {
                  final isSel = _mode == m;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _mode = m;
                      _lastSaccadeQuadrant = -1; // Reset saccade logic
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSel ? colorScheme.primary : theme.dividerColor.withOpacity(0.2)),
                      ),
                      child: Text(
                          m,
                          style: TextStyle(
                              fontSize: 13,
                              color: isSel ? colorScheme.primary : theme.colorScheme.onSurface,
                              fontWeight: isSel ? FontWeight.w900 : FontWeight.bold
                          )
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // 🎯 MAXIMIZED ANIMATION CANVAS
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite, // 🎯 Forces the canvas to take all remaining space
                      painter: _EyeGuidePainter(
                          progress: _controller.value,
                          mode: _mode,
                          themeColor: colorScheme.primary,
                          trackColor: theme.dividerColor.withOpacity(0.15)
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// 🎯 FULL-SCREEN EYE TRACKING PAINTER
// Uses width and height dynamically to stretch animations to device size
// =======================================================================
class _EyeGuidePainter extends CustomPainter {
  final double progress;
  final String mode;
  final Color themeColor;
  final Color trackColor;

  _EyeGuidePainter({
    required this.progress,
    required this.mode,
    required this.themeColor,
    required this.trackColor
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final pathPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final dotGlowPaint = Paint()
      ..color = themeColor.withOpacity(0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final dotCorePaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.fill;

    Offset dotPos = center;
    double dotRadius = 10.0;
    final double t = progress * 2 * math.pi;

    // 🎯 Dynamically utilize the rectangular bounds of the screen
    final double maxW = size.width / 2;
    final double maxH = size.height / 2;

    if (mode == "Infinity") {
      // Scale infinity to fit a rectangle perfectly
      final path = Path();
      for (double i = 0; i <= 2 * math.pi; i += 0.05) {
        final px = maxW * math.cos(i) / (1 + math.sin(i) * math.sin(i));
        final py = maxH * math.sin(i) * math.cos(i) / (1 + math.sin(i) * math.sin(i));
        if (i == 0) path.moveTo(center.dx + px, center.dy + py);
        else path.lineTo(center.dx + px, center.dy + py);
      }
      canvas.drawPath(path, pathPaint);

      final x = maxW * math.cos(t) / (1 + math.sin(t) * math.sin(t));
      final y = maxH * math.sin(t) * math.cos(t) / (1 + math.sin(t) * math.sin(t));
      dotPos = center + Offset(x, y);
    }

    else if (mode == "Circle") {
      // Draws an oval that fits the screen shape
      canvas.drawOval(Rect.fromCenter(center: center, width: maxW * 2, height: maxH * 2), pathPaint);

      final x = maxW * math.cos(t);
      final y = maxH * math.sin(t);
      dotPos = center + Offset(x, y);
    }

    else if (mode == "Box") {
      canvas.drawRect(Rect.fromCenter(center: center, width: maxW * 2, height: maxH * 2), pathPaint);

      final side = progress * 4;
      double dx = 0, dy = 0;
      if (side < 1) { dx = -maxW + (maxW * 2 * side); dy = -maxH; } // Top
      else if (side < 2) { dx = maxW; dy = -maxH + (maxH * 2 * (side - 1)); } // Right
      else if (side < 3) { dx = maxW - (maxW * 2 * (side - 2)); dy = maxH; } // Bottom
      else { dx = -maxW; dy = maxH - (maxH * 2 * (side - 3)); } // Left

      dotPos = center + Offset(dx, dy);
    }

    else if (mode == "Vertical") {
      canvas.drawLine(Offset(center.dx, center.dy - maxH), Offset(center.dx, center.dy + maxH), pathPaint);
      final y = math.sin(t) * maxH;
      dotPos = center + Offset(0, y);
    }

    else if (mode == "Horizontal") {
      canvas.drawLine(Offset(center.dx - maxW, center.dy), Offset(center.dx + maxW, center.dy), pathPaint);
      final x = math.sin(t) * maxW;
      dotPos = center + Offset(x, 0);
    }

    else if (mode == "Diagonal") {
      canvas.drawLine(Offset(center.dx - maxW, center.dy - maxH), Offset(center.dx + maxW, center.dy + maxH), pathPaint);
      canvas.drawLine(Offset(center.dx - maxW, center.dy + maxH), Offset(center.dx + maxW, center.dy - maxH), pathPaint..color = pathPaint.color.withOpacity(0.05));

      // Goes from bottom-left to top-right
      final x = math.sin(t) * maxW;
      final y = math.sin(t) * maxH;
      dotPos = center + Offset(x, y);
    }

    else if (mode == "Saccades") {
      // Instantly jumps between the 4 corners
      canvas.drawRect(Rect.fromCenter(center: center, width: maxW * 2, height: maxH * 2), pathPaint..color = pathPaint.color.withOpacity(0.05));

      final p = progress % 1.0;
      if (p < 0.25) dotPos = center + Offset(-maxW, -maxH); // Top Left
      else if (p < 0.50) dotPos = center + Offset(maxW, -maxH); // Top Right
      else if (p < 0.75) dotPos = center + Offset(maxW, maxH); // Bottom Right
      else dotPos = center + Offset(-maxW, maxH); // Bottom Left
    }

    else if (mode == "Convergence") {
      // Pulses massive and small in the center to train eye convergence
      dotPos = center;
      final scale = (math.sin(t) + 1) / 2;
      dotRadius = 8 + (scale * (math.min(maxW, maxH) * 0.5)); // Fills up to 50% of screen width
    }

    // 🎯 Render Dot
    canvas.drawCircle(dotPos, dotRadius * 2.5, dotGlowPaint);
    canvas.drawCircle(dotPos, dotRadius, dotCorePaint);

    // 3D Reflection
    final reflectionPaint = Paint()..color = Colors.white.withOpacity(0.8)..style = PaintingStyle.fill;
    canvas.drawCircle(dotPos + Offset(-dotRadius * 0.3, -dotRadius * 0.3), dotRadius * 0.25, reflectionPaint);
  }

  @override
  bool shouldRepaint(covariant _EyeGuidePainter old) => true;
}