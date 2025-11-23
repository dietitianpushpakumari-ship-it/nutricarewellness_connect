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
  String _mode = "Infinity"; // Box, Pulse


  @override
  void initState() {
    super.initState();
    final _audio = WellnessAudioService();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        // 🎯 Play sound on loop complete
        _audio.playClick();
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A2138), // Dark Mode for Eye Comfort
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Eye Yoga", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Follow the dot without moving your head", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),

          // Mode Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ["Infinity", "Box", "Focus"].map((m) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ChoiceChip(
                  label: Text(m),
                  selected: _mode == m,
                  onSelected: (val) => setState(() => _mode = m),
                  selectedColor: Colors.teal,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(color: _mode == m ? Colors.white : Colors.grey),
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

          // Close Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: const CircleBorder(), padding: const EdgeInsets.all(20)),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          )
        ],
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
    final paint = Paint()..color = Colors.teal.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 2;
    final dotPaint = Paint()..color = Colors.teal..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    Offset dotPos = center;

    if (mode == "Infinity") {
      // Figure 8
      final t = progress * 2 * pi;
      final x = 150 * cos(t) / (1 + sin(t) * sin(t));
      final y = 150 * sin(t) * cos(t) / (1 + sin(t) * sin(t));
      dotPos = center + Offset(x, y);
      // Draw Path Trail (Optional)
    } else if (mode == "Box") {
      // Rectangular movement
      final side = progress * 4;
      if (side < 1) dotPos = center + Offset(-100 + (200 * side), -100); // Top
      else if (side < 2) dotPos = center + Offset(100, -100 + (200 * (side - 1))); // Right
      else if (side < 3) dotPos = center + Offset(100 - (200 * (side - 2)), 100); // Bottom
      else dotPos = center + Offset(-100, 100 - (200 * (side - 3))); // Left

      canvas.drawRect(Rect.fromCenter(center: center, width: 200, height: 200), paint);
    } else {
      // Pulse (Near/Far)
      final scale = 0.5 + 0.5 * sin(progress * 2 * pi);
      canvas.drawCircle(center, 20 * scale, dotPaint..color = Colors.teal.withOpacity(0.8));
      return;
    }

    canvas.drawCircle(dotPos, 15, dotPaint);
  }
  @override
  bool shouldRepaint(covariant _EyeGuidePainter old) => true;
}