import 'dart:math';
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
  final _audio = WellnessAudioService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _audio.playTick(); // Soft tick at cycle end
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A), // Dark Slate Blue (Eye Comfort)
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 30),
      
            const Text("Eye Yoga", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Keep your head still. Follow the dot with your eyes.", style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
            const SizedBox(height: 30),
      
            // Mode Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ["Infinity", "Box", "Focus"].map((m) {
                final isSel = _mode == m;
                return GestureDetector(
                  onTap: () => setState(() => _mode = m),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSel ? Colors.teal : Colors.white24),
                    ),
                    child: Text(m, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
      
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _EyeGuidePainter(progress: _controller.value, mode: _mode),
                    child: Container(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeGuidePainter extends CustomPainter {
  final double progress;
  final String mode;
  _EyeGuidePainter({required this.progress, required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pathPaint = Paint()..color = Colors.teal.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 2;
    final dotPaint = Paint()..color = Colors.tealAccent..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final corePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

    Offset dotPos = center;

    if (mode == "Infinity") {
      final t = progress * 2 * pi;
      final x = 150 * cos(t) / (1 + sin(t) * sin(t));
      final y = 150 * sin(t) * cos(t) / (1 + sin(t) * sin(t));
      dotPos = center + Offset(x, y);

      // Draw Path (Figure 8)
      // (Path drawing logic omitted for brevity, dot movement creates the visual)
    } else if (mode == "Box") {
      final side = progress * 4;
      double dx = 0, dy = 0;
      if (side < 1) { dx = -100 + (200 * side); dy = -100; } // Top
      else if (side < 2) { dx = 100; dy = -100 + (200 * (side - 1)); } // Right
      else if (side < 3) { dx = 100 - (200 * (side - 2)); dy = 100; } // Bottom
      else { dx = -100; dy = 100 - (200 * (side - 3)); } // Left
      dotPos = center + Offset(dx, dy);

      canvas.drawRect(Rect.fromCenter(center: center, width: 200, height: 200), pathPaint);
    } else {
      // Focus (Zoom In/Out)
      // Dot stays center, just grows/shrinks logic handled by caller if needed,
      // here we move it Near/Far in Z-space representation
      double y = sin(progress * 2 * pi) * 150;
      dotPos = center + Offset(0, y);
      canvas.drawLine(Offset(center.dx, center.dy - 150), Offset(center.dx, center.dy + 150), pathPaint);
    }

    // Glow & Dot
    canvas.drawCircle(dotPos, 15, dotPaint);
    canvas.drawCircle(dotPos, 6, corePaint);
  }
  @override
  bool shouldRepaint(covariant _EyeGuidePainter old) => true;
}