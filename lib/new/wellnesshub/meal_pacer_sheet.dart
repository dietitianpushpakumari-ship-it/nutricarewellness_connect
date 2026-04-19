import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class MealPacerSheet extends StatefulWidget {
  const MealPacerSheet({super.key});

  @override
  State<MealPacerSheet> createState() => _MealPacerSheetState();
}

class _MealPacerSheetState extends State<MealPacerSheet> with SingleTickerProviderStateMixin {
  String _phase = "Ready";
  String _clinicalDetail = "Prepare for nutrient absorption.";
  Timer? _timer;
  final int _chewSeconds = 20;
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
    HapticFeedback.mediumImpact();
    setState(() => _isActive = true);
    _runBitePhase();
  }

  void _stopCycle() {
    _timer?.cancel();
    if (!mounted) return;
    HapticFeedback.lightImpact();
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
      if (_isActive) _runBitePhase();
    });
  }

  void _runPhase(String phase, String detail, int duration, VoidCallback onComplete, {bool isChewing = false}) {
    if (!mounted || !_isActive) return;

    setState(() {
      _phase = phase;
      _clinicalDetail = detail;
      _currentCount = duration;
    });

    if (isChewing) _audio.playDing();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isActive) {
        t.cancel();
        return;
      }

      setState(() => _currentCount--);

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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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

            // 🚀 STANDARD HEADER WITH CROSS BUTTON
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("METABOLIC PACING", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Clinical Meal Pacer", style: TextStyle(fontFamily: kBodyFont, color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
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
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: 24, color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_clinicalDetail, style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // 🚀 THE FIX: Floating Timer ABOVE the animation
                    if (_isActive && _phase == "Chew Slowly")
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: cs.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, color: cs.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "$_currentCount",
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: 24, fontWeight: FontWeight.w700, color: cs.primary, height: 1.0),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 72), // 🚀 Spacing placeholder so UI doesn't jump

                    // 🎯 3. BIOMETRIC ANATOMY PAINTER
                    SizedBox(
                      width: 180, // Slightly reduced size to fit perfectly with timer
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
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
                                size: const Size(160, 160),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // 🎯 4. ACTION CONTROLS
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _isActive ? _stopCycle : _startCycle,
                        icon: Icon(_isActive ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
                        label: Text(_isActive ? "End Meal" : "Commence Pacing", style: const TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _isActive ? theme.colorScheme.error.withOpacity(0.8) : cs.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text("Leptin satiety signaling requires 20 minutes of paced digestion.", textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    // Standardized center point logic
    final cx = size.width / 2;
    final cy = size.height / 2;

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

    final path = Path();
    // Head Top
    path.moveTo(cx, cy - 70);
    path.quadraticBezierTo(cx + 35, cy - 70, cx + 40, cy - 25);
    // Nose/Mouth
    path.lineTo(cx + 55, cy - 5);
    path.lineTo(cx + 40, cy + 10);

    double jawOffset = 0;
    if (phase == "Take a Bite") jawOffset = 18;
    if (phase == "Chew Slowly") jawOffset = 4 + (animValue * 12);

    // Jaw/Throat (Animated)
    path.moveTo(cx + 40, cy + 10);
    path.lineTo(cx + 30, cy + 10 + jawOffset);
    path.quadraticBezierTo(cx - 5, cy + 45 + jawOffset, cx - 25, cy + 25);
    // Back of neck/head
    path.lineTo(cx - 25, cy - 35);

    canvas.drawPath(path, outlinePaint);

    // Esophagus Outline
    canvas.drawLine(Offset(cx - 10, cy + 35), Offset(cx - 10, cy + 80), outlinePaint..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 5, cy + 35 + jawOffset), Offset(cx + 5, cy + 80), outlinePaint);

    // Bolus (Food) Glow indicator
    if (phase == "Swallow") {
      final double throatY = cy + 35 + (animValue * 45);
      canvas.drawCircle(Offset(cx - 2, throatY), 6, glowPaint);
    } else if (phase != "Ready") {
      canvas.drawCircle(Offset(cx + 25, cy + 12 + (jawOffset / 2)), 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnatomicalPainter old) => true;
}