import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:collection/collection.dart';

class BreathingExerciseScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const BreathingExerciseScreen({super.key, required this.client});

  @override
  ConsumerState<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends ConsumerState<BreathingExerciseScreen>
    with TickerProviderStateMixin {

  // 🎯 The 16-second "master clock" for the 4-4-4-4 cycle
  late AnimationController _masterClockController;

  late Animation<double> _scaleAnimation;  // Drives the orb size
  late Animation<double> _glowAnimation;   // Drives the background glow
  late Animation<Color?> _colorAnimation;  // Drives the orb color

  String _instructionText = "Get Ready...";
  String _sessionTimeText = "00:00";
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  Timer? _sessionTimer;

  // 4 seconds per phase (4 * 4 = 16s total cycle)
  final int _phaseDuration = 4;

  @override
  void initState() {
    super.initState();

    _masterClockController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _phaseDuration * 4), // 16 seconds
    );

    // 2. 🎯 The "Scale" animation (0.9 = small, 1.0 = large)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25.0),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25.0),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9).chain(CurveTween(curve: Curves.easeIn)), weight: 25.0),
      TweenSequenceItem(tween: ConstantTween(0.9), weight: 25.0),
    ]).animate(_masterClockController);

    // 3. 🎯 The "Glow" animation (15.0 = small, 60.0 = large)
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 15.0, end: 60.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25.0),
      TweenSequenceItem(tween: ConstantTween(60.0), weight: 25.0),
      TweenSequenceItem(tween: Tween(begin: 60.0, end: 15.0).chain(CurveTween(curve: Curves.easeIn)), weight: 25.0),
      TweenSequenceItem(tween: ConstantTween(15.0), weight: 25.0),
    ]).animate(_masterClockController);

    // 4. 🎯 The "Color" animation (Dim Orange to Bright Sun)
    final dimColor = Colors.orange.shade800;
    final brightColor = Colors.yellow.shade400;

    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(tween: ColorTween(begin: dimColor, end: brightColor), weight: 25.0),
      TweenSequenceItem(tween: ConstantTween(brightColor), weight: 25.0),
      TweenSequenceItem(tween: ColorTween(begin: brightColor, end: dimColor), weight: 25.0),
      TweenSequenceItem(tween: ConstantTween(dimColor), weight: 25.0),
    ]).animate(_masterClockController);


    // 5. 🎯 The Text updater, perfectly synced to the master clock
    _masterClockController.addListener(() {
      final progress = _masterClockController.value;

      setState(() {
        if (!_isRunning) {
          _instructionText = "Get Ready...";
        } else if (progress < 0.25) { // 0-4s
          _instructionText = "Inhale...";
        } else if (progress < 0.5) { // 4-8s
          _instructionText = "Hold...";
        } else if (progress < 0.75) { // 8-12s
          _instructionText = "Exhale...";
        } else { // 12-16s
          _instructionText = "Hold...";
        }
      });
    });

    // Loop the master clock
    _masterClockController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _masterClockController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _masterClockController.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _startStopAnimation() {
    if (_isRunning) {
      // --- STOPPING ---
      _masterClockController.stop();
      _sessionTimer?.cancel();
      setState(() {
        _isRunning = false;
        _instructionText = "Session Paused";
      });
      _saveProgress();
    } else {
      // --- STARTING ---
      setState(() {
        _isRunning = true;
        _elapsedSeconds = 0;
        _sessionTimeText = "00:00";
      });
      _masterClockController.forward(from: 0.0);
      _startTimer();
    }
  }

  void _startTimer() {
    _sessionTimer?.cancel(); // Cancel any existing timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
        final int minutes = _elapsedSeconds ~/ 60;
        final int seconds = _elapsedSeconds % 60;
        _sessionTimeText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      });
    });
  }

  Future<void> _saveProgress() async {
    final minutes = (_elapsedSeconds / 60).ceil();
    if (minutes == 0) return;

    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final state = ref.read(activeDietPlanProvider);

    if (state.activePlan == null) return;

    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    final logToSave = dailyLog ?? ClientLogModel(
      id: '',
      clientId: state.activePlan!.clientId,
      dietPlanId: state.activePlan!.id,
      mealName: 'DAILY_WELLNESS_CHECK',
      actualFoodEaten: ['Daily Wellness Data'],
      date: notifier.state.selectedDate,
    );

    final updatedLog = logToSave.copyWith(
      breathingMinutes: (logToSave.breathingMinutes ?? 0) + minutes,
    );

    try {
      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$minutes minutes of breathing logged!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save log: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E3A59), // Deep indigo
      appBar: AppBar(
        title: const Text('Guided Breathing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Instructions
            Text(
              _instructionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),

            // 2. 🎯 "Sun Glow" Animation
            AnimatedBuilder(
              animation: _masterClockController,
              builder: (context, child) {

                final color = _colorAnimation.value ?? Colors.orange.shade700;
                final scale = _scaleAnimation.value;
                final glow = _glowAnimation.value;

                return Transform.scale(
                  scale: scale, // 🎯 Animated Scale
                  child: Container(
                    width: 240, // 🎯 Increased Radius
                    height: 240, // 🎯 Increased Radius
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color, // 🎯 Animated Color
                      // 🎯 Animated Glow
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.7),
                          blurRadius: 40.0,
                          spreadRadius: glow, // 🎯 Animated Spread
                        )
                      ],
                    ),
                    child: Center(
                      // 🎯 NEW: Person Icon Inside
                      child: Icon(
                        Icons.self_improvement,
                        // Animate icon color to contrast with the glow
                        color: Colors.white.withOpacity(0.8),
                        size: 100, // 🎯 Larger icon
                      ),
                    ),
                  ),
                );
              },
            ),

            // 3. Timer and Stop Button
            Column(
              children: [
                Text(
                  _sessionTimeText,
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w200),
                ),
                const SizedBox(height: 20),
                IconButton(
                  icon: Icon(_isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 80),
                  color: Colors.white,
                  onPressed: _startStopAnimation,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}