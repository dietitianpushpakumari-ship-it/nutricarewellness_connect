import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class MealPacerSheet extends StatefulWidget {
  const MealPacerSheet({super.key});

  @override
  State<MealPacerSheet> createState() => _MealPacerSheetState();
}

class _MealPacerSheetState extends State<MealPacerSheet> with SingleTickerProviderStateMixin {
  String _phase = "Ready";
  String _clinicalDetail = "Prepare for nutrient absorption.";
  Timer? _timer;
  final int _chewSeconds = 20; // Clinical standard for enzyme mixing
  int _currentCount = 0;
  bool _isActive = false;

  final _audio = WellnessAudioService();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200)
    )..repeat(reverse: true);
  }

  void _startCycle() {
    if (!mounted) return;
    setState(() => _isActive = true);
    _runBitePhase();
  }

  void _stopCycle() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _isActive = false;
      _phase = "Ready";
      _clinicalDetail = "Pacing paused. Ready to resume.";
      _currentCount = 0;
    });
  }

  void _runBitePhase() {
    _runPhase("Take a Bite", "Portion control active.", 2, () {
      _runChewPhase();
    });
  }

  void _runChewPhase() {
    _runPhase("Chew Slowly", "Activating salivary amylase...", _chewSeconds, () {
      _runSwallowPhase();
    }, isChewing: true);
  }

  void _runSwallowPhase() {
    _runPhase("Swallow", "Digestive transit initiating.", 3, () {
      if (_isActive) _runBitePhase(); // Loop
    });
  }

  void _runPhase(String phase, String detail, int duration, VoidCallback onComplete, {bool isChewing = false}) {
    if (!mounted || !_isActive) return;

    setState(() {
      _phase = phase;
      _clinicalDetail = detail;
      _currentCount = duration;
    });

    if (isChewing) _audio.playDing(); // Signal start of long chew phase

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isActive) {
        t.cancel();
        return;
      }

      setState(() => _currentCount--);

      // 🎯 Haptic metronome to guide chewing pace
      if (isChewing && _currentCount % 2 == 0 && _currentCount > 0) {
        _audio.hapticLight();
      }

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // 🎯 1. COMPACT MEDICAL HEADER
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("METABOLIC PACING", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text("Clinical Meal Pacer", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // 🎯 2. PHASE DISPLAY (Glassmorphism Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.primary.withOpacity(0.1)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _phase,
                            key: ValueKey(_phase),
                            style: TextStyle(fontSize: 28, color: cs.primary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_clinicalDetail, style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 🎯 3. BIOMETRIC ANATOMY PAINTER
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle background pulse
                        if (_isActive)
                          ScaleTransition(
                            scale: _animController,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.1), blurRadius: 40)],
                              ),
                            ),
                          ),

                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _AnatomicalPainter(
                                phase: _phase,
                                animValue: _animController.value,
                                color: cs.primary,
                              ),
                              size: const Size(200, 200),
                            );
                          },
                        ),

                        // Center Countdown Overlay
                        if (_isActive && _phase == "Chew Slowly")
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "$_currentCount",
                              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 🎯 4. ACTION CONTROLS
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isActive ? _stopCycle : _startCycle,
                      icon: Icon(_isActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(_isActive ? "End Meal" : "Commence Pacing", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isActive ? theme.colorScheme.error.withOpacity(0.8) : cs.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("Leptin satiety signaling requires 20 minutes of paced digestion.", textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor, fontSize: 11)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🎯 BIOMETRIC HUD PAINTER
class _AnatomicalPainter extends CustomPainter {
  final String phase;
  final double animValue;
  final Color color;

  _AnatomicalPainter({required this.phase, required this.animValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Clinical Blueprint Style
    final outlinePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // 1. Sleek Profile Wireframe
    final path = Path();
    path.moveTo(cx, cy - 80);
    path.quadraticBezierTo(cx + 40, cy - 80, cx + 45, cy - 30);
    path.lineTo(cx + 60, cy - 10);
    path.lineTo(cx + 45, cy + 10);

    // Jaw Dynamics
    double jawOffset = 0;
    if (phase == "Take a Bite") jawOffset = 18;
    if (phase == "Chew Slowly") jawOffset = 4 + (animValue * 12);

    path.moveTo(cx + 45, cy + 10);
    path.lineTo(cx + 35, cy + 10 + jawOffset);
    path.quadraticBezierTo(cx, cy + 50 + jawOffset, cx - 25, cy + 30);
    path.lineTo(cx - 25, cy - 40);

    // Draw the "blueprint" profile
    canvas.drawPath(path, outlinePaint);

    // Esophagus indicator (Clinical touch)
    canvas.drawLine(Offset(cx - 10, cy + 40), Offset(cx - 10, cy + 90), outlinePaint..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 5, cy + 40 + jawOffset), Offset(cx + 5, cy + 90), outlinePaint);

    // 2. Bolus (Food) Tracking
    if (phase == "Swallow") {
      final double throatY = cy + 40 + (animValue * 50);
      canvas.drawCircle(Offset(cx - 2, throatY), 6, glowPaint);
    } else if (phase != "Ready") {
      // Food mixing in mouth
      canvas.drawCircle(Offset(cx + 25, cy + 15 + (jawOffset / 2)), 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnatomicalPainter old) => true;
}