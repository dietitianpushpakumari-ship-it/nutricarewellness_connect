import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:nutricare_connect/core/utils/daily_vitals_card.dart';
import 'package:nutricare_connect/core/utils/diet_pdf_service.dart';
import 'package:nutricare_connect/core/utils/diet_plan_viewer.dart';
import 'package:nutricare_connect/core/utils/master_data_provider.dart';
import 'package:nutricare_connect/core/utils/meal_master_name.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:printing/printing.dart';


// 🎯 LOGGING SHEETS
import 'package:nutricare_connect/core/utils/meal_detail_sheet.dart';
import 'package:nutricare_connect/core/utils/hydration_detail_screen.dart';
import 'package:nutricare_connect/core/utils/movement_Details_sheet.dart';
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';

class PlanScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);
    final masterMealsAsync = ref.watch(masterMealNamesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.error != null) return Center(child: Text('Error: ${state.error}'));

    final activePlan = state.activePlan;
    if (activePlan == null) return const Center(child: Text('No active diet plan assigned.'));

    final dayPlan = activePlan.days.isNotEmpty ? activePlan.days.first : null;
    final dailyLogs = state.dailyLogs;
    final wellnessLog = dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: CustomScrollView(
          slivers: [
            // 1. HEADER & DATE PICKER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Daily Plan", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                          Text("Track meals & wellness", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // PDF Button
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                            child: Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 20),
                          ),
                          tooltip: "View Full Plan",
                          onPressed: () {
                            if (activePlan == null) return;

                            // 🎯 Navigate to Viewer instead of direct share
                            // In PlanScreen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DietPlanViewerScreen(
                                  plan: activePlan,
                                  client: client, // 🎯 Pass client
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // Date Picker
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: state.selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) notifier.selectDate(picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(DateFormat('MMM d').format(state.selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            // 🎯 2. WELLNESS TRACKER (Horizontal Rail)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildWellnessRail(context, activePlan, wellnessLog, notifier),
              ),
            ),

            // 🎯 3. NUTRITION SECTION TITLE
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu, size: 20, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text("Nutrition Timeline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  ],
                ),
              ),
            ),

            // 4. MEAL LIST
            if (dayPlan != null)
              masterMealsAsync.when(
                loading: () => const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
                data: (masterMeals) {
                  final sortedMealData = dayPlan.meals.map((meal) {
                    final config = masterMeals.firstWhereOrNull((m) => m.id == meal.mealNameId || m.enName == meal.mealName);
                    return (meal: meal, config: config);
                  }).toList();

                  sortedMealData.sort((a, b) {
                    final orderA = a.config?.order ?? a.meal.order;
                    final orderB = b.config?.order ?? b.meal.order;
                    return orderA.compareTo(orderB);
                  });

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final data = sortedMealData[index];
                          final log = dailyLogs.firstWhereOrNull((l) => l.mealName == data.meal.mealName);
                          return _buildMealTicket(context, data.meal, log, activePlan, notifier, data.config);
                        },
                        childCount: sortedMealData.length,
                      ),
                    ),
                  );
                },
              )
            else
              const SliverToBoxAdapter(child: Center(child: Text("Rest Day - No Meals Planned"))),

            // 🎯 5. HABITS CHECKLIST
            if (activePlan.mandatoryDailyTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                  child: Row(
                    children: [
                      Icon(Icons.check_box, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text("Daily Habits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final task = activePlan.mandatoryDailyTasks[index];
                      final isDone = wellnessLog?.completedMandatoryTasks.contains(task) ?? false;
                      return _buildHabitTile(task, isDone, notifier, wellnessLog, activePlan);
                    },
                    childCount: activePlan.mandatoryDailyTasks.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // --- 🎯 NEW: WELLNESS TRACKER RAIL ---
  Widget _buildWellnessRail(BuildContext context, ClientDietPlanModel plan, ClientLogModel? log, DietPlanNotifier notifier) {
    return SizedBox(
      height: 110, // Compact height
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildTrackerCard(
              context,
              "Hydration",
              "${log?.hydrationLiters ?? 0} / ${plan.dailyWaterGoal} L",
              (log?.hydrationLiters ?? 0) / plan.dailyWaterGoal,
              Icons.water_drop, Colors.blue,
                  () => _openSheet(context, HydrationDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, currentIntake: log?.hydrationLiters ?? 0))
          ),
          const SizedBox(width: 12),
          _buildTrackerCard(
              context,
              "Movement",
              "${log?.stepCount ?? 0} / ${plan.dailyStepGoal}",
              (log?.stepCount ?? 0) / plan.dailyStepGoal,
              Icons.directions_run, Colors.orange,
                  () => _openSheet(context, MovementDetailSheet.withSteps(notifier: notifier, activePlan: plan, dailyLog: log, currentSteps: log?.stepCount ?? 0))
          ),
          const SizedBox(width: 12),
          _buildTrackerCard(
              context,
              "Sleep",
              "${log?.totalSleepDurationHours ?? 0} / ${plan.dailySleepGoal} h",
              (log?.totalSleepDurationHours ?? 0) / plan.dailySleepGoal,
              Icons.bedtime, Colors.indigo,
                  () => _openSheet(context, SleepDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log))
          ),
          const SizedBox(width: 12),
          _buildTrackerCard(
              context,
              "Mind",
              "${log?.breathingMinutes ?? 0} / ${plan.dailyMindfulnessMinutes} m",
              (log?.breathingMinutes ?? 0) / plan.dailyMindfulnessMinutes,
              Icons.self_improvement, Colors.teal,
                  () => _openSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: BreathingConfig.box))
          ),

          const SizedBox(width: 10),
          // 1. INSERT THE VITALS CARD HERE
          DailyVitalsCard(
            dailyLog: log,
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LogVitalsScreen(
                          notifier: notifier,
                          activePlan: plan,
                          dailyLog: log
                      )
                  )
              );
            },
          ),

          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildTrackerCard(BuildContext context, String title, String value, double progress, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
          border: Border.all(color: progress >= 1.0 ? color.withOpacity(0.3) : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                if(progress >= 1.0) Icon(Icons.check_circle, color: color, size: 16),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- HABIT TILE ---
  Widget _buildHabitTile(String task, bool isDone, DietPlanNotifier notifier, ClientLogModel? log, ClientDietPlanModel plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: CheckboxListTile(
        title: Text(task, style: TextStyle(fontWeight: FontWeight.w600, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.green.shade900 : Colors.black87)),
        value: isDone,
        activeColor: Colors.green,
        onChanged: (val) async {
          final list = List<String>.from(log?.completedMandatoryTasks ?? []);
          if(val == true) list.add(task); else list.remove(task);

          final baseLog = log ?? ClientLogModel(id: '', clientId: plan.clientId, dietPlanId: plan.id, mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: DateTime.now());
          await notifier.createOrUpdateLog(log: baseLog.copyWith(completedMandatoryTasks: list), mealPhotoFiles: []);
        },
        secondary: Icon(isDone ? Icons.task_alt : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  // --- MEAL TICKET (Kept Consistent) ---
  Widget _buildMealTicket(BuildContext context, DietPlanMealModel meal, ClientLogModel? log, ClientDietPlanModel activePlan, DietPlanNotifier notifier, MasterMealName? config) {
    final isLogged = log != null;
    final isSkipped = log?.logStatus == LogStatus.skipped;
    Color statusColor = isLogged ? (isSkipped ? Colors.orange : Colors.green) : Colors.grey;

    String timeString = "";
    if (config?.startTime != null) {
      timeString = config!.startTime!;
      if (config.endTime != null) timeString += " - ${config.endTime}";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLogged ? Border.all(color: statusColor.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isLogged ? statusColor.withOpacity(0.1) : Colors.grey.shade50,
              child: Row(
                children: [
                  Icon(Icons.restaurant, size: 18, color: isLogged ? statusColor : Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meal.mealName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLogged ? statusColor.withOpacity(0.8) : Colors.black87)),
                        if (timeString.isNotEmpty)
                          Text(timeString, style: TextStyle(fontSize: 11, color: isLogged ? statusColor.withOpacity(0.6) : Colors.grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _openSheet(context, MealDetailSheet(notifier: notifier, mealName: meal.mealName, activePlan: activePlan, logToEdit: log, plannedItems: meal.items)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLogged ? Colors.white : Theme.of(context).colorScheme.primary,
                      foregroundColor: isLogged ? Colors.black87 : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 32),
                      side: isLogged ? BorderSide(color: Colors.grey.shade300) : null,
                    ),
                    child: Text(isLogged ? "Edit" : "Log"),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: meal.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 6, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text("${item.foodItemName} (${item.quantity} ${item.unit})", style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }
}