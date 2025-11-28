import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/activity_trend_chart.dart';
import 'package:nutricare_connect/core/utils/movement_Details_sheet.dart';
import 'package:nutricare_connect/core/utils/workout_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:collection/collection.dart';


class ActivityTrackerScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const ActivityTrackerScreen({super.key, required this.client});

  @override
  ConsumerState<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends ConsumerState<ActivityTrackerScreen> with WidgetsBindingObserver {
  Stream<StepCount>? _stepCountStream;
  int _liveSensorSteps = 0;
  bool _sensorActive = false;
  DateTime _lastAutoSaveTime = DateTime.now();
  int _stepsAtLastSave = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(stepSensorEnabledProvider)) _initPedometer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _forceSaveSteps();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _forceSaveSteps();
  }

  void _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((StepCount event) {
        if (mounted) {
          setState(() {
            _liveSensorSteps = event.steps;
            _sensorActive = true;
          });
          _smartAutoSync();
        }
      });
    }
  }

  void _smartAutoSync() {
    final now = DateTime.now();
    final stepDiff = (_liveSensorSteps - _stepsAtLastSave).abs();
    final timeDiff = now.difference(_lastAutoSaveTime).inMinutes;
    if ((stepDiff > 500 && timeDiff > 5) || stepDiff > 1000) {
      _forceSaveSteps();
    }
  }

  Future<void> _forceSaveSteps() async {
    if (_liveSensorSteps == 0) return;
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final state = ref.read(activeDietPlanProvider);
    if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) return;

    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;
    int newBaseline = baseline;
    if (baseline == 0 && _liveSensorSteps > 0) newBaseline = _liveSensorSteps;

    final int calculatedDailySteps = (newBaseline == 0) ? 0 : (_liveSensorSteps - newBaseline);
    if (calculatedDailySteps <= (dailyLog?.stepCount ?? 0)) return;

    final logToSave = dailyLog ?? ClientLogModel(
      id: '', clientId: state.activePlan!.clientId, dietPlanId: state.activePlan!.id,
      mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: DateTime.now(),
    );

    final updatedLog = logToSave.copyWith(sensorStepsBaseline: newBaseline, stepCount: calculatedDailySteps);
    _lastAutoSaveTime = DateTime.now();
    _stepsAtLastSave = _liveSensorSteps;
    await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
  }

  Future<void> _logWorkout(ClientLogModel? log, int calories, int durationMinutes) async {
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final state = ref.read(activeDietPlanProvider);
      final logToSave = log ?? ClientLogModel(
        id: '', clientId: state.activePlan!.clientId, dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: state.selectedDate,
      );

      final updatedLog = logToSave.copyWith(
        caloriesBurned: (logToSave.caloriesBurned ?? 0) + calories,
        activityScore: ((logToSave.activityScore ?? 0) + 15).clamp(0, 100),
      );

      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nice! +$calories kcal 🔥"), backgroundColor: Colors.green));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleTask(ClientLogModel? log, String task, bool isPersonal) async {
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final state = ref.read(activeDietPlanProvider);
      final logToSave = log ?? ClientLogModel(
        id: '', clientId: state.activePlan!.clientId, dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: state.selectedDate,
      );

      ClientLogModel updatedLog;
      if (isPersonal) {
        final current = List<String>.from(logToSave.completedPersonalGoals);
        if (current.contains(task)) current.remove(task); else current.add(task);
        updatedLog = logToSave.copyWith(completedPersonalGoals: current);
      } else {
        final current = List<String>.from(logToSave.completedMandatoryTasks);
        if (current.contains(task)) current.remove(task); else current.add(task);
        updatedLog = logToSave.copyWith(completedMandatoryTasks: current);
      }
      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.activePlan == null) return const Center(child: Text("No active plan."));

    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    // Live Data
    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;
    int displaySteps = dailyLog?.stepCount ?? 0;
    if (_sensorActive && DateUtils.isSameDay(state.selectedDate, DateTime.now()) && baseline > 0 && _liveSensorSteps >= baseline) {
      displaySteps = _liveSensorSteps - baseline;
    }

    final int dbSteps = dailyLog?.stepCount ?? 0;
    final int dbCals = dailyLog?.caloriesBurned ?? 0;
    final int liveStepCals = ((displaySteps - dbSteps) * 0.04).round();
    final int totalDisplayCals = dbCals + liveStepCals;
    final int stepGoal = state.activePlan!.dailyStepGoal > 0 ? state.activePlan!.dailyStepGoal : 8000;
    final int score = dailyLog?.activityScore ?? 0;
    final mandatoryTasks = state.activePlan!.mandatoryDailyTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Activity Lab", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                  Text(DateFormat('MMM d').format(state.selectedDate), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                ],
              ),
            ),
          ),

          // 2. CHART CARD (Clean White)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.only(top: 20, bottom: 20, right: 20), // Internal padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: ActivityTrendChart(clientId: widget.client.id, stepGoal: stepGoal),
            ),
          ),

          // 3. SCORE CARD (Premium Gradient)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], // Mystical Purple-Blue
                    begin: Alignment.topLeft, end: Alignment.bottomRight
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: const Color(0xFF2575FC).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Daily Activity Score", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text("$score", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 1.0)),
                        const SizedBox(height: 8),
                        const Text("Keep moving to boost your score!", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 70, width: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: 1.0, color: Colors.white24, strokeWidth: 6),
                        CircularProgressIndicator(value: (score / 100).clamp(0.0, 1.0), color: Colors.greenAccent, strokeWidth: 6, strokeCap: StrokeCap.round),
                        const Icon(Icons.bolt, color: Colors.white, size: 28)
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // 4. METRICS ROW (Calories & Steps)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: _buildMetricTile("Steps", "$displaySteps", " / $stepGoal", Icons.directions_walk, Colors.orange)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricTile("Burned", "$totalDisplayCals", " kcal", Icons.local_fire_department, Colors.red)),
                ],
              ),
            ),
          ),

          // 5. WORKOUT LOGGER (Action)
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => showDialog(context: context, builder: (_) => WorkoutEntryDialog(onSave: (t, d, c) => _logWorkout(dailyLog, c, d))),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.teal.shade100),
                  boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle), child: Icon(Icons.fitness_center, color: Colors.teal.shade700)),
                    const SizedBox(width: 16),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Log Workout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text("Add manual exercise", style: TextStyle(fontSize: 12, color: Colors.grey))]),
                    const Spacer(),
                    const Icon(Icons.add, color: Colors.teal),
                  ],
                ),
              ),
            ),
          ),

          // 6. MISSIONS
          if (mandatoryTasks.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 10), child: Text("Mission Checklist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final task = mandatoryTasks[index];
                final isCompleted = dailyLog?.completedMandatoryTasks.contains(task) ?? false;
                return _buildTaskCard(task, isCompleted, () => _toggleTask(dailyLog, task, false));
              }, childCount: mandatoryTasks.length)),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String suffix, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          RichText(text: TextSpan(children: [TextSpan(text: value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), TextSpan(text: suffix, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(String title, bool isCompleted, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(isCompleted ? Icons.check_circle : Icons.circle_outlined, color: isCompleted ? Colors.green : Colors.grey.shade400),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isCompleted ? Colors.green.shade900 : Colors.black87, decoration: isCompleted ? TextDecoration.lineThrough : null))),
          ],
        ),
      ),
    );
  }
}