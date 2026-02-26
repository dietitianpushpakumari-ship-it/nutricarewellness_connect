import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/daily_vitals_card.dart';
import 'package:nutricare_connect/new/dietplan/diet_plan_viewer.dart';
import 'package:nutricare_connect/new/models/diet_plan_item_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 LOGGING SHEETS
import 'package:nutricare_connect/new/dietplan/meal_detail_sheet.dart';
import 'package:nutricare_connect/new/dietplan/hydration_detail_screen.dart';
import 'package:nutricare_connect/new/dietplan/movement_Details_sheet.dart';
import 'package:nutricare_connect/new/dietplan/sleep_details_screen.dart';
import 'package:nutricare_connect/new/wellnesshub/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';

class PlanScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dietPlanNotifierProvider(client.id));
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    // 🎨 THEME ACCESS
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.error != null) return Center(child: Text('Error: ${state.error}'));

    final activePlan = state.activePlan;
    if (activePlan == null) return const Center(child: Text('No active diet plan assigned.'));
    final vitals = state.clinicalVitals;
    final guidelines = vitals?.clinicalGuidelines ?? {};

    // 🎯 1. DETERMINE CORRECT DAY (Weekly vs Single)
    MasterDayPlanModel? dayPlan;
    if (activePlan.days.isNotEmpty) {
      if (activePlan.days.length > 1) {
        // Weekly: Match "Monday", "Tuesday" etc.
        final selectedDayName = DateFormat('EEEE').format(state.selectedDate);
        dayPlan = IterableExtensions(activePlan.days).firstWhereOrNull(
                (d) => d.dayName.toLowerCase() == selectedDayName.toLowerCase()
        ) ?? activePlan.days.first;
      } else {
        // Single: Always use the first one
        dayPlan = activePlan.days.first;
      }
    }

    // 🎯 2. THE SINGLE SOURCE OF TRUTH
    final dailyRecord = state.dailyRecord;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                        Text("Daily Plan", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                        Text(
                            dayPlan != null ? "${dayPlan.dayName} Schedule" : "Track meals & wellness",
                            style: TextStyle(fontSize: 14, color: theme.hintColor)
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
                                vitals: state.clinicalVitals,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Date Picker (Themed to prevent transparency bugs)
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: state.selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  dialogTheme: DialogThemeData(
                                    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                  datePickerTheme: DatePickerThemeData(
                                    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                    headerBackgroundColor: colorScheme.primary,
                                    headerForegroundColor: colorScheme.onPrimary,
                                    dayStyle: const TextStyle(fontWeight: FontWeight.bold),
                                    surfaceTintColor: Colors.transparent,
                                  ),
                                  colorScheme: colorScheme.copyWith(
                                    surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                    onSurface: isDark ? Colors.white : Colors.black,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) notifier.selectDate(picked);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.dividerColor)
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

          // 2. WELLNESS TRACKER (Passes Master Record directly)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildWellnessRail(context, activePlan, dailyRecord, notifier),
            ),
          ),

          // 2.5 CLINICAL GUIDELINES SECTION
          if (guidelines.isNotEmpty)
          // 3. NUTRITION SECTION TITLE & COMPACT GUIDELINES BUTTON
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu, size: 20, color: theme.hintColor),
                    const SizedBox(width: 8),
                    Text("Nutrition Timeline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),

                    const Spacer(), // Pushes the button to the far right

                    // 🎯 ULTRA COMPACT GUIDELINES BUTTON
                    if (guidelines.isNotEmpty)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        side: BorderSide.none,
                        avatar: Icon(Icons.info_outline, size: 14, color: colorScheme.primary),
                        label: Text("Guidelines", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                        onPressed: () => _showGuidelinesSheet(context, guidelines, theme),
                      ),
                  ],
                ),
              ),
            ),


          // 4. MEAL LIST (Optimized & Clean)
          // 4. MEAL LIST (Optimized, Animated & Time-Aware)
          if (dayPlan != null)
          // 🎯 Added state.selectedDate as the 6th argument here!
            _buildDailyMealList(context, dayPlan, dailyRecord, activePlan, notifier, state.selectedDate)
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
                    final isDone = dailyRecord?.completedMandatoryTasks.contains(task) ?? false;
                    return _buildHabitTile(task, isDone, notifier, dailyRecord, activePlan);
                  },
                  childCount: activePlan.mandatoryDailyTasks.length,
                ),
              ),
            ),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
        ],
      ),
    );
  }

  // --- 🎯 OPTIMIZED LIST BUILDER ---
  // --- 🎯 OPTIMIZED LIST BUILDER ---
  // --- 🎯 OPTIMIZED LIST BUILDER ---
  Widget _buildDailyMealList(BuildContext context, MasterDayPlanModel dayPlan, ClientLogModel? dailyRecord, ClientDietPlanModel activePlan, DietPlanNotifier notifier, DateTime selectedDate) {
    final meals = List<DietPlanMealModel>.from(dayPlan.meals);

    // 🎯 SAFE SORT: Prevents crash if 'order' is accidentally stored as a String in the database
    meals.sort((a, b) => _safeInt(a.order).compareTo(_safeInt(b.order)));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final meal = meals[index];
            final MealEntry? mealLog = dailyRecord?.mealLogs[meal.mealName];

            return _buildMealTicket(context, meal, mealLog, dailyRecord, activePlan, notifier, index, selectedDate);
          },
          childCount: meals.length,
        ),
      ),
    );
  }
// 🛡️ SAFE PARSING HELPERS: Prevents crashes if Firebase returns a String instead of an int/double
  double _safeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  int _safeInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  Widget _buildWellnessRail(BuildContext context, ClientDietPlanModel plan, ClientLogModel? log, DietPlanNotifier notifier) {

    // 🎯 SANITIZE ALL DATA BEFORE RENDERING
    final waterGoal = _safeDouble(plan.dailyWaterGoal);
    final waterCurrent = _safeDouble(log?.hydrationLiters);

    final stepGoal = _safeInt(plan.dailyStepGoal);
    final stepCurrent = _safeInt(log?.stepCount);

    final sleepGoal = _safeDouble(plan.dailySleepGoal);
    final sleepCurrent = _safeDouble(log?.totalSleepDurationHours);

    final mindGoal = _safeInt(plan.dailyMindfulnessMinutes);
    final mindCurrent = _safeInt(log?.breathingMinutes);

    final fbsCurrent = _safeDouble(log?.fbsMgDl);
    final bpCurrent = _safeDouble(log?.bloodPressureSystolic);

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 💧 1. Hydration (Liquid Wave)
          _buildStandardRailingShell(
            context: context, index: 0,
            onTap: () => _openSheet(context, HydrationDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, currentIntake: waterCurrent)),
            child: AnimatedLiquidWave(
              progress: waterGoal > 0 ? (waterCurrent / waterGoal) : 0,
              title: "Hydration",
              subtitle: "${waterCurrent.toStringAsFixed(1)} / $waterGoal L",
              icon: Icons.water_drop_rounded,
            ),
          ),

          // 🏃 2. Movement (Jogging Bob)
          _buildStandardRailingShell(
            context: context, index: 1,
            onTap: () => _openSheet(context, MovementDetailSheet.withSteps(notifier: notifier, activePlan: plan, dailyLog: log, currentSteps: stepCurrent)),
            child: AnimatedMovementContent(
              progress: stepGoal > 0 ? (stepCurrent / stepGoal) : 0,
              title: "Movement",
              subtitle: "$stepCurrent / $stepGoal",
            ),
          ),

          // 🌙 3. Sleep (Deep Glow)
          _buildStandardRailingShell(
            context: context, index: 2,
            onTap: () => _openSheet(context, SleepDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log)),
            child: AnimatedSleepContent(
              progress: sleepGoal > 0 ? (sleepCurrent / sleepGoal) : 0,
              title: "Sleep",
              subtitle: "${sleepCurrent.toStringAsFixed(1)} / $sleepGoal h",
            ),
          ),

          // 🧘 4. Mind (Zen Ripples)
          _buildStandardRailingShell(
            context: context, index: 3,
            onTap: () => _openSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: BreathingConfig.box)),
            child: AnimatedMindContent(
              progress: mindGoal > 0 ? (mindCurrent / mindGoal) : 0,
              title: "Mindfulness",
              subtitle: "$mindCurrent / $mindGoal m",
            ),
          ),

          // 📊 5. Vitals (Pulsing Check)
          _buildStandardRailingShell(
            context: context, index: 4,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogVitalsScreen(notifier: notifier, activePlan: plan, dailyLog: log))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, val, _) => Transform.scale(scale: val, child: const Icon(Icons.monitor_heart_rounded, color: Colors.redAccent, size: 20)),
                    ),
                    if (fbsCurrent > 0 || bpCurrent > 0)
                      const Icon(Icons.check_circle, color: Colors.redAccent, size: 16),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Vitals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                        fbsCurrent > 0 ? "${fbsCurrent.toStringAsFixed(0)} mg/dL" : "Not logged",
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis
                    ),
                  ],
                ),
                _buildSmoothProgressBar(fbsCurrent > 0 ? 1.0 : 0.0, Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  } // --- 💧 NEW: Custom Liquid Animation for Hydration ---
  Widget _buildHydrationContent(BuildContext context, double current, double goal) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final theme = Theme.of(context);

    return Stack(
      children: [
        // 🌊 Liquid Wave Fill
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOutSine,
            tween: Tween<double>(begin: 0.0, end: progress),
            builder: (context, value, _) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: value, // Dynamically fills the container height
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4), // Keeps it inside the card curves slightly
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blue.withOpacity(0.3),
                          Colors.blue.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Content on top of liquid
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.water_drop_rounded, color: Colors.blue, size: 20),
                if (progress >= 1.0) const Icon(Icons.check_circle, color: Colors.blue, size: 16),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hydration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text("${current.toStringAsFixed(1)} / $goal L", style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // --- 🎯 UPDATED TRACKER CARD (With Animated Bars) ---
  Widget _buildTrackerCard(BuildContext context, String title, String value, double progress, IconData icon, Color color, int index, VoidCallback onTap) {
    final theme = Theme.of(context);

    return _buildStandardRailingShell(
      context: context,
      index: index, // Passes index to stagger entrance
      onTap: onTap,
      progress: progress,
      progressColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              if (progress >= 1.0) Icon(Icons.check_circle, color: color, size: 16)
            ],
          ),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500))
              ]
          ),
          // 🎯 Smooth Animated Progress Bar
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
            builder: (context, val, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 4,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🎯 UPDATED SHELL (With Staggered Entrance Animation) ---
  Widget _buildStandardRailingShell({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
    required int index, // Determines delay
    double? progress,
    Color? progressColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 🎯 Staggered Entrance Animation
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 150)), // Staggered delay
      curve: Curves.easeOutBack, // Gives a slight organic bounce at the end
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, animatedChild) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: animatedChild,
          ),
        );
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (progress != null && progress >= 1.0)
                  ? (progressColor?.withOpacity(0.3) ?? theme.dividerColor.withOpacity(0.1))
                  : theme.dividerColor.withOpacity(0.1)
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        // Adding Material & InkWell inside the shell makes it cleanly tappable
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: (progressColor ?? theme.colorScheme.primary).withOpacity(0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
  // --- HABIT TILE (ATOMIC UPDATE APPLIED) ---
  Widget _buildHabitTile(String task, bool isDone, DietPlanNotifier notifier, ClientLogModel? dailyRecord, ClientDietPlanModel plan) {
    return Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: isDone ? Colors.green.withOpacity(0.1) : theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDone ? Colors.green.withOpacity(0.3) : theme.dividerColor)
            ),
            child: CheckboxListTile(
              title: Text(task, style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.green : theme.colorScheme.onSurface
              )),
              value: isDone,
              activeColor: Colors.green,
              onChanged: (val) async {
                final list = List<String>.from(dailyRecord?.completedMandatoryTasks ?? []);
                if(val == true) list.add(task); else list.remove(task);

                // 🎯 ATOMIC UPDATE
                await notifier.updateDailyRecord(data: {
                  'completedMandatoryTasks': list
                });
              },
              secondary: Icon(isDone ? Icons.task_alt : Icons.radio_button_unchecked, color: isDone ? Colors.green : theme.hintColor),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
        }
    );
  }

  // --- ⏰ HELPER: Check if a meal is overdue ---
  bool _isMealOverdue(String? timeStr, DateTime selectedDate) {
    if (timeStr == null || timeStr.isEmpty) return false;

    final now = DateTime.now();

    // 1. If looking at a past date, it's definitely overdue/missed
    if (selectedDate.year < now.year ||
        (selectedDate.year == now.year && selectedDate.month < now.month) ||
        (selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day < now.day)) {
      return true;
    }

    // 2. If looking at a future date, it's not overdue
    if (!DateUtils.isSameDay(selectedDate, now)) return false;

    // 3. It's today. Parse the time string (e.g., "08:30 AM" or "8:30 PM")
    try {
      final cleanStr = timeStr.trim().toUpperCase();
      final isPM = cleanStr.contains("PM");
      final timePart = cleanStr.replaceAll("AM", "").replaceAll("PM", "").trim();
      final parts = timePart.split(":");

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      final mealTime = DateTime(now.year, now.month, now.day, hour, minute);

      // Add a 30-minute grace period before officially calling it "Overdue"
      return now.isAfter(mealTime.add(const Duration(minutes: 30)));
    } catch (e) {
      return false; // If parsing fails, default to safe
    }
  }

  // --- 🎯 MEAL TICKET (Now expects MealEntry) ---
  // --- 🎯 ANIMATED MEAL TICKET ---
  // --- 🎯 ANIMATED & TIME-AWARE MEAL TICKET ---
  Widget _buildMealTicket(BuildContext context, DietPlanMealModel mealPlanInfo, MealEntry? mealLog, ClientLogModel? masterRecord, ClientDietPlanModel activePlan, DietPlanNotifier notifier, int index, DateTime selectedDate) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isLogged = mealLog != null;
    final isSkipped = mealLog?.status == LogStatus.skipped;
    final timeString = mealPlanInfo.time ?? "";

    // 🎯 Check if it's late!
    final isOverdue = !isLogged && _isMealOverdue(timeString, selectedDate);

    // 🎯 Determine the status color
    Color statusColor;
    if (isLogged) {
      statusColor = isSkipped ? Colors.orange : Colors.green;
    } else if (isOverdue) {
      statusColor = Colors.redAccent; // Highlights missed meals
    } else {
      statusColor = theme.disabledColor; // Normal unlogged state
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 150)),
      curve: Curves.easeOutQuart,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isLogged || isOverdue
                  ? statusColor.withOpacity(0.4) // Red border if overdue!
                  : theme.dividerColor.withOpacity(isDark ? 0.05 : 0.1),
              width: isOverdue && !isLogged ? 2.0 : 1.5 // Slightly thicker border if overdue
          ),
          boxShadow: [
            BoxShadow(
                color: isLogged || isOverdue
                    ? statusColor.withOpacity(0.05)
                    : Colors.black.withOpacity(isDark ? 0.15 : 0.04),
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: isLogged || isOverdue
                        ? statusColor.withOpacity(0.1) // Red tinted background if overdue!
                        : (isDark ? Colors.white.withOpacity(0.03) : colorScheme.surfaceContainerHighest.withOpacity(0.3)),
                    border: Border(
                        bottom: BorderSide(
                            color: isLogged || isOverdue
                                ? statusColor.withOpacity(0.15)
                                : theme.dividerColor.withOpacity(0.05)
                        )
                    )
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: RotationTransition(turns: Tween<double>(begin: 0.8, end: 1.0).animate(animation), child: child),
                      ),
                      // 🎯 Icon turns to an alarm clock if overdue!
                      child: Icon(
                        isLogged
                            ? (isSkipped ? Icons.next_plan_rounded : Icons.check_circle_rounded)
                            : (isOverdue ? Icons.alarm_off_rounded : Icons.restaurant_rounded),
                        key: ValueKey("$isLogged-$isOverdue"),
                        size: 20,
                        color: isLogged || isOverdue ? statusColor : theme.hintColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isLogged || isOverdue ? statusColor : colorScheme.onSurface,
                              decoration: isSkipped ? TextDecoration.lineThrough : null,
                            ),
                            child: Text(mealPlanInfo.mealName),
                          ),
                          if (timeString.isNotEmpty)
                          // 🎯 Show "Overdue" text if late!
                            Text(
                                isOverdue ? "Overdue (Scheduled: $timeString)" : timeString,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isOverdue ? statusColor : (isLogged ? statusColor.withOpacity(0.8) : theme.hintColor),
                                    fontWeight: isOverdue ? FontWeight.w800 : FontWeight.w600
                                )
                            ),
                        ],
                      ),
                    ),

                    // Button logic
                    ElevatedButton(
                      onPressed: () => _openSheet(
                          context,
                          MealDetailSheet(notifier: notifier, mealName: mealPlanInfo.mealName, activePlan: activePlan, logToEdit: mealLog, plannedItems: mealPlanInfo.items)
                      ),
                      style: ButtonStyle(
                        // If it's overdue, the button becomes Red to grab attention!
                        backgroundColor: WidgetStateProperty.resolveWith((states) => isLogged ? theme.cardColor : (isOverdue ? Colors.redAccent : colorScheme.primary)),
                        foregroundColor: WidgetStateProperty.resolveWith((states) => isLogged ? colorScheme.onSurface : Colors.white),
                        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
                        shadowColor: WidgetStatePropertyAll((isOverdue ? Colors.redAccent : colorScheme.primary).withOpacity(0.2)),
                        elevation: WidgetStatePropertyAll(isLogged ? 0 : 2),
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isLogged ? BorderSide(color: theme.dividerColor.withOpacity(0.2)) : BorderSide.none,
                          ),
                        ),
                      ),
                      child: Text(
                        isLogged ? "Edit" : "Log Now",
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // ... (Food Items List stays exactly the same as the previous response) ...

              // FOOD ITEMS LIST
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: mealPlanInfo.items.map((item) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              // Soften the bullet point if logged
                              child: Icon(Icons.circle, size: 6, color: isLogged ? statusColor.withOpacity(0.5) : colorScheme.primary.withOpacity(0.7)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${item.foodItemName} (${item.quantity} ${item.unit})",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface.withOpacity(isLogged ? 0.6 : 0.9), // Dims slightly when done
                                  decoration: isSkipped ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.alternatives.isNotEmpty && !isLogged) // Hide alternatives if already logged to save space
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: item.alternatives.map((alt) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text("OR", style: TextStyle(fontSize: 9, color: isDark ? Colors.orangeAccent : Colors.orange.shade800, fontWeight: FontWeight.w900)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text("${alt.foodItemName} (${alt.quantity} ${alt.unit})", style: TextStyle(fontSize: 13, color: theme.hintColor)),
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
      ),
    );
  }
  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(isDismissible: false,context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }

  // --- 🎯 CLINICAL GUIDELINES SECTION ---
  // --- 🎯 COMPACT CLINICAL GUIDELINES BUTTON ---
  Widget _buildGuidelinesSection(BuildContext context, Map<String, String> guidelines) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: InkWell(
        onTap: () => _showGuidelinesSheet(context, guidelines, theme),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.primaryContainer.withOpacity(0.1) : colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.health_and_safety_outlined, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Clinical Guidelines", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.primary)),
                    const SizedBox(height: 2),
                    Text("${guidelines.length} instructions from your dietitian", style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

// --- 🎯 SOLID & COMPACT GUIDELINES BOTTOM SHEET ---
  void _showGuidelinesSheet(BuildContext context, Map<String, String> guidelines, ThemeData theme) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent, // Required for the rounded corners to render
        builder: (context) {
          final colorScheme = theme.colorScheme;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              // 🎯 FIXED TRANSPARENCY: Forced a solid, opaque background color
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)], // Blocks background elements
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 10),
                      Text("Dietitian's Guidelines", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Scrollable List of Guidelines
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: guidelines.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Icon(Icons.check_circle, size: 18, color: colorScheme.primary.withOpacity(0.8)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      height: 1.5,
                                    ),
                                    children: [
                                      TextSpan(text: "${e.key}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: e.value),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          );
        }
    );
  }
}


// --- 🌊 NEW: Animated Liquid Wave Widget ---
class AnimatedLiquidWave extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;
  final IconData icon;

  const AnimatedLiquidWave({
    super.key,
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  State<AnimatedLiquidWave> createState() => _AnimatedLiquidWaveState();
}

class _AnimatedLiquidWaveState extends State<AnimatedLiquidWave> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    // Controls the continuous rippling speed
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // 🌊 Custom Painted Waves
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _LiquidWavePainter(
                    progress: widget.progress,
                    animationValue: _waveController.value,
                    // 🎯 Vibrant colors for the water
                    frontColor: Colors.blue.shade400.withOpacity(0.8),
                    backColor: Colors.lightBlueAccent.shade200.withOpacity(0.5),
                  ),
                );
              },
            ),
          ),
        ),

        // 📝 Overlay Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(widget.icon, color: widget.progress > 0.6 ? Colors.white : Colors.blue.shade600, size: 20),
                if (widget.progress >= 1.0)
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    // Dynamic text color based on water level
                    color: widget.progress > 0.4 ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.progress > 0.4 ? Colors.white.withOpacity(0.9) : theme.hintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// --- 🎨 The Math behind the Wave ---
class _LiquidWavePainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final Color frontColor;
  final Color backColor;

  _LiquidWavePainter({
    required this.progress,
    required this.animationValue,
    required this.frontColor,
    required this.backColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final waterHeight = size.height * (1 - progress.clamp(0.0, 1.0));
    final waveWidth = size.width;
    // Lower amplitude when almost empty or almost full so it doesn't spill out
    final amplitude = progress < 0.1 || progress > 0.9 ? 3.0 : 6.0;

    _drawWave(canvas, size, waterHeight, waveWidth, amplitude, animationValue, backColor);
    _drawWave(canvas, size, waterHeight, waveWidth, amplitude, animationValue + 0.5, frontColor); // Offset the front wave
  }

  void _drawWave(Canvas canvas, Size size, double waterHeight, double waveWidth, double amplitude, double phase, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, waterHeight);

    for (double x = 0; x <= size.width; x++) {
      // Sine wave formula: y = amplitude * sin(frequency * x + phase) + vertical_offset
      final y = waterHeight + math.sin((x / waveWidth * 2 * math.pi) + (phase * 2 * math.pi)) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.progress != progress;
  }
}

// --- 🏃‍♂️ MOVEMENT: Jogging Bob Animation ---
class AnimatedMovementContent extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;

  const AnimatedMovementContent({super.key, required this.progress, required this.title, required this.subtitle});

  @override
  State<AnimatedMovementContent> createState() => _AnimatedMovementContentState();
}

class _AnimatedMovementContentState extends State<AnimatedMovementContent> with SingleTickerProviderStateMixin {
  late AnimationController _runController;

  @override
  void initState() {
    super.initState();
    // Fast cycle for a running/jogging effect
    _runController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _runController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedBuilder(
              animation: _runController,
              builder: (context, child) {
                // Translates up and down slightly
                return Transform.translate(
                  offset: Offset(0, -3 * _runController.value),
                  child: const Icon(Icons.directions_run_rounded, color: Colors.orange, size: 22),
                );
              },
            ),
            if (widget.progress >= 1.0) const Icon(Icons.check_circle, color: Colors.orange, size: 16),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
            Text(widget.subtitle, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)),
          ],
        ),
        _buildSmoothProgressBar(widget.progress, Colors.orange),
      ],
    );
  }
}

// --- 🌙 SLEEP: Deep Breathing Glow ---
class AnimatedSleepContent extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;

  const AnimatedSleepContent({super.key, required this.progress, required this.title, required this.subtitle});

  @override
  State<AnimatedSleepContent> createState() => _AnimatedSleepContentState();
}

class _AnimatedSleepContentState extends State<AnimatedSleepContent> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    // Slow cycle for deep sleep breathing
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Icon(
                  Icons.bedtime_rounded,
                  color: Colors.indigo,
                  size: 20,
                  shadows: [
                    Shadow(
                      color: Colors.indigoAccent.withOpacity(0.8 * _glowController.value),
                      blurRadius: 15 * _glowController.value,
                    )
                  ],
                );
              },
            ),
            if (widget.progress >= 1.0) const Icon(Icons.check_circle, color: Colors.indigo, size: 16),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
            Text(widget.subtitle, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)),
          ],
        ),
        _buildSmoothProgressBar(widget.progress, Colors.indigo),
      ],
    );
  }
}

// --- 🧘 MIND: Zen Expanding Ripples ---
class AnimatedMindContent extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;

  const AnimatedMindContent({super.key, required this.progress, required this.title, required this.subtitle});

  @override
  State<AnimatedMindContent> createState() => _AnimatedMindContentState();
}

class _AnimatedMindContentState extends State<AnimatedMindContent> with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    // Medium cycle for a calming breath
    _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_rippleController.value * 1.5), // Expands outward
                      child: Opacity(
                        opacity: 1.0 - _rippleController.value, // Fades as it expands
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.teal.withOpacity(0.4)),
                        ),
                      ),
                    );
                  },
                ),
                const Icon(Icons.self_improvement_rounded, color: Colors.teal, size: 20),
              ],
            ),
            if (widget.progress >= 1.0) const Icon(Icons.check_circle, color: Colors.teal, size: 16),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
            Text(widget.subtitle, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)),
          ],
        ),
        _buildSmoothProgressBar(widget.progress, Colors.teal),
      ],
    );
  }
}

// Helper for the smooth progress bars shared by the 3 widgets above
Widget _buildSmoothProgressBar(double progress, Color color) {
  return TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 1000),
    curve: Curves.easeOutCubic,
    tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
    builder: (context, val, _) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: val,
        minHeight: 4,
        backgroundColor: color.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    ),
  );
}