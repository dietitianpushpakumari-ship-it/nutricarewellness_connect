import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class Co2ToleranceSheet extends StatefulWidget {
  const Co2ToleranceSheet({super.key});

  @override
  State<Co2ToleranceSheet> createState() => _Co2ToleranceSheetState();
}

class _Co2ToleranceSheetState extends State<Co2ToleranceSheet> with SingleTickerProviderStateMixin {
  bool _isRunning = false;
  int _milliseconds = 0;
  Timer? _timer;
  String _result = "";
  final _audio = WellnessAudioService();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Idle breathing animation
    _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3)
    )..repeat(reverse: true);
  }

  void _startTest() {
    setState(() {
      _isRunning = true;
      _milliseconds = 0;
      _result = "";
    });

    _audio.hapticMedium();
    _pulseController.stop(); // Stop idle breathing
    _pulseController.value = 1.0; // Start full

    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() => _milliseconds += 100);

      // Haptic heartbeat every second to keep user focused
      if (_milliseconds % 1000 == 0) _audio.hapticLight();
    });
  }

  void _stopTest() {
    _timer?.cancel();
    _audio.playSuccess();
    _audio.hapticSuccess();

    setState(() {
      _isRunning = false;
      double sec = _milliseconds / 1000;

      if (sec < 20) _result = "Low Tolerance (High Stress)";
      else if (sec < 40) _result = "Moderate Tolerance";
      else _result = "Elite / Relaxed Nervous System";

      _pulseController.repeat(reverse: true); // Resume idle
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double sec = _milliseconds / 1000;

    return Container(
      height: 500,
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text("CO2 Stress Test", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (!_isRunning && _result.isEmpty)
            const Text(
              "Inhale deeply, then EXHALE as slowly as possible.\nHold the button while exhaling.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

          const Spacer(),

          // 🎯 2D LUNG ANIMATION
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              // Logic: If running, calculate depletion based on time (up to 60s cap for visual)
              // If idle, use sine wave.
              double progress = _isRunning
                  ? (1.0 - (sec / 60.0)).clamp(0.0, 1.0)
                  : _pulseController.value;

              return CustomPaint(
                size: const Size(200, 200),
                painter: _LungsPainter(
                  progress: progress,
                  isTesting: _isRunning,
                  elapsed: sec,
                ),
              );
            },
          ),

          const Spacer(),

          // Result Display
          if (_result.isNotEmpty) ...[
            Text(
              "${sec.toStringAsFixed(1)} s",
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_result, style: TextStyle(fontSize: 16, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],

          // Control Button
          GestureDetector(
            onLongPressStart: (_) => _startTest(),
            onLongPressEnd: (_) => _stopTest(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isRunning ? Colors.redAccent : Colors.blueAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_isRunning ? Colors.red : Colors.blue).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Text(
                _isRunning ? "EXHALING..." : "HOLD TO TEST",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🎯 CUSTOM 2D PAINTER: LUNGS
class _LungsPainter extends CustomPainter {
  final double progress; // 0.0 (Empty) to 1.0 (Full)
  final bool isTesting;
  final double elapsed;

  _LungsPainter({required this.progress, required this.isTesting, required this.elapsed});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.8;
    final h = size.height * 0.8;

    // Dynamic Color based on Stress Level (Time)
    Color lungColor = Colors.lightBlueAccent;
    if (isTesting) {
      if (elapsed < 20) lungColor = Colors.blue;       // Good
      else if (elapsed < 40) lungColor = Colors.purple; // Strain
      else lungColor = Colors.red;                     // Max Effort
    }

    final paintFill = Paint()..color = lungColor.withOpacity(0.3)..style = PaintingStyle.fill;
    final paintBorder = Paint()..color = lungColor..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;

    // Inner "Air" Paint (Fills up based on progress)
    final paintAir = Paint()..color = lungColor..style = PaintingStyle.fill;

    // Scale visual breath (simulating volume)
    // 0.8 is base size, progress adds up to 0.2 extra scale
    double scale = 0.8 + (progress * 0.2);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);
    canvas.translate(-cx, -cy);

    // Draw Left Lung
    final leftLung = Path();
    leftLung.moveTo(cx - 10, cy - 40); // Trachea start
    leftLung.quadraticBezierTo(cx - 30, cy - 60, cx - 60, cy - 20); // Top curve
    leftLung.quadraticBezierTo(cx - 90, cy + 20, cx - 60, cy + 80); // Outer edge
    leftLung.quadraticBezierTo(cx - 30, cy + 90, cx - 10, cy + 60); // Bottom curve
    leftLung.close();

    // Draw Right Lung (Mirror)
    final rightLung = Path();
    rightLung.moveTo(cx + 10, cy - 40);
    rightLung.quadraticBezierTo(cx + 30, cy - 60, cx + 60, cy - 20);
    rightLung.quadraticBezierTo(cx + 90, cy + 20, cx + 60, cy + 80);
    rightLung.quadraticBezierTo(cx + 30, cy + 90, cx + 10, cy + 60);
    rightLung.close();

    // Draw Background (Empty Lung Shell)
    canvas.drawPath(leftLung, paintFill);
    canvas.drawPath(rightLung, paintFill);
    canvas.drawPath(leftLung, paintBorder);
    canvas.drawPath(rightLung, paintBorder);

    // 🎯 Draw "Air" Level (Clipping)
    // If testing, the air depletes. If idle, it pulses.

    // We use a rect to clip the "Full" paint to show depletion
    // Height grows from bottom up
    double fillHeight = h * progress;
    Rect fillRect = Rect.fromLTRB(0, size.height - fillHeight, size.width, size.height);

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawPath(leftLung, paintAir);
    canvas.drawPath(rightLung, paintAir);
    // Mask with rect (Simulate liquid/air level)
    // Actually for breathing, scaling looks better than filling like water.
    // Since we already scaled the whole canvas above, the "Fill" paint just makes it solid.
    canvas.restore();

    // Trachea (Windpipe)
    canvas.drawLine(Offset(cx, cy - 40), Offset(cx, cy - 80), paintBorder);
    canvas.drawLine(Offset(cx - 10, cy - 40), Offset(cx, cy - 40), paintBorder);
    canvas.drawLine(Offset(cx + 10, cy - 40), Offset(cx, cy - 40), paintBorder);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LungsPainter old) => true;
}