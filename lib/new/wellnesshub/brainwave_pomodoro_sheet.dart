import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class BrainwavePomodoroSheet extends StatefulWidget {
  const BrainwavePomodoroSheet({super.key});
  @override
  State<BrainwavePomodoroSheet> createState() => _BrainwavePomodoroSheetState();
}

class _BrainwavePomodoroSheetState extends State<BrainwavePomodoroSheet> with SingleTickerProviderStateMixin {
  // ⏱️ Timer State
  final int _totalSeconds = 25 * 60; // 25 Minutes
  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(25 * 60);
  bool _isRunning = false;
  Timer? _timer;

  // 🎵 Audio & Animation State
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _visualPulseController;
  String _selectedWave = "Beta (Focus)";

  // 🧠 Brainwave Configurations (Speed multiplier for audio & visual pulse)
  final Map<String, Map<String, dynamic>> _waveConfigs = {
    "Beta (Focus)": {"speed": 1.5, "animDuration": 600, "color": Colors.teal},
    "Alpha (Flow)": {"speed": 1.0, "animDuration": 1200, "color": Colors.indigo},
    "Theta (Deep)": {"speed": 0.6, "animDuration": 2000, "color": Colors.deepPurple},
  };

  @override
  void initState() {
    super.initState();

    // 🎯 FIX: Initialize with a default duration, and REMOVE the ..repeat() cascade
    _visualPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Default starting duration
    );

    _initAudio();
    _updateWaveState(); // This will automatically set the correct duration based on the selected wave
  }

  Future<void> _initAudio() async {
    try {
      // 🎯 Ensure you drop a file named 'focus_tone.mp3' in your assets/audio folder!
      // This can be a seamless brown noise or low hum.
      await _audioPlayer.setAsset('assets/audio/focus_tone.mp3');
      await _audioPlayer.setLoopMode(LoopMode.all);
    } catch (e) {
      debugPrint("Audio load error: Ensure focus_tone.mp3 is in assets and pubspec.yaml. $e");
    }
  }

  void _updateWaveState() {
    final config = _waveConfigs[_selectedWave]!;

    // Update audio speed
    _audioPlayer.setSpeed(config["speed"]);

    // Update visual pulse speed
    _visualPulseController.duration = Duration(milliseconds: config["animDuration"]);
    if (_isRunning) {
      _visualPulseController.repeat(reverse: true);
    }
  }

  void _changeWave(String wave) {
    setState(() {
      _selectedWave = wave;
      _updateWaveState();
    });
  }

  void _toggleTimer() async { // 🎯 Added async
    if (_isRunning) {
      // Pause
      _timer?.cancel();
      _audioPlayer.pause();
      _visualPulseController.stop();
      setState(() => _isRunning = false);
    } else {
      // Play
      setState(() => _isRunning = true);
      _visualPulseController.repeat(reverse: true);

      // 🎯 Make sure audio is actually ready before playing
      if (_audioPlayer.processingState == ProcessingState.idle) {
        await _initAudio();
      }

      _audioPlayer.play();

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft.value > 0) {
          _secondsLeft.value--;
        } else {
          _sessionComplete();
        }
      });
    }
  }

  void _sessionComplete() {
    _timer?.cancel();
    _audioPlayer.stop();
    _visualPulseController.stop();
    setState(() => _isRunning = false);
    WellnessAudioService().playSuccess(); // Rings when 25 mins are up
  }

  String _formatTime(int totalSecs) {
    int m = totalSecs ~/ 60;
    int s = totalSecs % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _visualPulseController.dispose();
    _secondsLeft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentConfig = _waveConfigs[_selectedWave]!;
    final activeColor = currentConfig["color"] as Color;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            // 🎯 HEADER
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
              child: Row(
                children: [
                  Text("DEEP WORK", style: TextStyle(color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const Spacer(),
                  IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
                ],
              ),
            ),

            // 🎯 WAVE SELECTOR
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _waveConfigs.keys.map((w) {
                  final isSel = _selectedWave == w;
                  final waveColor = _waveConfigs[w]!["color"] as Color;
                  return GestureDetector(
                    onTap: () => _changeWave(w),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? waveColor.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? waveColor : theme.dividerColor.withOpacity(0.2)),
                      ),
                      child: Text(w, style: TextStyle(color: isSel ? waveColor : theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
            ),

            // 🎯 DYNAMIC VISUAL TIMER
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                    animation: _visualPulseController,
                    builder: (context, child) {
                      return Container(
                        width: 280 + (_isRunning ? (_visualPulseController.value * 20) : 0),
                        height: 280 + (_isRunning ? (_visualPulseController.value * 20) : 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeColor.withOpacity(_isRunning ? 0.05 + (_visualPulseController.value * 0.05) : 0.05),
                          boxShadow: _isRunning ? [
                            BoxShadow(color: activeColor.withOpacity(0.2 * _visualPulseController.value), blurRadius: 40, spreadRadius: 10)
                          ] : [],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ValueListenableBuilder<int>(
                              valueListenable: _secondsLeft,
                              builder: (context, seconds, _) {
                                return CircularProgressIndicator(
                                  value: seconds / _totalSeconds,
                                  strokeWidth: 8,
                                  backgroundColor: theme.dividerColor.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation(activeColor),
                                );
                              },
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ValueListenableBuilder<int>(
                                    valueListenable: _secondsLeft,
                                    builder: (context, seconds, _) {
                                      return Text(_formatTime(seconds), style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: colorScheme.onSurface, fontFamily: 'Monospace'));
                                    },
                                  ),
                                  Text("Remaining", style: TextStyle(color: theme.hintColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                ),
              ),
            ),

            // 🎯 BOTTOM PLAY/PAUSE BUTTON
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: FilledButton.icon(
                  onPressed: _toggleTimer,
                  icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                  label: Text(_isRunning ? "Pause Session" : "Start Deep Work", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isRunning ? theme.cardColor : activeColor,
                    foregroundColor: _isRunning ? colorScheme.onSurface : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}