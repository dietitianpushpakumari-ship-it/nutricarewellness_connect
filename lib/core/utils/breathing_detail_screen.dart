import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

import 'mindfullness_config.dart';

class BreathingDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;
  final BreathingConfig config;

  const BreathingDetailSheet({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
    this.config = BreathingConfig.box,
  });

  @override
  ConsumerState<BreathingDetailSheet> createState() => _BreathingDetailSheetState();
}

class _BreathingDetailSheetState extends ConsumerState<BreathingDetailSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;

  String _phaseText = "Tap Start";
  String _timerText = "00:00";
  bool _isRunning = false;
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();

    // 1. Calculate Total Cycle Duration
    final int cycleDuration = widget.config.inhale + widget.config.hold1 + widget.config.exhale + widget.config.hold2;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: cycleDuration),
    );

    // 2. Build Dynamic Animation
    final double total = cycleDuration.toDouble();
    final double weightInhale = (widget.config.inhale / total) * 100;
    final double weightHold1 = (widget.config.hold1 / total) * 100;
    final double weightExhale = (widget.config.exhale / total) * 100;
    final double weightHold2 = (widget.config.hold2 / total) * 100;

    List<TweenSequenceItem<double>> items = [];

    if (weightInhale > 0) items.add(TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: weightInhale));
    if (weightHold1 > 0) items.add(TweenSequenceItem(tween: ConstantTween(1.0), weight: weightHold1));
    if (weightExhale > 0) items.add(TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5).chain(CurveTween(curve: Curves.easeIn)), weight: weightExhale));
    if (weightHold2 > 0) items.add(TweenSequenceItem(tween: ConstantTween(0.5), weight: weightHold2));

    _sizeAnimation = TweenSequence<double>(items).animate(_controller);

    // 3. Dynamic Text Listener
    _controller.addListener(() {
      final val = _controller.value;
      final tInhale = widget.config.inhale / total;
      final tHold1 = tInhale + (widget.config.hold1 / total);
      final tExhale = tHold1 + (widget.config.exhale / total);

      String newPhase = "";
      if (val <= tInhale) newPhase = "Inhale...";
      else if (val <= tHold1) newPhase = "Hold...";
      else if (val <= tExhale) newPhase = "Exhale...";
      else newPhase = "Hold...";

      if (newPhase != _phaseText && _isRunning) {
        HapticFeedback.lightImpact();
        setState(() => _phaseText = newPhase);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _toggleSession() {
    if (_isRunning) {
      _controller.stop();
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _phaseText = "Paused";
      });
      _saveSession();
    } else {
      _controller.repeat();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds++;
          final min = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
          final sec = (_elapsedSeconds % 60).toString().padLeft(2, '0');
          _timerText = "$min:$sec";
        });
      });
      setState(() => _isRunning = true);
    }
  }

  Future<void> _saveSession() async {
    final minutes = (_elapsedSeconds / 60).ceil();
    if (minutes == 0) return;

    try {
      final logToSave = widget.dailyLog ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: widget.notifier.state.selectedDate,
      );

      final updatedLog = logToSave.copyWith(
        breathingMinutes: (logToSave.breathingMinutes ?? 0) + minutes,
      );

      // 1. Save to Firestore
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      // 🎯 2. FIX: FORCE REFRESH OF PARENT DATA
      // This ensures the Home Screen updates its "Mind" stats immediately
      await widget.notifier.loadInitialData(widget.notifier.state.selectedDate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session Saved!"), backgroundColor: Colors.teal));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = widget.config.color;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [themeColor.withOpacity(0.1), Colors.white],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 40),

                  // Title (assuming BreathingConfig has 'name' or 'title' property)
                  Text(widget.config.title, style: TextStyle(color: themeColor.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(widget.config.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 20),
                  Text(_timerText, style: TextStyle(color: themeColor, fontSize: 18, fontFamily: 'monospace')),

                  const Spacer(),

                  // Animation
                  SizedBox(
                    height: 300,
                    width: 300,
                    child: AnimatedBuilder(
                      animation: _sizeAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 300 * _sizeAnimation.value,
                              height: 300 * _sizeAnimation.value,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor.withOpacity(0.1)),
                            ),
                            Container(
                              width: 260 * _sizeAnimation.value,
                              height: 260 * _sizeAnimation.value,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor.withOpacity(0.2)),
                            ),
                            Container(
                              width: 220 * _sizeAnimation.value,
                              height: 220 * _sizeAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [themeColor.withOpacity(0.6), themeColor],
                                ),
                                boxShadow: [BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                              ),
                              child: Center(
                                child: Text(
                                  _phaseText,
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _toggleSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning ? Colors.white : themeColor,
                        foregroundColor: _isRunning ? Colors.red : Colors.white,
                        elevation: _isRunning ? 2 : 4,
                        side: _isRunning ? const BorderSide(color: Colors.red) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_isRunning ? "Stop Session" : "Start Breathing", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}