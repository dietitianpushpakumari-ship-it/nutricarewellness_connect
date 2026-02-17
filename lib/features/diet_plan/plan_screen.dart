import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/daily_vitals_card.dart';
import 'package:nutricare_connect/core/utils/diet_plan_viewer.dart';
import 'package:nutricare_connect/new/models/diet_plan_item_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 LOGGING SHEETS
import 'package:nutricare_connect/features/diet_plan/meal_detail_sheet.dart';
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

    // 🎨 THEME ACCESS
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.error != null) return Center(child: Text('Error: ${state.error}'));

    final activePlan = state.activePlan;
    if (activePlan == null) return const Center(child: Text('No active diet plan assigned.'));

    // 🎯 1. DETERMINE CORRECT DAY (Weekly vs Single)
    MasterDayPlanModel? dayPlan;
    if (activePlan.days.isNotEmpty) {
      if (activePlan.days.length > 1) {
        // Weekly: Match "Monday", "Tuesday" etc.
        final selectedDayName = DateFormat('EEEE').format(state.selectedDate);
        dayPlan = IterableExtension(activePlan.days).firstWhereOrNull(
                (d) => d.dayName.toLowerCase() == selectedDayName.toLowerCase()
        ) ?? activePlan.days.first;
      } else {
        // Single: Always use the first one
        dayPlan = activePlan.days.first;
      }
    }

    final dailyLogs = state.dailyLogs;
    final wellnessLog = IterableExtension(dailyLogs).firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 🎨 Dynamic Background
      body: CustomScrollView(
        slivers: [
          // 1. HEADER & DATE PICKER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Daily Plan", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)), // 🎨 Theme Color
                        Text(
                            dayPlan != null ? "${dayPlan.dayName} Schedule" : "Track meals & wellness",
                            style: TextStyle(fontSize: 14, color: theme.hintColor) // 🎨 Theme Color
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // PDF Button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50,
                              shape: BoxShape.circle
                          ),
                          child: Icon(Icons.picture_as_pdf, color: isDark ? Colors.redAccent : Colors.red.shade700, size: 20),
                        ),
                        tooltip: "View Full Plan",
                        onPressed: () {
                          if (activePlan == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DietPlanViewerScreen(
                                plan: activePlan,
                                client: client,
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
                          decoration: BoxDecoration(
                              color: theme.cardColor, // 🎨 Dynamic Card Color
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.dividerColor) // 🎨 Dynamic Border
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(DateFormat('MMM d').format(state.selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
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

          // 2. WELLNESS TRACKER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildWellnessRail(context, activePlan, wellnessLog, notifier),
            ),
          ),

          // 3. NUTRITION SECTION TITLE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu, size: 20, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text("Nutrition Timeline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                ],
              ),
            ),
          ),

          // 4. MEAL LIST (Optimized & Clean)
          if (dayPlan != null)
            _buildDailyMealList(context, dayPlan, dailyLogs, activePlan, notifier)
          else
            const SliverToBoxAdapter(child: Center(child: Text("Rest Day - No Meals Planned"))),

          // 5. HABITS CHECKLIST
          if (activePlan.mandatoryDailyTasks.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.check_box, size: 20, color: theme.hintColor),
                    const SizedBox(width: 8),
                    Text("Daily Habits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
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
    );
  }

  // --- 🎯 OPTIMIZED LIST BUILDER (NO ASYNC DEPENDENCY) ---
  Widget _buildDailyMealList(BuildContext context, MasterDayPlanModel dayPlan, List<ClientLogModel> dailyLogs, ClientDietPlanModel activePlan, DietPlanNotifier notifier) {
    // 1. Prepare List from Plan
    final meals = List<DietPlanMealModel>.from(dayPlan.meals);

    // 2. Sort by Plan's internal order (drag-and-drop from Admin)
    meals.sort((a, b) => a.order.compareTo(b.order));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final meal = meals[index];
            final log = IterableExtension(dailyLogs).firstWhereOrNull((l) => l.mealName == meal.mealName);
            return _buildMealTicket(context, meal, log, activePlan, notifier);
          },
          childCount: meals.length,
        ),
      ),
    );
  }

  // --- 🎯 WELLNESS RAIL ---
  Widget _buildWellnessRail(BuildContext context, ClientDietPlanModel plan, ClientLogModel? log, DietPlanNotifier notifier) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildTrackerCard(context, "Hydration", "${log?.hydrationLiters ?? 0} / ${plan.dailyWaterGoal} L", (log?.hydrationLiters ?? 0) / plan.dailyWaterGoal, Icons.water_drop, Colors.blue, () => _openSheet(context, HydrationDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, currentIntake: log?.hydrationLiters ?? 0))),
          const SizedBox(width: 12),
          _buildTrackerCard(context, "Movement", "${log?.stepCount ?? 0} / ${plan.dailyStepGoal}", (log?.stepCount ?? 0) / plan.dailyStepGoal, Icons.directions_run, Colors.orange, () => _openSheet(context, MovementDetailSheet.withSteps(notifier: notifier, activePlan: plan, dailyLog: log, currentSteps: log?.stepCount ?? 0))),
          const SizedBox(width: 12),
          _buildTrackerCard(context, "Sleep", "${log?.totalSleepDurationHours ?? 0} / ${plan.dailySleepGoal} h", (log?.totalSleepDurationHours ?? 0) / plan.dailySleepGoal, Icons.bedtime, Colors.indigo, () => _openSheet(context, SleepDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log))),
          const SizedBox(width: 12),
          _buildTrackerCard(context, "Mind", "${log?.breathingMinutes ?? 0} / ${plan.dailyMindfulnessMinutes} m", (log?.breathingMinutes ?? 0) / plan.dailyMindfulnessMinutes, Icons.self_improvement, Colors.teal, () => _openSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: BreathingConfig.box))),
          const SizedBox(width: 10),
          DailyVitalsCard(dailyLog: log, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogVitalsScreen(notifier: notifier, activePlan: plan, dailyLog: log)))),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildTrackerCard(BuildContext context, String title, String value, double progress, IconData icon, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: theme.cardColor, // 🎨 Dynamic Card
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4)
              )
            ],
            border: Border.all(color: progress >= 1.0 ? color.withOpacity(0.3) : Colors.transparent)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 20), if(progress >= 1.0) Icon(Icons.check_circle, color: color, size: 16)]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)), // 🎨 Theme Text
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)) // 🎨 Theme Text
            ]),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 4, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color))),
          ],
        ),
      ),
    );
  }

  // --- HABIT TILE ---
  Widget _buildHabitTile(String task, bool isDone, DietPlanNotifier notifier, ClientLogModel? log, ClientDietPlanModel plan) {
    return Builder( // Use Builder to get context with Theme
        builder: (context) {
          final theme = Theme.of(context);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: isDone ? Colors.green.withOpacity(0.1) : theme.cardColor, // 🎨 Dynamic Background
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDone ? Colors.green.withOpacity(0.3) : theme.dividerColor)
            ),
            child: CheckboxListTile(
              title: Text(task, style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.green : theme.colorScheme.onSurface // 🎨 Dynamic Text
              )),
              value: isDone,
              activeColor: Colors.green,
              onChanged: (val) async {
                final list = List<String>.from(log?.completedMandatoryTasks ?? []);
                if(val == true) list.add(task); else list.remove(task);
                final baseLog = log ?? ClientLogModel(id: '', clientId: plan.clientId, dietPlanId: plan.id, mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: DateTime.now());
                await notifier.createOrUpdateLog(log: baseLog.copyWith(completedMandatoryTasks: list), mealPhotoFiles: []);
              },
              secondary: Icon(isDone ? Icons.task_alt : Icons.radio_button_unchecked, color: isDone ? Colors.green : theme.hintColor),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
        }
    );
  }

  // --- 🎯 MEAL TICKET (Supports Theme + Alternatives + Direct Data) ---
  Widget _buildMealTicket(BuildContext context, DietPlanMealModel meal, ClientLogModel? log, ClientDietPlanModel activePlan, DietPlanNotifier notifier) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isLogged = log != null;
    final isSkipped = log?.logStatus == LogStatus.skipped;
    Color statusColor = isLogged ? (isSkipped ? Colors.orange : Colors.green) : theme.disabledColor;

    // 🎯 USE PLAN DATA DIRECTLY
    final timeString = meal.time ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor, // 🎨 Dynamic Card
        borderRadius: BorderRadius.circular(20),
        border: isLogged ? Border.all(color: statusColor.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isLogged ? statusColor.withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3), // 🎨 Dynamic Header
              child: Row(
                children: [
                  Icon(Icons.restaurant, size: 18, color: isLogged ? statusColor : theme.iconTheme.color?.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meal.mealName, style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isLogged ? statusColor : theme.colorScheme.onSurface // 🎨 Theme Text
                        )),
                        if (timeString.isNotEmpty)
                          Text(timeString, style: TextStyle(
                              fontSize: 11,
                              color: isLogged ? statusColor.withOpacity(0.8) : theme.hintColor, // 🎨 Theme Text
                              fontWeight: FontWeight.w500
                          )),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _openSheet(context, MealDetailSheet(notifier: notifier, mealName: meal.mealName, activePlan: activePlan, logToEdit: log, plannedItems: meal.items)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLogged ? theme.cardColor : theme.colorScheme.primary, // 🎨 Dynamic Button
                      foregroundColor: isLogged ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 32),
                      side: isLogged ? BorderSide(color: theme.dividerColor) : null,
                    ),
                    child: Text(isLogged ? "Edit" : "Log"),
                  ),
                ],
              ),
            ),

            // 🎯 FOOD ITEMS & ALTERNATIVES LIST
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: meal.items.map((item) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. MAIN FOOD ITEM
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 8, color: theme.colorScheme.primary), // 🎨 Theme Bullet
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${item.foodItemName} (${item.quantity} ${item.unit})",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface // 🎨 Theme Text
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 2. ALTERNATIVES LIST
                      if (item.alternatives.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: item.alternatives.map((alt) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text("OR", style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "${alt.foodItemName} (${alt.quantity} ${alt.unit})",
                                      style: TextStyle(fontSize: 13, color: theme.hintColor), // 🎨 Theme Text
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
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