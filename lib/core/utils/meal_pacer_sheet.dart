import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class MealPacerSheet extends StatefulWidget {
  const MealPacerSheet({super.key});

  @override
  State<MealPacerSheet> createState() => _MealPacerSheetState();
}

class _MealPacerSheetState extends State<MealPacerSheet> with SingleTickerProviderStateMixin {
  String _phase = "Ready";
  Timer? _timer;
  int _chewSeconds = 20;
  int _currentCount = 0;
  final _audio = WellnessAudioService();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  void _startCycle() {
    _runPhase("Take a Bite", 2, () {
      _runPhase("Chew Slowly", _chewSeconds, () {
        _runPhase("Swallow", 3, () {
          _startCycle();
        });
      }, isChewing: true);
    });
  }

  void _runPhase(String phase, int duration, VoidCallback onComplete, {bool isChewing = false}) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _currentCount = duration;
    });

    if (isChewing) _audio.playDing();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _currentCount--);

      if (isChewing && _currentCount % 2 == 0) _audio.hapticLight();

      if (_currentCount <= 0) {
        t.cancel();
        onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Text("Mindful Eating", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(_phase, style: const TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),

          Expanded(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _FacePainter(
                    phase: _phase,
                    animValue: _animController.value,
                  ),
                  child: Container(),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          if (_phase == "Ready")
            ElevatedButton.icon(
              onPressed: _startCycle,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Meal"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            )
          else
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Stop Eating")),
        ],
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final String phase;
  final double animValue;

  _FacePainter({required this.phase, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = Colors.orange.shade100..style = PaintingStyle.fill;

    // 1. Head Outline (Profile)
    final path = Path();
    path.moveTo(cx, cy - 80); // Forehead
    path.quadraticBezierTo(cx + 50, cy - 80, cx + 50, cy - 30); // Nose bridge
    path.lineTo(cx + 70, cy - 10); // Nose tip
    path.lineTo(cx + 50, cy + 10); // Upper lip

    // 2. Jaw Logic
    double jawOffset = 0;
    if (phase == "Take a Bite") jawOffset = 15; // Mouth Open
    if (phase == "Chew Slowly") jawOffset = 5 + (animValue * 10); // Moving

    path.moveTo(cx + 50, cy + 10); // Reset at mouth
    path.lineTo(cx + 40, cy + 10 + jawOffset); // Lower lip
    path.quadraticBezierTo(cx, cy + 60 + jawOffset, cx - 20, cy + 40); // Chin/Jawline
    path.lineTo(cx - 20, cy - 40); // Ear area

    canvas.drawPath(path, paint);

    // 3. Food / Swallow Animation
    if (phase == "Swallow") {
      final double throatY = cy + 40 + (animValue * 60); // Moving down
      canvas.drawCircle(Offset(cx + 10, throatY), 8, Paint()..color = Colors.green);
    } else if (phase != "Ready") {
      // Food in mouth
      canvas.drawCircle(Offset(cx + 30, cy + 15 + (jawOffset/2)), 6, Paint()..color = Colors.green);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => true;
}