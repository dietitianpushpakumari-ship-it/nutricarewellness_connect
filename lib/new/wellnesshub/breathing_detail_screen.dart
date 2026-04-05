import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

 // FlatClientDietPlanModel
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';
import '../../core/utils/mindfullness_config.dart';

class BreathingDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final FlatClientDietPlanModel activePlan; // 🚀 Strongly typed to Flat Model
  final ClientLogModel? dailyLog; // Represents the Master Record
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
  final _audio = WellnessAudioService();

  String _phaseText = "Ready";
  bool _hasStarted = false;
  bool _isRunning = false;
  Timer? _timer;

  final ValueNotifier<int> _elapsedSeconds = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();

    final int cycleDuration = widget.config.inhale + widget.config.hold1 + widget.config.exhale + widget.config.hold2;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: cycleDuration),
    );

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

    _controller.addListener(() {
      final val = _controller.value;
      final tInhale = widget.config.inhale / total;
      final tHold1 = tInhale + (widget.config.hold1 / total);
      final tExhale = tHold1 + (widget.config.exhale / total);

      String newPhase = "";
      if (val <= tInhale) newPhase = "Inhale";
      else if (val <= tHold1) newPhase = "Hold";
      else if (val <= tExhale) newPhase = "Exhale";
      else newPhase = "Hold";

      if (newPhase != _phaseText && _isRunning) {
        _audio.hapticMedium();
        if (newPhase == "Inhale" || newPhase == "Exhale") _audio.playDing();
        setState(() => _phaseText = newPhase);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    _elapsedSeconds.dispose();
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
    } else {
      _controller.repeat();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _elapsedSeconds.value++;
      });
      setState(() {
        _isRunning = true;
        _hasStarted = true;
      });
    }
  }

  // 🎯 ATOMIC MINDFULNESS SAVE
  Future<void> _saveAndClose() async {
    _timer?.cancel();
    _controller.stop();

    final minutes = (_elapsedSeconds.value / 60).ceil();

    if (minutes > 0) {
      try {
        final currentMinutes = widget.dailyLog?.breathingMinutes ?? 0;

        // 🎯 Atomic Update: Simply increment the breathingMinutes field
        await widget.notifier.updateDailyRecord(
            data: {
              'breathingMinutes': currentMinutes + minutes,
            }
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("+$minutes Min Mindful Breathing Saved! 🧘"),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )
          );
        }
      } catch (e) {
        debugPrint("Error saving breathing session: $e");
      }
    }

    if (mounted) Navigator.pop(context);
  }

  String _formatTime(int totalSeconds) {
    final min = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color themeColor = widget.config.color;

    // 🎯 Opaque Premium Background
    final solidBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: solidBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Stack(
        children: [
          // Subtle Gradient Overlay
          Positioned(
            top: 0, left: 0, right: 0, height: 300,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    themeColor.withOpacity(isDark ? 0.12 : 0.06),
                    solidBgColor.withOpacity(0.0)
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(3)))),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.config.title.toUpperCase(), style: TextStyle(color: themeColor, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            const SizedBox(height: 4),
                            Text(widget.config.description, style: TextStyle(color: theme.hintColor, fontSize: 15, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: theme.hintColor),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),

                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double circleSize = (constraints.maxHeight * 0.6).clamp(220.0, 350.0);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: _elapsedSeconds,
                            builder: (context, seconds, child) {
                              return Text(
                                  _formatTime(seconds),
                                  style: TextStyle(color: colorScheme.onSurface, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2)
                              );
                            },
                          ),
                          const SizedBox(height: 48),

                          SizedBox(
                            height: circleSize,
                            width: circleSize,
                            child: AnimatedBuilder(
                              animation: _sizeAnimation,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: circleSize * _sizeAnimation.value,
                                      height: circleSize * _sizeAnimation.value,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor.withOpacity(isDark ? 0.08 : 0.04)),
                                    ),
                                    Container(
                                      width: (circleSize * 0.82) * _sizeAnimation.value,
                                      height: (circleSize * 0.82) * _sizeAnimation.value,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor.withOpacity(isDark ? 0.15 : 0.08)),
                                    ),
                                    Container(
                                      width: (circleSize * 0.68) * _sizeAnimation.value,
                                      height: (circleSize * 0.68) * _sizeAnimation.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [themeColor.withOpacity(0.8), themeColor],
                                        ),
                                        boxShadow: [BoxShadow(color: themeColor.withOpacity(isDark ? 0.2 : 0.3), blurRadius: 25, spreadRadius: 2)],
                                      ),
                                    ),
                                    Text(
                                      _phaseText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    children: [
                      if (_hasStarted && !_isRunning) ...[
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: FilledButton.icon(
                            onPressed: _saveAndClose,
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text("Finish & Save", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _toggleSession,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRunning ? (isDark ? Colors.white.withOpacity(0.05) : theme.cardColor) : themeColor,
                            foregroundColor: _isRunning ? colorScheme.onSurface : Colors.white,
                            elevation: _isRunning ? 0 : 2,
                            side: _isRunning ? BorderSide(color: theme.dividerColor.withOpacity(0.2)) : BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                          label: Text(_isRunning ? "Pause" : (_hasStarted ? "Resume" : "Start Breathing"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}