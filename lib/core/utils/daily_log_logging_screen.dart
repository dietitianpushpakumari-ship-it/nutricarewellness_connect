import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:collection/collection.dart';

// Detail Sheets
import 'package:nutricare_connect/core/utils/hydration_detail_screen.dart';
import 'package:nutricare_connect/core/utils/movement_Details_sheet.dart';
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';

class DailyGoalsLoggingScreen extends ConsumerStatefulWidget {
  final String clientId;
  const DailyGoalsLoggingScreen({super.key, required this.clientId});

  @override
  ConsumerState<DailyGoalsLoggingScreen> createState() => _DailyGoalsLoggingScreenState();
}

class _DailyGoalsLoggingScreenState extends ConsumerState<DailyGoalsLoggingScreen> {
  // 🎯 FIX 1: Persistent ScrollController
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);

    // 🎯 FIX 2: Only block UI if data is completely missing.
    // If data exists but we are just saving, don't show the full screen loader.
    if (state.isLoading && state.activePlan == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ClientDietPlanModel? plan = state.activePlan;
    if (plan == null) return const Scaffold(body: Center(child: Text("No active plan found.")));

    final ClientLogModel? dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    // --- DATA PREP ---
    // Targets
    final double waterGoal = plan.dailyWaterGoal;
    final int stepGoal = plan.dailyStepGoal;
    final double sleepGoal = plan.dailySleepGoal;
    final int mindGoal = plan.dailyMindfulnessMinutes;

    // Actuals
    final double waterCur = dailyLog?.hydrationLiters ?? 0;
    final int stepsCur = dailyLog?.stepCount ?? 0;
    final double sleepCur = dailyLog?.totalSleepDurationHours ?? 0;
    final int mindCur = dailyLog?.breathingMinutes ?? 0;

    // Habits
    final List<String> habits = plan.mandatoryDailyTasks;
    final List<String> completedHabits = dailyLog?.completedMandatoryTasks ?? [];

    // Progress
    int totalItems = 4 + habits.length;
    int completedItems = (waterCur >= waterGoal ? 1 : 0) +
        (stepsCur >= stepGoal ? 1 : 0) +
        (sleepCur >= sleepGoal ? 1 : 0) +
        (mindCur >= mindGoal ? 1 : 0) +
        completedHabits.length;

    double progress = totalItems > 0 ? completedItems / totalItems : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Daily Targets", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(DateFormat.yMMMd().format(state.selectedDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // 🎯 FIX 3: Non-intrusive loading indicator in AppBar
        bottom: state.isLoading
            ? const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: LinearProgressIndicator(color: Colors.teal, minHeight: 3),
        )
            : null,
      ),
      body: ListView(
        controller: _scrollController, // 🎯 FIX 4: Attach controller
        padding: const EdgeInsets.all(16),
        children: [
          // PROGRESS HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.teal.shade600, Colors.teal.shade400]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: progress, color: Colors.white, backgroundColor: Colors.white24, strokeWidth: 8),
                    Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Daily Consistency", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("$completedItems of $totalItems goals met", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. CORE METRICS
          const Text("Performance Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildMetricTile(
            context, "Hydration", Icons.water_drop, Colors.blue,
            "${waterCur.toStringAsFixed(1)} / ${waterGoal.toStringAsFixed(1)} L", waterCur >= waterGoal,
                () => _openSheet(context, HydrationDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyLog, currentIntake: waterCur)),
          ),
          _buildMetricTile(
            context, "Movement", Icons.directions_run, Colors.orange,
            "$stepsCur / $stepGoal Steps", stepsCur >= stepGoal,
                () => _openSheet(context, MovementDetailSheet.withSteps(notifier: notifier, activePlan: plan, dailyLog: dailyLog, currentSteps: stepsCur)),
          ),
          _buildMetricTile(
            context, "Sleep", Icons.bedtime, Colors.indigo,
            "${sleepCur.toStringAsFixed(1)} / ${sleepGoal.toStringAsFixed(1)} Hrs", sleepCur >= sleepGoal,
                () => _openSheet(context, SleepDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyLog)),
          ),
          _buildMetricTile(
            context, "Mindfulness", Icons.self_improvement, Colors.teal,
            "$mindCur / $mindGoal Mins", mindCur >= mindGoal,
                () => _openSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyLog, config: BreathingConfig.box)),
          ),

          const SizedBox(height: 24),

          // 2. HABITS CHECKLIST
          if (habits.isNotEmpty) ...[
            const Text("Daily Rituals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...habits.map((task) {
              final isDone = completedHabits.contains(task);

              return Card(
                elevation: 0,
                key: ValueKey(task), // 🎯 FIX 5: Stable Keys
                color: isDone ? Colors.green.shade50 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDone ? Colors.green : Colors.grey.shade300)),
                child: CheckboxListTile(
                  title: Text(task, style: TextStyle(fontWeight: FontWeight.w600, decoration: isDone ? TextDecoration.lineThrough : null)),
                  value: isDone,
                  activeColor: Colors.green,
                  onChanged: (val) async {
                    // Update Logic
                    final list = List<String>.from(dailyLog?.completedMandatoryTasks ?? []);
                    if (val == true) list.add(task);
                    else list.remove(task);

                    final baseLog = dailyLog ?? ClientLogModel(
                        id: '', clientId: widget.clientId, dietPlanId: plan.id,
                        mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'],
                        date: DateTime.now()
                    );

                    // Save without blocking UI flow
                    await notifier.createOrUpdateLog(log: baseLog.copyWith(completedMandatoryTasks: list), mealPhotoFiles: []);
                  },
                  secondary: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
                ),
              );
            }).toList(),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, String title, IconData icon, Color color, String status, bool isMet, VoidCallback onTap) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(status, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        trailing: Icon(isMet ? Icons.check_circle : Icons.arrow_forward_ios, color: isMet ? Colors.green : Colors.grey, size: isMet ? 24 : 16),
      ),
    );
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }
}