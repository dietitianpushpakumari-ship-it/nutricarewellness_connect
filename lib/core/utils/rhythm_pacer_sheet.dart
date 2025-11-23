import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';
class RhythmPacerSheet extends StatefulWidget {
  const RhythmPacerSheet({super.key});

  @override
  State<RhythmPacerSheet> createState() => _RhythmPacerSheetState();
}

class _RhythmPacerSheetState extends State<RhythmPacerSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _audio = WellnessAudioService();

  final Map<String, int> _modes = {
    "Jumping Jacks": 700,
    "Squats": 2500,
    "Lunges": 3000,
    "High Knees": 500,
  };

  String _currentMode = "Squats";
  bool _isRunning = false;

  // 🎯 NEW: Track reps to switch legs
  int _repCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2500)
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 🎯 Bottom of Movement (Squat/Lunge Down)
        if (_isRunning) {
          _audio.hapticHeavy();
          _audio.playTick();
          _controller.reverse();
        }
      } else if (status == AnimationStatus.dismissed) {
        // 🎯 Top of Movement (Stand Up)
        if (_isRunning) {
          _audio.hapticLight();

          // 🎯 NEW: Increment Rep Count to switch legs
          setState(() {
            _repCount++;
          });

          _controller.forward();
        }
      }
    });
  }

  void _toggle() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) _controller.forward();
      else _controller.stop();
    });
  }

  void _changeMode(String mode) {
    setState(() {
      _currentMode = mode;
      _isRunning = false;
      _repCount = 0; // Reset reps on mode change
      _controller.stop();
      _controller.reset();
      _controller.duration = Duration(milliseconds: _modes[mode]!);
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
        gradient: LinearGradient(
          colors: [Color(0xFF212121), Color(0xFF000000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 30),

          const Text("Cardio Beat", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Sync your movement to the pacer", style: TextStyle(color: Colors.white54)),

          const SizedBox(height: 30),

          // Mode Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _modes.keys.map((m) {
                final isSelected = _currentMode == m;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: ChoiceChip(
                    label: Text(m),
                    selected: isSelected,
                    onSelected: (val) => _changeMode(m),
                    selectedColor: Colors.redAccent,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                  ),
                );
              }).toList(),
            ),
          ),

          // 🎯 The Visualizer Area
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _HumanPacerPainter(
                    progress: _controller.value,
                    mode: _currentMode,
                    repCount: _repCount, // 🎯 Pass rep count
                  ),
                  child: Container(),
                );
              },
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _toggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.white10 : Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(_isRunning ? "PAUSE" : "START PACER", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🎯 UPDATED PAINTER: Handles Leg Switching
class _HumanPacerPainter extends CustomPainter {
  final double progress;
  final String mode;
  final int repCount; // 🎯 New parameter

  _HumanPacerPainter({required this.progress, required this.mode, required this.repCount});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;

    // Paints
    final bodyPaint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill..strokeCap = StrokeCap.round..strokeWidth = 8;
    final headPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final limbPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;

    // --- ANIMATION VARIABLES ---
    double offsetY = 0.0;
    double scaleY = 1.0;
    double legSpread = 0.0;
    double kneeBend = 0.0;

    bool isLunge = mode == "Lunges";
    double backKneeDrop = 0.0;

    // 1. CALCULATE POSITIONS
    if (mode.contains("Jumping") || mode.contains("High")) {
      offsetY = -(progress * 40); // Jump Up
      legSpread = progress * 30;
    }
    else if (isLunge) {
      offsetY = progress * 50;       // Drop down
      scaleY = 1.0;
      backKneeDrop = progress * 40;  // Back knee drops
    }
    else {
      // Squat
      offsetY = progress * 60;
      scaleY = 1.0 - (progress * 0.3);
      legSpread = progress * 10;
      kneeBend = progress * 35;
    }

    // --- DRAWING ---

    // 1. HEAD
    canvas.drawCircle(Offset(cx, cy - 110 + offsetY), 20, headPaint);

    // 2. TORSO
    final bodyRect = Rect.fromCenter(
        center: Offset(cx, cy - 40 + offsetY),
        width: 50,
        height: 90 * scaleY
    );
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(15)), bodyPaint);

    // 3. ARMS
    double armLift = (isLunge || mode == "Squats") ? (progress * 40) : (progress * 80);

    canvas.drawLine(Offset(cx - 25, cy - 70 + offsetY), Offset(cx - 50, cy + 10 + offsetY - armLift), limbPaint);
    canvas.drawLine(Offset(cx + 25, cy - 70 + offsetY), Offset(cx + 50, cy + 10 + offsetY - armLift), limbPaint);


    // 4. LEGS (ALTERNATING LOGIC)

    if (isLunge) {
      // 🎯 SWITCH LEGS BASED ON REP COUNT
      bool leftLegForward = repCount % 2 == 0; // Even reps = Left, Odd = Right

      // Define coords for Forward Leg vs Back Leg
      // Forward Leg: 90 degree bend, foot planted
      // Back Leg: Knee drops deep, foot on toes (higher Y visually)

      void drawForwardLeg(bool isLeft) {
        double dir = isLeft ? -1.0 : 1.0;
        canvas.drawLine(Offset(cx + (15 * dir), cy + 5 + offsetY), Offset(cx + (25 * dir), cy + 60 + offsetY), limbPaint); // Thigh
        canvas.drawLine(Offset(cx + (25 * dir), cy + 60 + offsetY), Offset(cx + (25 * dir), cy + 120), limbPaint); // Shin
      }

      void drawBackLeg(bool isLeft) {
        double dir = isLeft ? -1.0 : 1.0;
        canvas.drawLine(Offset(cx + (15 * dir), cy + 5 + offsetY), Offset(cx + (35 * dir), cy + 60 + offsetY + backKneeDrop), limbPaint); // Thigh
        canvas.drawLine(Offset(cx + (35 * dir), cy + 60 + offsetY + backKneeDrop), Offset(cx + (55 * dir), cy + 110), limbPaint); // Shin
      }

      // Draw
      if (leftLegForward) {
        drawForwardLeg(true);  // Left Forward
        drawBackLeg(false);    // Right Back
      } else {
        drawBackLeg(true);     // Left Back
        drawForwardLeg(false); // Right Forward
      }

    } else {
      // --- SYMMETRICAL (Squat/Jump) ---
      // Left Leg
      canvas.drawLine(Offset(cx - 15, cy + 5 + offsetY), Offset(cx - 20 - legSpread - kneeBend, cy + 60 + offsetY), limbPaint);
      canvas.drawLine(Offset(cx - 20 - legSpread - kneeBend, cy + 60 + offsetY), Offset(cx - 20 - legSpread, cy + 120), limbPaint);

      // Right Leg
      canvas.drawLine(Offset(cx + 15, cy + 5 + offsetY), Offset(cx + 20 + legSpread + kneeBend, cy + 60 + offsetY), limbPaint);
      canvas.drawLine(Offset(cx + 20 + legSpread + kneeBend, cy + 60 + offsetY), Offset(cx + 20 + legSpread, cy + 120), limbPaint);
    }

    // 5. FLOOR
    final floorY = cy + 122;
    canvas.drawLine(Offset(cx - 100, floorY), Offset(cx + 100, floorY), Paint()..color = Colors.white24..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _HumanPacerPainter old) => true;
}