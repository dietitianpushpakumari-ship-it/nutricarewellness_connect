import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

enum Co2State { idle, prep, hold, complete }

class Co2ToleranceSheet extends StatefulWidget {
  const Co2ToleranceSheet({super.key});

  @override
  State<Co2ToleranceSheet> createState() => _Co2ToleranceSheetState();
}

class _Co2ToleranceSheetState extends State<Co2ToleranceSheet> with TickerProviderStateMixin {
  Co2State _state = Co2State.idle;

  // Timers & State
  int _prepCountdown = 15; // 15 seconds to take 3 normal breaths
  Timer? _prepTimer;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer; // Used strictly to update the screen

  final _audio = WellnessAudioService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _startPrepPhase() {
    _audio.playDing();
    setState(() {
      _state = Co2State.prep;
      _prepCountdown = 15;
    });

    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _prepCountdown--;
      });

      if (_prepCountdown <= 3 && _prepCountdown > 0) {
        _audio.hapticLight(); // Warning ticks
      }

      if (_prepCountdown <= 0) {
        timer.cancel();
        _startHoldPhase();
      }
    });
  }

  void _startHoldPhase() {
    _audio.playSuccess(); // Long beep to indicate HOLD
    _audio.hapticHeavy();

    setState(() {
      _state = Co2State.hold;
    });

    _stopwatch.reset();
    _stopwatch.start();

    // UI Render Loop (Updates the stopwatch text every 50ms for a smooth 60fps feel)
    _uiTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && _state == Co2State.hold) {
        setState(() {}); // Repaints the stopwatch
      }
    });
  }

  void _endHoldPhase() {
    _stopwatch.stop();
    _uiTimer?.cancel();
    _audio.playDing();
    _audio.hapticSuccess();

    setState(() {
      _state = Co2State.complete;
    });
  }

  void _resetTest() {
    setState(() {
      _state = Co2State.idle;
      _stopwatch.reset();
    });
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _uiTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
                      Text("AUTONOMIC REGULATION", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text("Metabolic CO2 Tolerance", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

          // 🎯 2. DYNAMIC CONTENT AREA
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStateContent(theme, cs),
            ),
          ),

          // 🎯 3. ACTION CONTROLS
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: _buildActionButtons(theme, cs),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent(ThemeData theme, ColorScheme cs) {
    switch (_state) {
      case Co2State.idle:
        return _buildInstructions(theme, cs);
      case Co2State.prep:
        return _buildPrepPhase(theme, cs);
      case Co2State.hold:
        return _buildHoldPhase(theme, cs);
      case Co2State.complete:
        return _buildClinicalLog(theme, cs);
    }
  }

  // --- UI STATES ---

  Widget _buildInstructions(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.primary.withOpacity(0.2))),
          child: Column(
            children: [
              Icon(Icons.air_rounded, color: cs.primary, size: 40),
              const SizedBox(height: 16),
              const Text("The Apnea Protocol", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "This is not a maximum breath hold. Stop the timer at the FIRST definite urge to breathe or swallow.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.hintColor, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildTargetRow(Icons.looks_one_rounded, "Take 3 calm, normal breaths.", theme),
        _buildTargetRow(Icons.looks_two_rounded, "After the 3rd exhale, pinch your nose.", theme),
        _buildTargetRow(Icons.looks_3_rounded, "Hold until the first physical urge to breathe.", theme),
      ],
    );
  }

  Widget _buildPrepPhase(ThemeData theme, ColorScheme cs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("PREPARATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 2)),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) => Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withOpacity(0.1), border: Border.all(color: cs.primary, width: 2)),
              alignment: Alignment.center,
              child: Text("$_prepCountdown", style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: cs.primary)),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text("Take 3 normal breaths.\nExhale and hold on zero.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHoldPhase(ThemeData theme, ColorScheme cs) {
    String formattedTime = (_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("APNEA ACTIVE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 2)),
        const SizedBox(height: 24),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 240, height: 240,
              child: CircularProgressIndicator(value: 1.0, strokeWidth: 4, color: theme.dividerColor.withOpacity(0.1)),
            ),
            SizedBox(
              width: 240, height: 240,
              child: CircularProgressIndicator(value: null, strokeWidth: 4, color: cs.primary), // Indeterminate active spin
            ),
            Text(formattedTime, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: cs.primary, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 40),
        const Text("Relax your shoulders. Tap the button the moment you feel the physical urge to breathe.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildClinicalLog(ThemeData theme, ColorScheme cs) {
    double totalSeconds = _stopwatch.elapsedMilliseconds / 1000;
    String score = _getScoreLabel(totalSeconds);
    Color scoreColor = _getScoreColor(totalSeconds, cs);
    String feedback = _getClinicalFeedback(totalSeconds);



    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("TOLERANCE SCORE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: scoreColor.withOpacity(0.3), width: 2)),
          child: Column(
            children: [
              Text("${totalSeconds.toStringAsFixed(1)}s", style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: scoreColor, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(score.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scoreColor, letterSpacing: 1)),
              ),
              const SizedBox(height: 24),
              Text(feedback, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildActionButtons(ThemeData theme, ColorScheme cs) {
    if (_state == Co2State.idle) {
      return SizedBox(
        width: double.infinity, height: 56,
        child: FilledButton.icon(
          onPressed: _startPrepPhase,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text("COMMENCE CALIBRATION"),
          style: FilledButton.styleFrom(backgroundColor: cs.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      );
    } else if (_state == Co2State.prep) {
      return SizedBox(
        width: double.infinity, height: 56,
        child: FilledButton.icon(
          onPressed: null, // Disabled during prep
          icon: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
          label: const Text("PREPARING NERVOUS SYSTEM..."),
          style: FilledButton.styleFrom(backgroundColor: theme.dividerColor.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      );
    } else if (_state == Co2State.hold) {
      return SizedBox(
        width: double.infinity, height: 80, // Massive target area so they don't miss it
        child: FilledButton.icon(
          onPressed: _endHoldPhase,
          icon: const Icon(Icons.pan_tool_rounded, size: 28),
          label: const Text("I NEED TO BREATHE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(backgroundColor: cs.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity, height: 56,
        child: FilledButton.icon(
          onPressed: _resetTest,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text("RETEST BASELINE"),
          style: FilledButton.styleFrom(backgroundColor: cs.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      );
    }
  }

  Widget _buildTargetRow(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _getScoreLabel(double seconds) {
    if (seconds < 20) return "Severe Sympathetic Stress";
    if (seconds < 40) return "Moderate Vagal Tone";
    return "Elite Metabolic Efficiency";
  }

  Color _getScoreColor(double seconds, ColorScheme cs) {
    if (seconds < 20) return cs.error; // Red
    if (seconds < 40) return Colors.orange; // Yellow/Orange
    return Colors.green; // Green
  }

  String _getClinicalFeedback(double seconds) {
    if (seconds < 20) {
      return "Your nervous system is in a high-alert state. Blood is being diverted away from your digestive tract. Use the Box Breathing tool before meals to restore metabolic function.";
    } else if (seconds < 40) {
      return "Your autonomic nervous system is functioning normally. You have adequate oxygen delivery for standard digestive processes.";
    } else {
      return "Excellent vagal tone. Your body is in a profound state of 'Rest and Digest', ensuring maximum nutrient absorption from your diet plan.";
    }
  }
}