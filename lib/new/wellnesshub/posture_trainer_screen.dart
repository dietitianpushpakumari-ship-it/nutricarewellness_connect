import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

class PostureTrainerSheet extends StatefulWidget {
  const PostureTrainerSheet({super.key});

  @override
  State<PostureTrainerSheet> createState() => _PostureTrainerSheetState();
}

class _PostureTrainerSheetState extends State<PostureTrainerSheet> {
  StreamSubscription? _subscription;
  final _audio = WellnessAudioService();
  Timer? _hapticTimer;

  // 🎯 ValueNotifiers for buttery smooth 120fps updates without rebuilding the whole UI
  final ValueNotifier<double> _tiltStrain = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isBadPosture = ValueNotifier<bool>(false);

  // 🎯 Calibration Baseline
  double _targetZ = 2.0; // Assume 2.0 is a good starting point (holding phone up)

  @override
  void initState() {
    super.initState();
    _startSensor();
  }

  void _startSensor() {
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Z-axis measures screen tilt.
      // 0 = perfectly vertical (great). 9.8 = flat on table (terrible text-neck).
      double currentZ = event.z;

      // Calculate strain percentage based on how far Z is from the target baseline
      // A difference of 5.0 from the baseline is considered 100% strain.
      double rawStrain = (currentZ - _targetZ) / 5.0;
      double clampedStrain = rawStrain.clamp(0.0, 1.0);

      _tiltStrain.value = clampedStrain;

      bool bad = clampedStrain > 0.85; // Trigger alarm at 85% strain

      if (bad != _isBadPosture.value) {
        _isBadPosture.value = bad;
        _manageHapticLoop(bad);
      }
    });
  }

  void _calibrate() {
    // Captures the current Z value and sets it as the "Perfect" baseline
    _audio.playSuccess();
    _audio.hapticSuccess();

    // Briefly listen to get exactly one frame of data for calibration
    StreamSubscription? tempSub;
    tempSub = accelerometerEvents.listen((event) {
      setState(() {
        _targetZ = event.z;
        // Ensure baseline isn't completely flat (prevent cheating)
        if (_targetZ > 6.0) _targetZ = 6.0;
      });
      tempSub?.cancel();
    });
  }

  void _manageHapticLoop(bool isBad) {
    _hapticTimer?.cancel();
    if (isBad) {
      _audio.hapticHeavy();
      _hapticTimer = Timer.periodic(const Duration(seconds: 2), (t) {
        if (mounted && _isBadPosture.value) _audio.hapticMedium();
      });
    } else {
      _audio.playDing();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hapticTimer?.cancel();
    _tiltStrain.dispose();
    _isBadPosture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90, // 🎯 Slightly taller to give breathing room
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // 🎯 FIXED HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("POSTURE TRAINER", style: TextStyle(fontSize: 14, color: theme.hintColor, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // 🎯 DYNAMIC SCROLLABLE MIDDLE SECTION
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Dynamically scale the gauge based on available vertical space
                  final double gaugeSize = (constraints.maxHeight * 0.45).clamp(180.0, 280.0);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 🎯 Replaces Spacer()
                        children: [
                          const SizedBox(height: 16),

                          // 🎯 DYNAMIC STATUS TEXT
                          ValueListenableBuilder<bool>(
                            valueListenable: _isBadPosture,
                            builder: (context, isBad, child) {
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  isBad ? "HEAD UP!" : "Perfect Alignment",
                                  key: ValueKey(isBad),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: isBad ? Colors.redAccent : colorScheme.primary,
                                    letterSpacing: isBad ? 2.0 : 0.0,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text("Keep the phone elevated to protect your neck.", style: TextStyle(color: theme.hintColor, fontSize: 14)),

                          const SizedBox(height: 24),

                          // 🎯 LIVE ANIMATION & GAUGE (Dynamically Sized)
                          SizedBox(
                            height: gaugeSize,
                            width: gaugeSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ValueListenableBuilder<double>(
                                  valueListenable: _tiltStrain,
                                  builder: (context, strain, child) {
                                    return SizedBox(
                                      height: gaugeSize,
                                      width: gaugeSize,
                                      child: CircularProgressIndicator(
                                        value: strain,
                                        strokeWidth: 12,
                                        backgroundColor: theme.dividerColor.withOpacity(0.1),
                                        valueColor: AlwaysStoppedAnimation(
                                            Color.lerp(Colors.green, Colors.red, strain) ?? Colors.green
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                ValueListenableBuilder<double>(
                                  valueListenable: _tiltStrain,
                                  builder: (context, strain, child) {
                                    return CustomPaint(
                                      size: Size(gaugeSize * 0.7, gaugeSize * 0.7), // Scale painter with gauge
                                      painter: _DynamicPosturePainter(
                                          strainProgress: strain,
                                          themeColor: colorScheme.onSurface
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 🎯 CALIBRATION INFO
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: theme.hintColor, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Hold your phone at eye level in a comfortable position, then tap Calibrate.",
                                      style: TextStyle(color: theme.hintColor, fontSize: 12, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 🎯 FIXED BOTTOM BUTTON
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _calibrate,
                  style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  label: const Text("Set Target Posture", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
// 🎯 DYNAMIC POSTURE PAINTER
// Smoothly bends the stick figure based on the exact tilt of the phone
// =======================================================================
class _DynamicPosturePainter extends CustomPainter {
  final double strainProgress; // 0.0 (Perfect) to 1.0 (Terrible)
  final Color themeColor;

  _DynamicPosturePainter({required this.strainProgress, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Color interpolates from Gray to Red as posture worsens
    final drawColor = Color.lerp(themeColor.withOpacity(0.5), Colors.redAccent, strainProgress) ?? themeColor;
    final paint = Paint()..color = drawColor..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;

    // Spine Base (Hips)
    final base = Offset(cx - 20, cy + 70);

    // Dynamic Head Position based on strain
    double headX = cx + (strainProgress * 60); // Moves forward
    double headY = cy - 60 + (strainProgress * 40); // Drops down
    double spineCurve = strainProgress * 50; // Spine bows out

    // Draw Spine (Quadratic Bezier for natural slump)
    final path = Path();
    path.moveTo(base.dx, base.dy);
    path.quadraticBezierTo(cx + spineCurve, cy, headX, headY + 20);
    canvas.drawPath(path, paint);

    // Head
    canvas.drawCircle(Offset(headX, headY), 18, Paint()..color = drawColor);

    // Arm & Phone
    final phonePaint = Paint()..color = themeColor.withOpacity(0.3)..style = PaintingStyle.fill;

    // Arm moving down with the head
    final armElbow = Offset(cx + 10 + (strainProgress * 30), cy + 10 + (strainProgress * 20));
    final hands = Offset(headX + 25, headY + 50);

    // Draw Arm
    canvas.drawLine(Offset(headX, headY + 25), armElbow, paint..strokeWidth = 5); // Shoulder to elbow
    canvas.drawLine(armElbow, hands, paint..strokeWidth = 5); // Elbow to hands

    // Draw Phone
    canvas.save();
    canvas.translate(hands.dx + 5, hands.dy - 5);
    // Rotate phone based on strain
    canvas.rotate(strainProgress * math.pi / 4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -15, 20, 30), const Radius.circular(4)), phonePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DynamicPosturePainter old) {
    return old.strainProgress != strainProgress || old.themeColor != themeColor;
  }
}