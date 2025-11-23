import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

class PostureTrainerSheet extends StatefulWidget {
  const PostureTrainerSheet({super.key});

  @override
  State<PostureTrainerSheet> createState() => _PostureTrainerSheetState();
}

class _PostureTrainerSheetState extends State<PostureTrainerSheet> {
  bool _isBadPosture = false;
  StreamSubscription? _subscription;
  final _audio = WellnessAudioService();
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      bool bad = event.z < 5.0;

      if (bad != _isBadPosture) {
        setState(() => _isBadPosture = bad);
        _manageHapticLoop(bad);
      }
    });
  }

  void _manageHapticLoop(bool isBad) {
    _hapticTimer?.cancel();
    if (isBad) {
      // 🎯 REPEATED WARNING VIBRATION
      _audio.hapticHeavy(); // Initial alert
      _hapticTimer = Timer.periodic(const Duration(seconds: 2), (t) {
        if (mounted && _isBadPosture) _audio.hapticMedium();
      });
    } else {
      // 🎯 SUCCESS CUE
      _audio.playDing();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hapticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _isBadPosture ? Colors.red : Colors.green;
    final text = _isBadPosture ? "HEAD UP!" : "Perfect.";
    final icon = _isBadPosture ? Icons.arrow_upward : Icons.check_circle;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: double.infinity,
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: Size(200, 200),
            painter: _PosturePainter(isBad: _isBadPosture),
          ),
          const SizedBox(height: 20),
          Text(text, style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "I will vibrate if you look down.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
            child: const Text("Close Trainer"),
          )
        ],
      ),
    );
  }
}

class _PosturePainter extends CustomPainter {
  final bool isBad;
  _PosturePainter({required this.isBad});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final color = isBad ? Colors.white : Colors.white; // Always white on colored bg
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;

    // Spine Base
    final base = Offset(cx - 20, cy + 80);

    // Head Position
    double headX = cx;
    double headY = cy - 60;
    double spineCurve = 0;

    if (isBad) {
      headX += 40; // Forward Head
      headY += 20; // Slumped
      spineCurve = 30; // Curved Spine
    }

    // Draw Spine (Quadratic Bezier for slump)
    final path = Path();
    path.moveTo(base.dx, base.dy);
    path.quadraticBezierTo(cx + spineCurve, cy, headX, headY + 20);
    canvas.drawPath(path, paint);

    // Head
    canvas.drawCircle(Offset(headX, headY), 20, Paint()..color = color);

    // Phone
    if (isBad) {
      canvas.drawRect(Rect.fromCenter(center: Offset(headX + 30, headY + 60), width: 20, height: 30), Paint()..color = Colors.white54);
      // Arms holding phone
      canvas.drawLine(Offset(headX, headY + 30), Offset(headX + 30, headY + 60), paint..strokeWidth=3);
    }
  }
  @override
  bool shouldRepaint(covariant _PosturePainter old) => true;
}