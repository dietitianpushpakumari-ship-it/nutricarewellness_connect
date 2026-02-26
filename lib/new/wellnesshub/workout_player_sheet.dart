import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/services/tts_service.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/wellnesshub/virtual_trainer_painter.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';
import 'package:nutricare_connect/core/utils/workout_config.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:collection/collection.dart';

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

  int _currentStepIndex = 0;
  bool _isPaused = false;
  bool _isMuted = false;
  Timer? _timer;
  late AnimationController _repController;

  bool _hasStarted = false;
  bool _isPreparing = false;
  bool _isTimelineMode = false;

  // 🎯 Post-Workout Summary State
  bool _isFinished = false;
  double _rpeScore = 5.0; // Rate of Perceived Exertion (1-10)
  String _selectedMood = 'Energized';

  // 🎯 Intensity Multiplier
  double _intensity = 1.0;

  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    //WakelockPlus.enable();
    _repController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  void _beginWorkout() {
    setState(() {
      _hasStarted = true;
      _isPreparing = true;
    });
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

    setState(() {
      _currentStepIndex = index;
      _isPaused = false;
    });

    // Apply Intensity Multiplier to duration
    final int adjustedDuration = (step.duration * _intensity).toInt();
    _secondsLeft.value = adjustedDuration;

    if (!_isMuted) {
      if (step.isRest) {
        _audio.playDing();
        _speechService.speak(text: "Rest for $adjustedDuration seconds", languageCode: "en-US");
      } else {
        _audio.hapticHeavy();
        _audio.playClick();
        _speechService.speak(text : step.isRepBased ? "${step.reps} ${step.title}. ${step.instruction}" : step.instruction, languageCode: "en-US");
      }
    }

    // 🎯 If Rep Based, don't start the timer countdown! Wait for manual "Done" click.
    if (step.isRepBased) return;

    _progressController?.dispose();
    _progressController = AnimationController(vsync: this, duration: Duration(seconds: adjustedDuration))..forward();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isPaused) return;

      if (_secondsLeft.value > 0) {
        _secondsLeft.value--;

        // 🎯 Halfway Alert Logic
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
    if (!_hasStarted || _isPreparing || widget.config.steps[_currentStepIndex].isRepBased) return;
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) _progressController?.stop();
      else _progressController?.forward();
    });
  }

  void _skipToNext() {
    if (!_hasStarted || _isPreparing) return;
    _timer?.cancel();
    _startStep(_currentStepIndex + 1);
  }

  void _skipToPrevious() {
    if (!_hasStarted || _isPreparing) return;
    if (_currentStepIndex > 0) {
      _timer?.cancel();
      _startStep(_currentStepIndex - 1);
    }
  }

  void _showCoolDownScreen() {
    _timer?.cancel();
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
    final colorScheme = theme.colorScheme;

    final bool? exit = await showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 🎯 Premium Glass Blur Effect
        child: AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor, // 🎯 Solid themed background
          elevation: 24,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.2))
          ),
          title: Text("End Workout?", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
          content: Text(
              "You haven't finished yet. Are you sure you want to quit? Calories won't be saved.",
              style: TextStyle(color: theme.hintColor, height: 1.4)
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text("Resume", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error.withOpacity(0.1), // 🎯 Soft error background
                foregroundColor: colorScheme.error, // 🎯 Red text
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Quit", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (exit == true) {
      if (mounted) Navigator.pop(context);
    } else {
      _togglePause();
    }
    return exit ?? false;
  }

// ... imports remain the same ...

  // 🎯 ATOMIC WORKOUT LOGGING
  Future<void> _saveAndClose() async {
    if (widget.client != null) {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client!.id).notifier);
      final state = ref.read(activeDietPlanProvider);

      if (state.activePlan != null) {
        // 1. Calculate stats based on intensity and effort
        final totalDurationSec = widget.config.steps.fold(0, (sum, item) => sum + (item.duration * _intensity).toInt());

        // Calories: 5 kcal/min base * intensity multiplier * RPE adjustment
        final int newWorkoutCalories = ((totalDurationSec / 60) * 5 * _intensity * (_rpeScore / 5)).ceil();

        // 2. 🎯 Use Single Source of Truth
        final dailyRecord = state.dailyRecord;
        final int currentTotalCalories = dailyRecord?.caloriesBurned ?? 0;
        final int currentActivityScore = dailyRecord?.activityScore ?? 0;

        // 3. 🎯 Execute Atomic Merge
        // We only touch calories and activity score; everything else stays intact.
        await notifier.updateDailyRecord(
          data: {
            'caloriesBurned': currentTotalCalories + newWorkoutCalories,
            // Boost score by a flat 20 points for finishing a guided workout
            'activityScore': (currentActivityScore + 20).clamp(0, 100),
            'lastWorkoutMood': _selectedMood, // Optional: tracking mood trends
            'lastWorkoutRPE': _rpeScore,      // Optional: tracking effort trends
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Workout Logged: +$newWorkoutCalories kcal 🔥"),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )
          );
        }
      }
    }
    if (mounted) Navigator.pop(context);
  }

// ... rest of the file (UI helpers) remains the same ...

  @override
  void dispose() {
    //WakelockPlus.disable();
    _timer?.cancel();
    _progressController?.dispose();
    _repController.dispose();
    _speechService.stop();
    _secondsLeft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🎯 If finished, show the Cooldown / Summary Screen
    if (_isFinished) return _buildPostWorkoutSummary(theme, colorScheme, isDark);

    final step = widget.config.steps[_currentStepIndex];
    final isRest = step.isRest;
    final Color themeColor = isRest ? Colors.green : widget.config.color;
    final nextStep = (_currentStepIndex + 1 < widget.config.steps.length) ? widget.config.steps[_currentStepIndex + 1] : null;

    final double overallProgress = _hasStarted && !_isPreparing ? ((_currentStepIndex + 1) / widget.config.steps.length) : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // 🎯 OVERALL PROGRESS BAR
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), child: LinearProgressIndicator(value: overallProgress, minHeight: 6, backgroundColor: theme.dividerColor.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(themeColor))),
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),

          // 🎯 HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 10, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.config.title.toUpperCase(), style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    if (_hasStarted && !_isPreparing) Text("Step ${_currentStepIndex + 1} of ${widget.config.steps.length}", style: TextStyle(fontSize: 14, color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    if (_hasStarted) IconButton(icon: Icon(_isTimelineMode ? Icons.radio_button_checked_rounded : Icons.format_list_bulleted_rounded, color: colorScheme.primary), onPressed: () => setState(() => _isTimelineMode = !_isTimelineMode)),
                    IconButton(icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: theme.hintColor), onPressed: () => setState(() => _isMuted = !_isMuted)),
                    IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: _confirmExit),
                  ],
                )
              ],
            ),
          ),

          // 🎯 DYNAMIC MIDDLE SECTION
          Expanded(
            child: !_hasStarted
                ? _buildPreWorkoutSettings(theme, colorScheme, themeColor, isDark)
                : _isTimelineMode
                ? _buildTimelineMode(theme, colorScheme, themeColor)
                : _buildFocusMode(theme, colorScheme, themeColor, step, isRest, nextStep, isDark),
          ),

          // 🎯 BOTTOM CONTROLS
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            child: !_hasStarted
                ? SizedBox(
              width: double.infinity, height: 64,
              child: FilledButton.icon(
                onPressed: _beginWorkout,
                style: FilledButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text("Start Workout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.skip_previous_rounded), iconSize: 32, color: _currentStepIndex == 0 || _isPreparing ? theme.dividerColor : colorScheme.onSurface, onPressed: _currentStepIndex == 0 || _isPreparing ? null : _skipToPrevious),
                const SizedBox(width: 24),

                // 🎯 Dynamic Action Button (Timer vs Reps)
                (step.isRepBased && !_isPreparing)
                    ? FloatingActionButton.extended(
                  backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 4,
                  onPressed: _skipToNext,
                  label: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  icon: const Icon(Icons.check_rounded),
                )
                    : FloatingActionButton.large(
                    backgroundColor: _isPreparing ? theme.disabledColor : themeColor, foregroundColor: Colors.white, elevation: 4, shape: const CircleBorder(),
                    onPressed: _isPreparing ? null : _togglePause,
                    child: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 40)
                ),

                const SizedBox(width: 24),
                IconButton(icon: const Icon(Icons.skip_next_rounded), iconSize: 32, color: _isPreparing ? theme.dividerColor : colorScheme.onSurface, onPressed: _isPreparing ? null : _skipToNext),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // 1. PRE-WORKOUT SETTINGS (Intensity)
  // =======================================================================
  Widget _buildPreWorkoutSettings(ThemeData theme, ColorScheme colorScheme, Color themeColor, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.fitness_center_rounded, size: 80, color: themeColor),
        ),
        const SizedBox(height: 24),
        Text(widget.config.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(widget.config.description, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: theme.hintColor))),
        const SizedBox(height: 40),
        Text("SELECT INTENSITY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: theme.hintColor)),
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
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
      selected: isSelected,
      onSelected: (sel) { if (sel) setState(() => _intensity = value); },
      selectedColor: activeColor,
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : theme.cardColor,
      side: BorderSide(color: isSelected ? activeColor : theme.dividerColor.withOpacity(0.2)),
    );
  }

  // =======================================================================
  // 2. POST-WORKOUT SUMMARY (RPE & Mood)
  // =======================================================================
  Widget _buildPostWorkoutSummary(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.emoji_events_rounded, color: Colors.amber.shade600, size: 80)),
              const SizedBox(height: 16),
              Center(child: Text("Workout Complete!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
              const SizedBox(height: 40),

              Text("How hard was it? (Effort Level)", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 16)),
              Slider(
                value: _rpeScore, min: 1, max: 10, divisions: 9,
                activeColor: widget.config.color,
                label: _rpeScore.toInt().toString(),
                onChanged: (val) => setState(() => _rpeScore = val),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Too Easy", style: TextStyle(color: theme.hintColor, fontSize: 12)), Text("Maximum Effort", style: TextStyle(color: theme.hintColor, fontSize: 12))],
              ),

              const SizedBox(height: 40),
              Text("How do you feel?", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _moodBtn("Exhausted", "😫", theme, isDark),
                  _moodBtn("Good", "🙂", theme, isDark),
                  _moodBtn("Energized", "🤩", theme, isDark),
                ],
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity, height: 60,
                child: FilledButton(
                  onPressed: _saveAndClose,
                  style: FilledButton.styleFrom(backgroundColor: widget.config.color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Save & Close", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _moodBtn(String label, String emoji, ThemeData theme, bool isDark) {
    final isSelected = _selectedMood == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedMood = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? widget.config.color.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : theme.cardColor),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? widget.config.color : theme.dividerColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? widget.config.color : theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // 3. FOCUS MODE (Timer / Rep Counter)
  // =======================================================================
  Widget _buildFocusMode(ThemeData theme, ColorScheme colorScheme, Color themeColor, WorkoutStep step, bool isRest, WorkoutStep? nextStep, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double mediaSize = (constraints.maxHeight * 0.45).clamp(180.0, 300.0);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: mediaSize, height: mediaSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.cardColor,
                    border: Border.all(color: themeColor.withOpacity(isDark ? 0.3 : 0.1), width: 4),
                    boxShadow: [BoxShadow(color: themeColor.withOpacity(isDark ? 0.15 : 0.1), blurRadius: 40, spreadRadius: 5)],
                  ),
                  child: (_isPreparing || isRest || step.isRepBased)
                      ? Center(
                      child: _isPreparing || isRest
                          ? ValueListenableBuilder<int>(valueListenable: _secondsLeft, builder: (ctx, sec, _) => Text("$sec", style: TextStyle(fontSize: mediaSize * 0.35, fontWeight: FontWeight.w900, color: themeColor)))
                          : Text("X ${step.reps}", style: TextStyle(fontSize: mediaSize * 0.25, fontWeight: FontWeight.w900, color: themeColor)) // 🎯 Reps view
                  )
                      : AnimatedBuilder(animation: _repController, builder: (ctx, child) => CustomPaint(painter: VirtualTrainerPainter(progress: _repController.value, type: step.type, color: themeColor), size: Size.infinite)),
                ),

                if (!_isPreparing && !isRest && !step.isRepBased)
                  Padding(padding: const EdgeInsets.only(top: 24), child: ValueListenableBuilder<int>(valueListenable: _secondsLeft, builder: (ctx, sec, _) => Text("$sec", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: themeColor, height: 1)))),
                if (step.isRepBased && !_isPreparing)
                  Padding(padding: const EdgeInsets.only(top: 24), child: Text("REPS", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 2, height: 1))),

                const SizedBox(height: 16),
                Text(_isPreparing ? "GET READY" : isRest ? "REST" : step.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(_isPreparing ? "Starting with ${step.title}" : step.instruction, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: theme.hintColor, height: 1.4))),

                if (nextStep != null && !_isPreparing)
                  Container(
                    margin: const EdgeInsets.only(top: 32, left: 24, right: 24),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                    child: Row(children: [Text("Up Next: ", style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor)), Expanded(child: Text(nextStep.title, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface), overflow: TextOverflow.ellipsis)), Text(nextStep.isRepBased ? "${nextStep.reps} Reps" : "${nextStep.duration}s", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold))]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =======================================================================
  // 4. TIMELINE MODE (List View)
  // =======================================================================
  Widget _buildTimelineMode(ThemeData theme, ColorScheme colorScheme, Color themeColor) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: widget.config.steps.length,
      itemBuilder: (context, index) {
        final step = widget.config.steps[index];
        final isPast = index < _currentStepIndex;
        final isActive = index == _currentStepIndex;

        if (isActive) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16, top: 4),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: themeColor.withOpacity(0.3), width: 2), boxShadow: [BoxShadow(color: themeColor.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: themeColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(step.icon, color: themeColor)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ACTIVE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.redAccent)), Text(step.isRest ? "Rest" : step.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface))])),
                    if (!_isPreparing && !step.isRepBased) ValueListenableBuilder<int>(valueListenable: _secondsLeft, builder: (ctx, sec, _) => Text("${sec}s", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColor)))
                    else if (!_isPreparing && step.isRepBased) Text("x${step.reps}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColor))
                  ],
                ),
                if (step.instruction.isNotEmpty && !step.isRest) ...[const SizedBox(height: 12), Text(step.instruction, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8), height: 1.4))]
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
              Container(width: 40, height: 40, decoration: BoxDecoration(color: isPast ? Colors.green.withOpacity(0.1) : theme.dividerColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isPast ? Icons.check_rounded : step.icon, color: isPast ? Colors.green : theme.hintColor, size: 20)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.isRest ? "Rest" : step.title, style: TextStyle(fontWeight: FontWeight.bold, color: isPast ? theme.hintColor : colorScheme.onSurface, decoration: isPast ? TextDecoration.lineThrough : null)),
                    Text(step.isRepBased ? "${step.reps} Reps" : "${step.duration} sec", style: TextStyle(fontSize: 12, color: theme.hintColor)),
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