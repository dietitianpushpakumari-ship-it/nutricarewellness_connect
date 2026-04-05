import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
 // Ensure this points to FlatClientDietPlanModel
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// Detail Sheets
import 'package:nutricare_connect/new/dietplan/hydration_detail_screen.dart';
import 'package:nutricare_connect/new/dietplan/movement_Details_sheet.dart';
import 'package:nutricare_connect/new/dietplan/sleep_details_screen.dart';
import 'package:nutricare_connect/new/wellnesshub/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';

class DailyGoalsLoggingScreen extends ConsumerStatefulWidget {
  final String clientId;
  const DailyGoalsLoggingScreen({super.key, required this.clientId});

  @override
  ConsumerState<DailyGoalsLoggingScreen> createState() => _DailyGoalsLoggingScreenState();
}

class _DailyGoalsLoggingScreenState extends ConsumerState<DailyGoalsLoggingScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);

    if (state.isLoading && state.activePlan == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 🚀 THE FIX: Strongly typed to Flat Model
    final FlatClientDietPlanModel? plan = state.activePlan;
    if (plan == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: Text("No active plan found.", style: TextStyle(color: colorScheme.onSurface))),
      );
    }

    // 🎯 ATOMIC FIX: Read directly from the Master Record
    final ClientLogModel? dailyRecord = state.dailyRecord;

    // Targets & Actuals
    final double waterGoal = plan.dailyWaterGoal;
    final int stepGoal = plan.dailyStepGoal;
    final double sleepGoal = plan.dailySleepGoal;
    final int mindGoal = plan.dailyMindfulnessMinutes;

    final double waterCur = dailyRecord?.hydrationLiters ?? 0;
    final int stepsCur = dailyRecord?.stepCount ?? 0;
    final double sleepCur = dailyRecord?.totalSleepDurationHours ?? 0;
    final int mindCur = dailyRecord?.breathingMinutes ?? 0;

    // 🚀 THE FIX: Changed mandatoryDailyTasks to assignedHabits
    final List<String> habits = plan.assignedHabits;
    final List<String> completedHabits = dailyRecord?.completedMandatoryTasks ?? [];

    int totalItems = 4 + habits.length;
    int completedItems = (waterCur >= waterGoal ? 1 : 0) +
        (stepsCur >= stepGoal ? 1 : 0) +
        (sleepCur >= sleepGoal ? 1 : 0) +
        (mindCur >= mindGoal ? 1 : 0) +
        completedHabits.length;

    double progress = totalItems > 0 ? completedItems / totalItems : 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Daily Targets", style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
            Text(DateFormat.yMMMd().format(state.selectedDate), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          // PROGRESS HEADER
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(isDark ? 0.15 : 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60, height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Overall Progress", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text("$completedItems of $totalItems goals met", style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text("Performance Goals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
          const SizedBox(height: 16),

          _buildMetricTile(
            context, "Hydration", Icons.water_drop_rounded, Colors.blue,
            "${waterCur.toStringAsFixed(1)} / ${waterGoal.toStringAsFixed(1)} L", waterCur >= waterGoal,
                () => _openSheet(context, HydrationDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyRecord, currentIntake: waterCur)),
          ),
          _buildMetricTile(
            context, "Movement", Icons.directions_run_rounded, Colors.orange,
            "$stepsCur / $stepGoal Steps", stepsCur >= stepGoal,
                () => _openSheet(context, MovementDetailSheet.withSteps(notifier: notifier, activePlan: plan, dailyLog: dailyRecord, currentSteps: stepsCur)),
          ),
          _buildMetricTile(
            context, "Sleep", Icons.bedtime_rounded, Colors.indigo,
            "${sleepCur.toStringAsFixed(1)} / ${sleepGoal.toStringAsFixed(1)} Hrs", sleepCur >= sleepGoal,
                () => _openSheet(context, SleepDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyRecord)),
          ),
          _buildMetricTile(
            context, "Mindfulness", Icons.self_improvement_rounded, Colors.teal,
            "$mindCur / $mindGoal Mins", mindCur >= mindGoal,
                () => _openSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyRecord, config: BreathingConfig.box)),
          ),

          const SizedBox(height: 32),

          // 2. HABITS CHECKLIST
          if (habits.isNotEmpty) ...[
            Text("Daily Rituals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            ...habits.map((task) {
              final isDone = completedHabits.contains(task);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: isDone ? colorScheme.primary.withOpacity(0.08) : (isDark ? theme.cardColor : Colors.white),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDone ? colorScheme.primary.withOpacity(0.4) : theme.dividerColor.withOpacity(0.05),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                ),
                child: CheckboxListTile(
                  key: ValueKey(task),
                  title: Text(
                    task,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDone ? colorScheme.primary : colorScheme.onSurface,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  value: isDone,
                  activeColor: colorScheme.primary,
                  checkColor: Colors.white,
                  onChanged: (val) async {
                    final list = List<String>.from(dailyRecord?.completedMandatoryTasks ?? []);
                    if (val == true) list.add(task);
                    else list.remove(task);

                    // 🎯 ATOMIC UPDATE: Only touch the habits list
                    await notifier.updateDailyRecord(
                        data: { 'completedMandatoryTasks': list }
                    );
                  },
                  secondary: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: isDone ? colorScheme.primary : theme.hintColor.withOpacity(0.5),
                    size: 28,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              );
            }).toList(),
          ],

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, String title, IconData icon, Color color, String status, bool isMet, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.onSurface, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: isMet ? colorScheme.primary.withOpacity(0.1) : theme.dividerColor.withOpacity(0.05),
              shape: BoxShape.circle
          ),
          child: Icon(
            isMet ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
            color: isMet ? colorScheme.primary : theme.hintColor.withOpacity(0.5),
            size: isMet ? 20 : 14,
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }
}