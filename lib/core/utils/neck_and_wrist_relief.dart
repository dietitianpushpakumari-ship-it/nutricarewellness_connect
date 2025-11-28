import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class NeckWristSheet extends StatefulWidget {
  final bool isNeck;
  const NeckWristSheet({super.key, required this.isNeck});

  @override
  State<NeckWristSheet> createState() => _NeckWristSheetState();
}

class _NeckWristSheetState extends State<NeckWristSheet> with SingleTickerProviderStateMixin {
  int _seconds = 30;
  Timer? _timer;
  bool _isRunning = false;
  late AnimationController _animController;
  final _audio = WellnessAudioService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  void _toggle() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_seconds > 0) setState(() => _seconds--);
        else {
          t.cancel();
          _audio.playSuccess();
          setState(() => _isRunning = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return  SafeArea(
      child: Container(
        height: 500,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ), child: Column(
          children: [
            Text(widget.isNeck ? "Neck Release" : "Wrist Relief", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
      
            // 🎯 VISUAL TRAINER
            SizedBox(
              height: 200,
              width: 200,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _StretchPainter(isNeck: widget.isNeck, progress: _animController.value),
                  );
                },
              ),
            ),
      
            const Spacer(),
            Text("$_seconds", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _toggle, child: Text(_isRunning ? "Pause" : "Start Timer"))
          ],
        ),
      ),
    );
  }
}

class _StretchPainter extends CustomPainter {
  final bool isNeck;
  final double progress; // 0.0 to 1.0

  _StretchPainter({required this.isNeck, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..color = Colors.teal..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    final headPaint = Paint()..color = Colors.teal..style = PaintingStyle.fill;

    if (isNeck) {
      // Body (Shoulders)
      canvas.drawLine(Offset(cx - 40, cy + 50), Offset(cx + 40, cy + 50), paint);
      canvas.drawLine(Offset(cx, cy + 50), Offset(cx, cy + 100), paint);

      // Head Tilting (-30 to +30 degrees approx)
      final angle = (progress - 0.5) * 1.0; // Tilt factor
      final headX = cx + (sin(angle) * 40);
      final headY = (cy - 20) - (cos(angle) * 10);

      canvas.drawCircle(Offset(headX, headY), 25, headPaint);
      // Neck Line
      canvas.drawLine(Offset(cx, cy + 50), Offset(headX, headY + 10), paint..strokeWidth=4);

    } else {
      // WRIST
      // Forearm
      canvas.drawLine(Offset(cx - 60, cy), Offset(cx, cy), paint); // Horizontal Arm

      // Hand Bending Up/Down
      final angle = (progress - 0.5) * 2.0; // -1 to 1
      final handX = cx + (30 * cos(angle));
      final handY = cy + (30 * sin(angle));

      // Palm
      canvas.drawLine(Offset(cx, cy), Offset(handX + 10, handY), paint..strokeWidth=8);

      // Fingers
      canvas.drawLine(Offset(handX + 10, handY), Offset(handX + 30, handY - (10 * angle)), paint..strokeWidth=4);
    }
  }
  @override
  bool shouldRepaint(covariant _StretchPainter old) => true;
}