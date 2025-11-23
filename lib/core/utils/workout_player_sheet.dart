import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/tts_service.dart';
import 'package:nutricare_connect/core/utils/virtual_trainer_painter.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';
import 'package:nutricare_connect/core/utils/workout_config.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/main.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // For ttsService


class WorkoutPlayerSheet extends ConsumerStatefulWidget {
  final WorkoutConfig config;
  final ClientModel? client;

  const WorkoutPlayerSheet({super.key, required this.config, this.client});

  @override
  ConsumerState<WorkoutPlayerSheet> createState() => _WorkoutPlayerSheetState();
}

class _WorkoutPlayerSheetState extends ConsumerState<WorkoutPlayerSheet> with TickerProviderStateMixin {
  late AnimationController _progressController;
  final _audio = WellnessAudioService();
  final _speechService = TextToSpeechService();

  int _currentStepIndex = 0;
  int _secondsLeft = 0;
  bool _isPaused = false;
  bool _isMuted = false;
  Timer? _timer;
  late AnimationController _repController;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _repController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000)
    )..repeat();

    _startStep(0);
  }

  void _startStep(int index) {
    if (index >= widget.config.steps.length) {
      _finishWorkout();
      return;
    }

    final step = widget.config.steps[index];
    setState(() {
      _currentStepIndex = index;
      _secondsLeft = step.duration;
      _isPaused = false;
    });

    if (!_isMuted) {
      if (step.isRest) {
        _audio.playDing();
        _speechService.speak(text: "Rest for ${step.duration} seconds", languageCode: "en-US");
      } else {
        _audio.hapticHeavy();
        _audio.playClick();
        _speechService.speak(text : step.instruction, languageCode: "en-US", );
      }
    }

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: step.duration),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isPaused) return;

      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
          if (!_isMuted && _secondsLeft <= 3 && _secondsLeft > 0) {
            _audio.playTick();
          }
        } else {
          t.cancel();
          _startStep(index + 1);
        }
      });
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _progressController.stop();
      } else {
        _progressController.forward();
      }
    });
  }

  Future<void> _saveSession() async {
    if (widget.client == null) return;

    final notifier = ref.read(dietPlanNotifierProvider(widget.client!.id).notifier);
    final state = ref.read(activeDietPlanProvider);

    if (state.activePlan == null) return;

    final totalDurationSec = widget.config.steps.fold(0, (sum, item) => sum + item.duration);
    final int minutes = (totalDurationSec / 60).ceil();
    final int calories = minutes * 5; // Approx 5 kcal/min

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
      caloriesBurned: (logToSave.caloriesBurned ?? 0) + calories,
    );

    await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved: +$calories kcal 🔥"), backgroundColor: Colors.green));
    }
  }

  void _finishWorkout() async {
    _timer?.cancel();
    if (!_isMuted) {
      _audio.playSuccess();
      _audio.hapticSuccess();
      _speechService.speak(text: "Workout Complete.", languageCode: "en-US",);
    }

    await _saveSession();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Workout Complete! 💪"),
        content: const Text("Great job! Your activity has been logged."),
        actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("Finish"))],
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _timer?.cancel();
    _progressController.dispose();
    _speechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.config.steps[_currentStepIndex];
    final isRest = step.isRest;
    final Color themeColor = isRest ? Colors.green : widget.config.color;
    final nextStep = (_currentStepIndex + 1 < widget.config.steps.length) ? widget.config.steps[_currentStepIndex + 1] : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: themeColor, width: 8)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.config.title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                IconButton(icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.grey), onPressed: () => setState(() => _isMuted = !_isMuted)),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: step.isRest
                ? Center(
              child: Text(
                  "$_secondsLeft",
                  style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: themeColor)
              ),
            )
                : AnimatedBuilder(
              animation: _repController,
              builder: (context, child) {
                return CustomPaint(
                  painter: VirtualTrainerPainter(
                    progress: _repController.value,
                    type: step.type,
                    color: themeColor,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),

          // 🎯 VISUALS (GIF or ICON)


          if (!isRest) Padding(padding: const EdgeInsets.only(top: 20), child: Text("$_secondsLeft s", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: themeColor))),

          const SizedBox(height: 20),
          Text(isRest ? "REST" : step.title, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: themeColor)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(step.instruction, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.black54))),
          const Spacer(),

          if (nextStep != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [const Text("Up Next: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), Icon(nextStep.icon, size: 16, color: Colors.black54), const SizedBox(width: 8), Text(nextStep.title, style: const TextStyle(fontWeight: FontWeight.w600))]),
            ),

          const SizedBox(height: 20),
          FloatingActionButton.large(backgroundColor: themeColor, foregroundColor: Colors.white, onPressed: _togglePause, child: Icon(_isPaused ? Icons.play_arrow : Icons.pause)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(WorkoutStep step, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(step.icon, size: 80, color: color),
      ],
    );
  }
}