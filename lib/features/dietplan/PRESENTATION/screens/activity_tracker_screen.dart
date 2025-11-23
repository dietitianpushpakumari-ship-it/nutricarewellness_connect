import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/activity_trend_chart.dart';
import 'package:nutricare_connect/core/utils/movement_Details_sheet.dart';
import 'package:nutricare_connect/core/utils/workout_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityTrackerScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const ActivityTrackerScreen({super.key, required this.client});

  @override
  ConsumerState<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends ConsumerState<ActivityTrackerScreen> {
  // Sensor State
  Stream<StepCount>? _stepCountStream;
  int _sensorSteps = 0;
  bool _sensorActive = false;

  // Local State for "Quick Check" interactions before saving
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize sensor if enabled
    final bool sensorEnabled = ref.read(stepSensorEnabledProvider);
    if (sensorEnabled) {
      _initPedometer();
    }
  }

  Future<void> _logWorkout(ClientLogModel? log, int calories, int durationMinutes) async {
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final state = ref.read(activeDietPlanProvider);

      final logToSave = log ?? ClientLogModel(
        id: '',
        clientId: state.activePlan!.clientId,
        dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: state.selectedDate,
      );

      // 1. Add Calories
      final int currentCals = logToSave.caloriesBurned ?? 0;
      final int newCals = currentCals + calories;

      // 2. Boost Score (Bonus points for logging a workout!)
      final int currentScore = logToSave.activityScore ?? 0;
      // Cap score addition so it doesn't exceed 100 easily
      final int newScore = (currentScore + 15).clamp(0, 100);

      final updatedLog = logToSave.copyWith(
        caloriesBurned: newCals,
        activityScore: newScore,
      );

      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Nice! +$calories kcal & Score Boosted! 🔥"),
            backgroundColor: Colors.green
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  void _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((StepCount event) {
        if (mounted) {
          setState(() {
            _sensorSteps = event.steps;
            _sensorActive = true;
          });
        }
      });
    }
  }

  // --- ACTIONS ---

  Future<void> _toggleTask(ClientLogModel? log, String task, bool isPersonal) async {
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final state = ref.read(activeDietPlanProvider);

      final logToSave = log ?? ClientLogModel(
        id: '',
        clientId: state.activePlan!.clientId,
        dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: state.selectedDate,
      );

      ClientLogModel updatedLog;

      if (isPersonal) {
        final current = List<String>.from(logToSave.completedPersonalGoals);
        if (current.contains(task)) current.remove(task);
        else current.add(task);
        updatedLog = logToSave.copyWith(completedPersonalGoals: current);
      } else {
        final current = List<String>.from(logToSave.completedMandatoryTasks);
        if (current.contains(task)) current.remove(task);
        else current.add(task);
        updatedLog = logToSave.copyWith(completedMandatoryTasks: current);
      }

      // Recalculate Score
      final int stepScore = (logToSave.stepCount ?? 0) > (logToSave.stepGoal ?? 8000) ? 50 : 30;
      final int taskScore = (updatedLog.completedMandatoryTasks.length * 10).clamp(0, 50);
      updatedLog = updatedLog.copyWith(activityScore: stepScore + taskScore);

      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addPersonalGoal(ClientLogModel? log, String newGoal) async {
    if (newGoal.isEmpty) return;
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final state = ref.read(activeDietPlanProvider);

    final logToSave = log ?? ClientLogModel(
      id: '',
      clientId: state.activePlan!.clientId,
      dietPlanId: state.activePlan!.id,
      mealName: 'DAILY_WELLNESS_CHECK',
      actualFoodEaten: ['Daily Wellness Data'],
      date: state.selectedDate,
    );

    final currentGoals = List<String>.from(logToSave.createdPersonalGoals);
    if (!currentGoals.contains(newGoal)) {
      currentGoals.add(newGoal);
      final updatedLog = logToSave.copyWith(createdPersonalGoals: currentGoals);
      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
    }
  }

  Future<void> _deletePersonalGoal(ClientLogModel? log, String goal) async {
    if (log == null) return;
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);

    final currentGoals = List<String>.from(log.createdPersonalGoals);
    final completed = List<String>.from(log.completedPersonalGoals);

    currentGoals.remove(goal);
    completed.remove(goal);

    final updatedLog = log.copyWith(createdPersonalGoals: currentGoals, completedPersonalGoals: completed);
    await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.activePlan == null) return const Center(child: Text("No active plan."));

    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    final int currentSteps = dailyLog?.stepCount ?? 0;
    final int stepGoal = state.activePlan!.dailyStepGoal > 0 ? state.activePlan!.dailyStepGoal : 8000;
    final int score = dailyLog?.activityScore ?? 0;
    final int calories = dailyLog?.caloriesBurned ?? 0;

    final mandatoryTasks = state.activePlan!.mandatoryDailyTasks;
    final personalGoals = dailyLog?.createdPersonalGoals ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [

          SliverToBoxAdapter(
            child: ActivityTrendChart(
              clientId: widget.client.id,
              stepGoal: stepGoal,
            ),
          ),

          // 1.5 Selected Date Indicator (Optional - just to show context)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "Showing details for: ${DateFormat.yMMMd().format(state.selectedDate)}",
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          // 1. Header & Dat

          // 2. Scoreboard
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  const Text("Daily Activity Score", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text("$score", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.black26,
                      valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(score >= 80 ? "Excellent work!" : "Keep moving to boost your score!", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),

          // 3. Movement Summary
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MovementDetailSheet.withSteps(
                    notifier: notifier,
                    activePlan: state.activePlan!,
                    dailyLog: dailyLog,
                    currentSteps: currentSteps,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.directions_walk, color: Colors.orange.shade700, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Movement", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text("$currentSteps", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(" / $stepGoal steps", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                            ],
                          ),
                          Text("$calories kcal burned", style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),

          // ... below the Movement Summary Sliver ...

// 3.5 Workout Logger
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => WorkoutEntryDialog(
                    onSave: (type, duration, cals) {
                      _logWorkout(dailyLog, cals, duration);
                    },
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Log Workout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text("Yoga, Gym, Cycling...", style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.add_circle, color: Colors.white, size: 28),
                  ],
                ),
              ),
            ),
          ),

          // 4. Mandatory Missions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
              child: Text("Daily Missions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final task = mandatoryTasks[index];
                  final isCompleted = dailyLog?.completedMandatoryTasks.contains(task) ?? false;
                  return _buildTaskCard(task, isCompleted, () => _toggleTask(dailyLog, task, false));
                },
                childCount: mandatoryTasks.length,
              ),
            ),
          ),

          // 5. Personal Goals (WITH DELETE BUTTON)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("My Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.teal),
                    onPressed: () => _showAddGoalDialog(context, dailyLog),
                  )
                ],
              ),
            ),
          ),

          if (personalGoals.isEmpty)
            const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No personal goals yet. Add one!", style: TextStyle(color: Colors.grey)),
              )),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final goal = personalGoals[index];
                    final isCompleted = dailyLog?.completedPersonalGoals.contains(goal) ?? false;

                    // 🎯 Swipe-to-delete AND Button-to-delete
                    return Dismissible(
                      key: Key(goal),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deletePersonalGoal(dailyLog, goal),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.shade100,
                        child: Icon(Icons.delete, color: Colors.red.shade700),
                      ),
                      child: _buildTaskCard(
                        goal,
                        isCompleted,
                            () => _toggleTask(dailyLog, goal, true),
                        isPersonal: true,
                        onDelete: () => _deletePersonalGoal(dailyLog, goal), // 🎯 Pass delete callback
                      ),
                    );
                  },
                  childCount: personalGoals.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // 🎯 WIDGET: Task Card with Optional Delete Button
  Widget _buildTaskCard(String title, bool isCompleted, VoidCallback onTap, {bool isPersonal = false, VoidCallback? onDelete}) {
    final color = isPersonal ? Colors.teal : Colors.deepPurple;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Adjusted padding
        decoration: BoxDecoration(
          color: isCompleted ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCompleted ? color.withOpacity(0.3) : Colors.grey.shade200,
              width: 1.5
          ),
          boxShadow: isCompleted ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Checkbox Icon
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? color : Colors.grey.shade300, width: 2),
                color: isCompleted ? color : Colors.transparent,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : const SizedBox(width: 14, height: 14),
            ),
            const SizedBox(width: 16),

            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? color.shade900 : Colors.black87,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: color.shade200,
                ),
              ),
            ),

            // 🎯 NEW: Delete Button (Only for Personal Goals)
            if (isPersonal && onDelete != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(), // Removes default padding
              ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, ClientLogModel? log) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Personal Goal"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. 10 min meditation"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _addPersonalGoal(log, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }
}