import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';


class KegelTrainerSheet extends StatefulWidget {
  const KegelTrainerSheet({super.key});

  @override
  State<KegelTrainerSheet> createState() => _KegelTrainerSheetState();
}

class _KegelTrainerSheetState extends State<KegelTrainerSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _status = "Relax";
  final _audio = WellnessAudioService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    _controller.addListener(() {
      final isSqueeze = _controller.value < 0.5;
      final newStatus = isSqueeze ? "SQUEEZE" : "RELAX";

      if (_status != newStatus) {
        setState(() => _status = newStatus);

        // 🎯 HAPTIC CUES
        if (isSqueeze) {
          _audio.hapticHeavy(); // Strong buzz for effort
          _audio.playClick();
        } else {
          _audio.hapticMedium(); // Double tap for relax
          Future.delayed(const Duration(milliseconds: 150), () => _audio.hapticMedium());
        }
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
      height: 500,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Kegel Trainer", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Phone will vibrate to guide you.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          CustomPaint(
            painter: _KegelPainter(squeezeValue: _controller.value), // 0 to 1
            size: Size(200, 200),
          )
        ],
      ),
    );
  }
}

// ... (Existing State logic)

// 🎯 UPDATE the AnimatedBuilder child to use this:
/*
   CustomPaint(
     painter: _KegelPainter(squeezeValue: _controller.value), // 0 to 1
     size: Size(200, 200),
   )
*/

class _KegelPainter extends CustomPainter {
  final double squeezeValue; // 0.0 (Squeeze) to 1.0 (Relax)
  _KegelPainter({required this.squeezeValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..color = Colors.blueGrey..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;

    // Draw Seated Figure (Lotus)
    // Head
    canvas.drawCircle(Offset(cx, cy - 60), 15, Paint()..color = Colors.blueGrey);
    // Torso
    canvas.drawLine(Offset(cx, cy - 45), Offset(cx, cy + 10), paint);
    // Legs (Crossed)
    canvas.drawLine(Offset(cx, cy + 10), Offset(cx - 40, cy + 40), paint);
    canvas.drawLine(Offset(cx, cy + 10), Offset(cx + 40, cy + 40), paint);
    canvas.drawLine(Offset(cx - 40, cy + 40), Offset(cx + 10, cy + 40), paint);
    canvas.drawLine(Offset(cx + 40, cy + 40), Offset(cx - 10, cy + 40), paint);

    // 🎯 CORE ACTIVATION
    // Squeeze (val < 0.5) -> Glow Red/Orange
    // Relax (val > 0.5) -> Blue/Invisible

    double intensity = 0.0;
    Color glowColor = Colors.blue;

    if (squeezeValue < 0.5) {
      // Squeezing
      intensity = 1.0 - (squeezeValue * 2); // 0 -> 1
      glowColor = Colors.orange;
    } else {
      // Relaxing
      intensity = (squeezeValue - 0.5) * 2; // 0 -> 1
      glowColor = Colors.blue.withOpacity(0.3);
    }

    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.6 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Draw Glow at Pelvis
    canvas.drawCircle(Offset(cx, cy + 20), 10 + (10 * intensity), glowPaint);

    // Inner Core
    if (squeezeValue < 0.5) {
      canvas.drawCircle(Offset(cx, cy + 20), 5, Paint()..color = Colors.deepOrange);
    }
  }

  @override
  bool shouldRepaint(covariant _KegelPainter old) => true;
}