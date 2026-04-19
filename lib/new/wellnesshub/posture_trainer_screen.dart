import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class PostureTrainerSheet extends StatefulWidget {
  const PostureTrainerSheet({super.key});

  @override
  State<PostureTrainerSheet> createState() => _PostureTrainerSheetState();
}

class _PostureTrainerSheetState extends State<PostureTrainerSheet> {
  StreamSubscription? _subscription;
  final _audio = WellnessAudioService();
  Timer? _hapticTimer;

  // 🎯 ValueNotifiers for buttery smooth 120fps updates
  final ValueNotifier<double> _tiltStrain = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isBadPosture = ValueNotifier<bool>(false);

  // 🎯 Calibration Baseline
  double _targetZ = 2.0;

  @override
  void initState() {
    super.initState();
    _startSensor();
  }

  void _startSensor() {
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double currentZ = event.z;
      double rawStrain = (currentZ - _targetZ) / 5.0;
      double clampedStrain = rawStrain.clamp(0.0, 1.0);

      _tiltStrain.value = clampedStrain;
      bool bad = clampedStrain > 0.85;

      if (bad != _isBadPosture.value) {
        _isBadPosture.value = bad;
        _manageHapticLoop(bad);
      }
    });
  }

  void _calibrate() {
    HapticFeedback.heavyImpact();
    _audio.playSuccess();
    _audio.hapticSuccess();

    StreamSubscription? tempSub;
    tempSub = accelerometerEvents.listen((event) {
      setState(() {
        _targetZ = event.z;
        if (_targetZ > 6.0) _targetZ = 6.0;
      });
      tempSub?.cancel();
    });
  }

  void _manageHapticLoop(bool isBad) {
    _hapticTimer?.cancel();
    if (isBad) {
      _audio.hapticHeavy();
      HapticFeedback.heavyImpact();
      _hapticTimer = Timer.periodic(const Duration(seconds: 2), (t) {
        if (mounted && _isBadPosture.value) {
          _audio.hapticMedium();
          HapticFeedback.mediumImpact();
        }
      });
    } else {
      _audio.playDing();
      HapticFeedback.lightImpact();
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
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      // 🚀 STRICT SAFE AREA HANDLING
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

            // 🚀 STANDARD HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("CERVICAL HEALTH", style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Posture Trainer", style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      }
                  )
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

            // 🎯 DYNAMIC SCROLLABLE MIDDLE SECTION
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double gaugeSize = (constraints.maxHeight * 0.45).clamp(180.0, 280.0);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(height: 16),

                          // 🎯 DYNAMIC STATUS TEXT
                          // 🎯 DYNAMIC STATUS TEXT
                          ValueListenableBuilder<bool>(
                            valueListenable: _isBadPosture,
                            builder: (context, isBad, child) {
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  isBad ? "HEAD UP!" : "Perfect Alignment",
                                  key: UniqueKey(), // 🚀 THE FIX: Prevents Stack key collisions during rapid sensor fluttering
                                  style: TextStyle(
                                    fontFamily: kDisplayFont,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isBad ? Colors.redAccent : colorScheme.primary,
                                    letterSpacing: isBad ? 2.0 : 0.0,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // 🚀 REFINED SUBTITLE (Size 12, w500)
                          Text("Keep the phone elevated to protect your neck.", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w500)),

                          const SizedBox(height: 24),

                          // 🎯 LIVE ANIMATION & GAUGE
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
                                        strokeWidth: 8, // 🚀 Thinner, more elegant stroke
                                        backgroundColor: theme.dividerColor.withOpacity(0.1),
                                        valueColor: AlwaysStoppedAnimation(
                                            Color.lerp(colorScheme.primary, Colors.redAccent, strain) ?? colorScheme.primary
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                ValueListenableBuilder<double>(
                                  valueListenable: _tiltStrain,
                                  builder: (context, strain, child) {
                                    return CustomPaint(
                                      size: Size(gaugeSize * 0.7, gaugeSize * 0.7),
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

                          const SizedBox(height: 32),

                          // 🎯 CALIBRATION INFO
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: theme.hintColor, size: 18),
                                  const SizedBox(width: 12),
                                  // 🚀 REFINED INFO TEXT (Size 11, w500)
                                  Expanded(
                                    child: Text(
                                      "Hold your phone at eye level in a comfortable position, then tap Calibrate.",
                                      style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.w500, height: 1.5),
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
                height: 50, // 🚀 Standardized to 50
                child: FilledButton.icon(
                  onPressed: _calibrate,
                  style: FilledButton.styleFrom(
                      elevation: 0, // 🚀 Flat premium look
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                  // 🚀 REFINED BUTTON TEXT (Max Size 12, w700)
                  label: const Text("Set Target Posture", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
// =======================================================================
class _DynamicPosturePainter extends CustomPainter {
  final double strainProgress;
  final Color themeColor;

  _DynamicPosturePainter({required this.strainProgress, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final drawColor = Color.lerp(themeColor.withOpacity(0.5), Colors.redAccent, strainProgress) ?? themeColor;
    final paint = Paint()..color = drawColor..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;

    final base = Offset(cx - 20, cy + 70);

    double headX = cx + (strainProgress * 60);
    double headY = cy - 60 + (strainProgress * 40);
    double spineCurve = strainProgress * 50;

    final path = Path();
    path.moveTo(base.dx, base.dy);
    path.quadraticBezierTo(cx + spineCurve, cy, headX, headY + 20);
    canvas.drawPath(path, paint);

    canvas.drawCircle(Offset(headX, headY), 16, Paint()..color = drawColor);

    final phonePaint = Paint()..color = themeColor.withOpacity(0.3)..style = PaintingStyle.fill;

    final armElbow = Offset(cx + 10 + (strainProgress * 30), cy + 10 + (strainProgress * 20));
    final hands = Offset(headX + 25, headY + 50);

    canvas.drawLine(Offset(headX, headY + 25), armElbow, paint..strokeWidth = 4);
    canvas.drawLine(armElbow, hands, paint..strokeWidth = 4);

    canvas.save();
    canvas.translate(hands.dx + 5, hands.dy - 5);
    canvas.rotate(strainProgress * math.pi / 4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -15, 20, 30), const Radius.circular(4)), phonePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DynamicPosturePainter old) {
    return old.strainProgress != strainProgress || old.themeColor != themeColor;
  }
}