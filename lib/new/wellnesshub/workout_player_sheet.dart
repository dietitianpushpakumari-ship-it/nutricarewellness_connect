import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart'; // 🎯 NEW IMPORT

import 'package:pure_shift/core/services/tts_service.dart';
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';
import 'package:pure_shift/core/utils/workout_config.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

// ==========================================================
// 🚀 THE MAGIC: Tie the local AI video paths directly to the Enum
// ==========================================================
extension ExerciseVideoMapper on ExerciseType {
  String get videoAssetPath {
    switch (this) {
      case ExerciseType.squat: return 'assets/videos/squat.mp4';
      case ExerciseType.pushup: return 'assets/videos/pushup.mp4';
      case ExerciseType.jumpingJack: return 'assets/videos/jumping_jacks.mp4';
      case ExerciseType.plank: return 'assets/videos/plank.mp4';
      case ExerciseType.lunges: return 'assets/videos/lunges.mp4';
      case ExerciseType.situp: return 'assets/videos/situps.mp4';
      case ExerciseType.gluteBridge: return 'assets/videos/glute_bridge.mp4';
      case ExerciseType.highKnees: return 'assets/videos/high_knees1.mp4';
      case ExerciseType.armCircles: return 'assets/videos/arm_circles1.mp4';
      case ExerciseType.shoulderShrug: return 'assets/videos/shoulder_shrug.mp4';
      case ExerciseType.neckRoll: return 'assets/videos/neck_roll1.mp4';
      case ExerciseType.wristStretch: return 'assets/videos/wrist_stretch.mp4';
      case ExerciseType.seatedTwist: return 'assets/videos/seated_twist.mp4';
      case ExerciseType.pacing: return 'assets/videos/pacing.mp4';
      case ExerciseType.calfRaise: return 'assets/videos/calf_raise.mp4';
      case ExerciseType.rest: return 'assets/videos/rest_breathing_female.mp4'; // Fallback for rests
      default: return 'assets/videos/rest_breathing.mp4';
    }
  }
}

class WorkoutPlayerSheet extends ConsumerStatefulWidget {
  final WorkoutConfig config;
  final ClientModel? client;

  const WorkoutPlayerSheet({super.key, required this.config, this.client});

  @override
  ConsumerState<WorkoutPlayerSheet> createState() => _WorkoutPlayerSheetState();
}

class _WorkoutPlayerSheetState extends ConsumerState<WorkoutPlayerSheet> with TickerProviderStateMixin {
  AnimationController? _progressController;
  final _audio = WellnessAudioService();
  final _speechService = TextToSpeechService();

  // 🎯 NEW: Video Controller
  VideoPlayerController? _videoController;

  int _currentStepIndex = 0;
  bool _isPaused = false;
  bool _isMuted = false;
  Timer? _timer;

  bool _hasStarted = false;
  bool _isPreparing = false;
  bool _isTimelineMode = false;

  bool _isFinished = false;
  double _rpeScore = 5.0;
  String _selectedMood = 'Energized';
  double _intensity = 1.0;

  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(0);

  @override
  void dispose() {
    _timer?.cancel();
    _progressController?.dispose();
    _speechService.stop();
    _secondsLeft.dispose();
    _videoController?.dispose(); // 🎯 Clean up video
    super.dispose();
  }

  // 🎯 NEW: Video Initialization Logic
  void _loadVideoForStep(ExerciseType type) {
    final oldController = _videoController;

    _videoController = VideoPlayerController.asset(type.videoAssetPath)
      ..initialize().then((_) {
        _videoController!.setLooping(true);
        if (!_isPaused && !_isPreparing) {
          _videoController!.play();
        }
        setState(() {}); // Trigger rebuild to show video
        oldController?.dispose(); // Dispose old video *after* new one loads
      }).catchError((error) {
        debugPrint("Error loading video: $error");
      });
  }

  void _beginWorkout() {
    HapticFeedback.mediumImpact();
    setState(() {
      _hasStarted = true;
      _isPreparing = true;
    });

    // Pre-load the first video while in the countdown
    _loadVideoForStep(widget.config.steps[0].type);

    _secondsLeft.value = 3;

    if (!_isMuted) {
      _audio.playDing();
      _speechService.speak(text: "Get ready!", languageCode: "en-US");
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft.value > 1) {
        _secondsLeft.value--;
        if (!_isMuted) _audio.playTick();
      } else {
        t.cancel();
        setState(() => _isPreparing = false);
        _videoController?.play(); // Start video when countdown ends
        _startStep(0);
      }
    });
  }

  void _startStep(int index) {
    if (index >= widget.config.steps.length) {
      _showCoolDownScreen();
      return;
    }

    final step = widget.config.steps[index];

    // Load new video if we advanced a step
    if (_currentStepIndex != index || index == 0) {
      _loadVideoForStep(step.type);
    }

    setState(() {
      _currentStepIndex = index;
      _isPaused = false;
    });

    final int adjustedDuration = (step.duration * _intensity).toInt();
    _secondsLeft.value = adjustedDuration;

    if (!_isMuted) {
      if (step.isRest) {
        _audio.playDing();
        _speechService.speak(text: "Rest for $adjustedDuration seconds", languageCode: "en-US");
      } else {
        _audio.hapticHeavy();
        _audio.playClick();
        _speechService.speak(text: step.isRepBased ? "${step.reps} ${step.title}. ${step.instruction}" : step.instruction, languageCode: "en-US");
      }
    }

    if (step.isRepBased) return;

    _progressController?.dispose();
    _progressController = AnimationController(vsync: this, duration: Duration(seconds: adjustedDuration))..forward();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isPaused) return;

      if (_secondsLeft.value > 0) {
        _secondsLeft.value--;
        if (step.switchSides && _secondsLeft.value == (adjustedDuration / 2).floor() && !_isMuted) {
          _audio.playDing();
          _speechService.speak(text: "Halfway there, switch sides!", languageCode: "en-US");
        }
        if (!_isMuted && _secondsLeft.value <= 3 && _secondsLeft.value > 0) _audio.playTick();
      } else {
        t.cancel();
        _startStep(index + 1);
      }
    });
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    if (!_hasStarted || _isPreparing || widget.config.steps[_currentStepIndex].isRepBased) return;
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _progressController?.stop();
        _videoController?.pause(); // 🎯 Pause video
      } else {
        _progressController?.forward();
        _videoController?.play(); // 🎯 Resume video
      }
    });
  }

  void _skipToNext() {
    HapticFeedback.selectionClick();
    if (!_hasStarted || _isPreparing) return;
    _timer?.cancel();
    _startStep(_currentStepIndex + 1);
  }

  void _skipToPrevious() {
    HapticFeedback.selectionClick();
    if (!_hasStarted || _isPreparing) return;
    if (_currentStepIndex > 0) {
      _timer?.cancel();
      _startStep(_currentStepIndex - 1);
    }
  }

  void _showCoolDownScreen() {
    _timer?.cancel();
    _videoController?.pause();
    if (!_isMuted) {
      _audio.playSuccess();
      _audio.hapticSuccess();
      _speechService.speak(text: "Workout Complete. Great job.", languageCode: "en-US");
    }
    setState(() => _isFinished = true);
  }

  Future<bool> _confirmExit() async {
    if (!_hasStarted) {
      Navigator.pop(context);
      return true;
    }
    _togglePause();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bool? exit = await showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
          title: Text("End Workout?", style: TextStyle(fontFamily: kDisplayFont, color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16)),
          content: Text("You haven't finished yet. Are you sure you want to quit? Calories won't be saved.", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 12, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Resume", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error.withOpacity(0.1), foregroundColor: cs.error, elevation: 0),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Quit", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      ),
    );

    if (exit != true) _togglePause();
    else if (mounted) Navigator.pop(context);
    return exit ?? false;
  }

  Future<void> _saveAndClose() async {
    HapticFeedback.mediumImpact();
    if (widget.client != null) {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client!.id).notifier);
      final state = ref.read(activeDietPlanProvider);
      if (state.activePlan != null) {
        final totalDurationSec = widget.config.steps.fold(0, (sum, item) => sum + (item.duration * _intensity).toInt());
        final int newWorkoutCalories = ((totalDurationSec / 60) * 5 * _intensity * (_rpeScore / 5)).ceil();
        final dailyRecord = state.dailyRecord;
        await notifier.updateDailyRecord(
          data: {
            'caloriesBurned': (dailyRecord?.caloriesBurned ?? 0) + newWorkoutCalories,
            'activityScore': ((dailyRecord?.activityScore ?? 0) + 20).clamp(0, 100),
            'lastWorkoutMood': _selectedMood,
            'lastWorkoutRPE': _rpeScore,
          },
        );
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_isFinished) return _buildPostWorkoutSummary(theme, cs, isDark);

    final step = widget.config.steps[_currentStepIndex];
    final isRest = step.isRest;
    final Color themeColor = isRest ? Colors.green : widget.config.color;
    final nextStep = (_currentStepIndex + 1 < widget.config.steps.length) ? widget.config.steps[_currentStepIndex + 1] : null;
    final double overallProgress = _hasStarted && !_isPreparing ? ((_currentStepIndex + 1) / widget.config.steps.length) : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), child: LinearProgressIndicator(value: overallProgress, minHeight: 4, backgroundColor: theme.dividerColor.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(themeColor))),
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.config.title.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    if (_hasStarted && !_isPreparing) Text("Step ${_currentStepIndex + 1} of ${widget.config.steps.length}", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w700)),
                  ],
                ),
                Row(
                  children: [
                    if (_hasStarted) IconButton(icon: Icon(_isTimelineMode ? Icons.radio_button_checked_rounded : Icons.format_list_bulleted_rounded, color: cs.primary, size: 20), onPressed: () => setState(() => _isTimelineMode = !_isTimelineMode)),
                    IconButton(icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: theme.hintColor, size: 20), onPressed: () => setState(() => _isMuted = !_isMuted)),
                    IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20), onPressed: _confirmExit),
                  ],
                )
              ],
            ),
          ),

          Expanded(
            child: !_hasStarted
                ? _buildPreWorkoutSettings(theme, cs, themeColor, isDark)
                : _isTimelineMode
                ? _buildTimelineMode(theme, cs, themeColor)
                : _buildFocusMode(theme, cs, themeColor, step, isRest, nextStep, isDark),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 20),
            child: !_hasStarted
                ? SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton.icon(
                onPressed: _beginWorkout,
                style: FilledButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text("Start Workout", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.skip_previous_rounded), iconSize: 28, color: _currentStepIndex == 0 || _isPreparing ? theme.dividerColor : cs.onSurface, onPressed: _currentStepIndex == 0 || _isPreparing ? null : _skipToPrevious),
                const SizedBox(width: 24),

                if (step.isRepBased && !_isPreparing)
                  SizedBox(
                    height: 50,
                    child: FloatingActionButton.extended(
                      backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0,
                      onPressed: _skipToNext,
                      label: const Text("Done", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12)),
                      icon: const Icon(Icons.check_rounded, size: 18),
                    ),
                  )
                else FloatingActionButton(
                    backgroundColor: _isPreparing ? theme.disabledColor : themeColor, foregroundColor: Colors.white, elevation: 0,
                    onPressed: _isPreparing ? null : _togglePause,
                    child: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 24)
                ),

                const SizedBox(width: 24),
                IconButton(icon: const Icon(Icons.skip_next_rounded), iconSize: 28, color: _isPreparing ? theme.dividerColor : cs.onSurface, onPressed: _isPreparing ? null : _skipToNext),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreWorkoutSettings(ThemeData theme, ColorScheme cs, Color themeColor, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.fitness_center_rounded, size: 48, color: themeColor)),
        const SizedBox(height: 24),
        Text(widget.config.title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(widget.config.description, textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: theme.hintColor, height: 1.5))),
        const SizedBox(height: 32),
        Text("SELECT INTENSITY", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _intensityChip("Beginner", 0.8, themeColor, theme, isDark),
            const SizedBox(width: 8),
            _intensityChip("Standard", 1.0, themeColor, theme, isDark),
            const SizedBox(width: 8),
            _intensityChip("Advanced", 1.2, themeColor, theme, isDark),
          ],
        )
      ],
    );
  }

  Widget _intensityChip(String label, double value, Color activeColor, ThemeData theme, bool isDark) {
    final isSelected = _intensity == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
      selected: isSelected,
      onSelected: (sel) { if (sel) { HapticFeedback.selectionClick(); setState(() => _intensity = value); } },
      selectedColor: activeColor,
      backgroundColor: theme.cardColor,
      side: BorderSide(color: isSelected ? activeColor : theme.dividerColor.withOpacity(0.1)),
    );
  }

  Widget _buildPostWorkoutSummary(ThemeData theme, ColorScheme cs, bool isDark) {
    // [Unchanged from previous code]
    return Container(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(child: Icon(Icons.emoji_events_rounded, color: Colors.amber.shade600, size: 64)),
              const SizedBox(height: 16),
              Center(child: Text("Workout Complete!", style: TextStyle(fontFamily: kDisplayFont, fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface))),
              const SizedBox(height: 32),

              Text("How hard was it? (Effort Level)", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 12)),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                child: Slider(
                  value: _rpeScore, min: 1, max: 10, divisions: 9,
                  activeColor: widget.config.color,
                  onChanged: (val) { HapticFeedback.selectionClick(); setState(() => _rpeScore = val); },
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Too Easy", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 10)), Text("Maximum Effort", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 10))]),

              const SizedBox(height: 32),
              Text("How do you feel?", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _moodBtn("Exhausted", "😫", theme, isDark, cs),
                  _moodBtn("Good", "🙂", theme, isDark, cs),
                  _moodBtn("Energized", "🤩", theme, isDark, cs),
                ],
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity, height: 50,
                child: FilledButton(
                  onPressed: _saveAndClose,
                  style: FilledButton.styleFrom(backgroundColor: widget.config.color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text("Save & Close", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _moodBtn(String label, String emoji, ThemeData theme, bool isDark, ColorScheme cs) {
    // [Unchanged from previous code]
    final isSelected = _selectedMood == label;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedMood = label); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? widget.config.color.withOpacity(0.1) : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? widget.config.color : theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: isSelected ? widget.config.color : cs.onSurface)),
          ],
        ),
      ),
    );
  }

  // 🎯 REVAMPED UI: The Video Player Card
  Widget _buildFocusMode(ThemeData theme, ColorScheme cs, Color themeColor, WorkoutStep step, bool isRest, WorkoutStep? nextStep, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust the video container size dynamically
        final double videoHeight = (constraints.maxHeight * 0.45).clamp(200.0, 300.0);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // 🚀 THE NEW VIDEO CONTAINER
                Container(
                  height: videoHeight,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: themeColor.withOpacity(0.2), width: 2),
                    boxShadow: [
                      BoxShadow(color: themeColor.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The Video
                        if (_videoController != null && _videoController!.value.isInitialized)
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          )
                        else
                          CircularProgressIndicator(color: themeColor), // Loading state

                        // Overlay for "Rest" or "Prep" to dim the video slightly and show the timer
                        if (_isPreparing || isRest)
                          Container(color: Colors.black.withOpacity(0.6)), // Dimmer

                        if (_isPreparing || isRest)
                          ValueListenableBuilder<int>(
                              valueListenable: _secondsLeft,
                              builder: (ctx, sec, _) => Text(
                                  "$sec",
                                  style: TextStyle(fontFamily: kDisplayFont, fontSize: 80, fontWeight: FontWeight.w700, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)])
                              )
                          ),

                        // Overlay for "Rep Based" exercises so users know it's not timed
                        if (step.isRepBased && !_isPreparing)
                          Positioned(
                            bottom: 16, right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
                              child: Text("x${step.reps}", style: const TextStyle(fontFamily: kDisplayFont, fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          )
                      ],
                    ),
                  ),
                ),

                // Timer Display (Only if it's an active, timed exercise)
                if (!_isPreparing && !isRest && !step.isRepBased)
                  Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: ValueListenableBuilder<int>(
                          valueListenable: _secondsLeft,
                          builder: (ctx, sec, _) => Text("$sec", style: TextStyle(fontFamily: kDisplayFont, fontSize: 48, fontWeight: FontWeight.w700, color: themeColor))
                      )
                  ),

                if (step.isRepBased && !_isPreparing)
                  Padding(padding: const EdgeInsets.only(top: 24), child: Text("REPS", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 2))),

                const SizedBox(height: 16),
                Text(_isPreparing ? "GET READY" : isRest ? "REST" : step.title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 24, fontWeight: FontWeight.w700, color: cs.onSurface), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(_isPreparing ? "Starting with ${step.title}" : step.instruction, textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 13, color: theme.hintColor, height: 1.5))),

                // Up Next Bar
                if (nextStep != null && !_isPreparing)
                  Container(
                    margin: const EdgeInsets.only(top: 32, left: 24, right: 24),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                    child: Row(children: [Text("Up Next: ", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, color: theme.hintColor)), Expanded(child: Text(nextStep.title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface), overflow: TextOverflow.ellipsis)), Text(nextStep.isRepBased ? "${nextStep.reps} Reps" : "${nextStep.duration}s", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w700))]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineMode(ThemeData theme, ColorScheme cs, Color themeColor) {
    // [Unchanged from previous code]
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: widget.config.steps.length,
      itemBuilder: (context, index) {
        final step = widget.config.steps[index];
        final isPast = index < _currentStepIndex;
        final isActive = index == _currentStepIndex;

        if (isActive) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16, top: 4),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(step.icon, color: themeColor, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ACTIVE", style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.redAccent)), Text(step.isRest ? "Rest" : step.title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface))])),
                    if (!_isPreparing && !step.isRepBased) ValueListenableBuilder<int>(valueListenable: _secondsLeft, builder: (ctx, sec, _) => Text("${sec}s", style: TextStyle(fontFamily: kDisplayFont, fontSize: 18, fontWeight: FontWeight.w700, color: themeColor)))
                    else if (!_isPreparing && step.isRepBased) Text("x${step.reps}", style: TextStyle(fontFamily: kDisplayFont, fontSize: 18, fontWeight: FontWeight.w700, color: themeColor))
                  ],
                ),
                if (step.instruction.isNotEmpty && !step.isRest) ...[const SizedBox(height: 12), Text(step.instruction, style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: cs.onSurface, height: 1.5))]
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: isPast ? Colors.transparent : theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isPast ? Colors.transparent : theme.dividerColor.withOpacity(0.1))),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: isPast ? Colors.green.withOpacity(0.1) : theme.dividerColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isPast ? Icons.check_rounded : step.icon, color: isPast ? Colors.green : theme.hintColor, size: 16)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.isRest ? "Rest" : step.title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, color: isPast ? theme.hintColor : cs.onSurface, decoration: isPast ? TextDecoration.lineThrough : null)),
                    Text(step.isRepBased ? "${step.reps} Reps" : "${step.duration} sec", style: TextStyle(fontFamily: kBodyFont, fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}