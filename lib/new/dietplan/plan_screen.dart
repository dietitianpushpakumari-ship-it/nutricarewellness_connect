import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 Required for HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/daily_vitals_card.dart';
import 'package:nutricare_connect/elite_meal_card.dart';
import 'package:nutricare_connect/image_helper_service.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/dietplan/diet_plan_viewer.dart';
import 'package:nutricare_connect/new/flat_diet_plan_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
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

    // 🎨 THEME ACCESS (Elite Palette integration)
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.error != null) return Center(child: Text('Error: ${state.error}'));

    final FlatClientDietPlanModel? activePlan = state.activePlan;
    if (activePlan == null) return const Center(child: Text('No active diet plan assigned.'));

    final vitals = state.clinicalVitals;
    final guidelines = vitals?.clinicalGuidelines ?? {};

    // 🚀 NEW FLAT LOGIC: Determine Correct Day Items
    final bool isWeekly = activePlan.allItems.map((e) => e.dayId).toSet().length > 1;
    List<FlatDietPlanItem> itemsForSelectedDay = [];

    if (activePlan.allItems.isNotEmpty) {
      if (isWeekly) {
        final selectedDayName = DateFormat('EEEE').format(state.selectedDate).toLowerCase();
        final selectedDayIndex = "day ${state.selectedDate.weekday}";

        itemsForSelectedDay = activePlan.allItems.where((item) {
          final dbDay = item.dayName.trim().toLowerCase();
          return dbDay == selectedDayName || dbDay == selectedDayIndex;
        }).toList();

        if (itemsForSelectedDay.isEmpty) {
          final firstDayId = activePlan.allItems.first.dayId;
          itemsForSelectedDay = activePlan.allItems.where((i) => i.dayId == firstDayId).toList();
        }
      } else {
        itemsForSelectedDay = activePlan.allItems;
      }
    }

    final dailyRecord = state.dailyRecord;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // 1. 🚀 THE NEW ELITE COMPACT HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Title / Context
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Daily Plan", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      Text("Track meals & wellness", style: TextStyle(fontSize: 14, color: theme.hintColor)),
                    ],
                  ),

                  // PDF Export Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.picture_as_pdf, color: isDark ? Colors.redAccent : Colors.red.shade700, size: 20),
                    ),
                    tooltip: "View Full Plan",
                    onPressed: () {
                      if (activePlan == null) return;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DietPlanViewerScreen(plan: activePlan, vitals: state.clinicalVitals)));
                    },
                  ),
                ],
              ),
            ),
          ),

          // 2. 🚀 THE ELITE DATE PILL (Replaces the Calendar Ribbon)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: _buildEliteDatePill(context, state, notifier, theme),
            ),
          ),

          // 3. WELLNESS TRACKER (Now pushed higher up the screen!)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildWellnessRail(context, activePlan, dailyRecord, notifier),
            ),
          ),

          // ... (Keep the rest of your Nutrition Timeline slivers below here) ...
          // 4. NUTRITION SECTION TITLE
          // 4. PROTOCOL & TIMELINE HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu, size: 20, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text("Nutrition Timeline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const Spacer(),

                  // 🚀 THE PASSIVE PROTOCOL BUTTON
                  if (guidelines.isNotEmpty || activePlan.assignedHabits.isNotEmpty)
                    InkWell(
                      onTap: () => _showProtocolSheet(context, guidelines, activePlan.assignedHabits, theme),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Text("Daily Protocol", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colorScheme.primary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 5. MEAL LIST (With Smart Focus Logic)
          if (itemsForSelectedDay.isNotEmpty)
            _buildDailyMealList(context, itemsForSelectedDay, dailyRecord, activePlan, notifier, state.selectedDate)
          else
            const SliverToBoxAdapter(child: Center(child: Text("Rest Day - No Meals Planned"))),


          const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
        ],
      ),
    );
  }
  void _showProtocolSheet(BuildContext context, Map<String, String> guidelines, List<String> habits, ThemeData theme) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121826) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40)],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
                  ),
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Text("Daily Protocol", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: colorScheme.onSurface, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Review your dietitian's core principles for success.", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                  const SizedBox(height: 24),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🚀 PASSIVE HABITS LIST
                          if (habits.isNotEmpty) ...[
                            Text("CORE HABITS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withOpacity(0.1))),
                              child: Column(
                                children: habits.map((habit) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(padding: const EdgeInsets.only(top: 4.0), child: Icon(Icons.star_rounded, size: 14, color: colorScheme.primary)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(habit, style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.onSurface, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],

                          // 🚀 CLINICAL GUIDELINES
                          if (guidelines.isNotEmpty) ...[
                            Text("CLINICAL GUIDELINES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            ...guidelines.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(padding: const EdgeInsets.only(top: 2.0), child: Icon(Icons.medical_information_rounded, size: 18, color: Colors.blueAccent.shade200)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, height: 1.5, fontSize: 14),
                                        children: [
                                          TextSpan(text: "${e.key}: ", style: const TextStyle(fontWeight: FontWeight.w800)),
                                          TextSpan(text: e.value, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary, foregroundColor: Colors.white,
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("GOT IT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  )
                ],
              ),
            ),
          );
        }
    );
  }

  // ===========================================================================
  // 🚀 THE ELITE HORIZONTAL CALENDAR RIBBON
  // ===========================================================================
// ===========================================================================
  // 🚀 THE ELITE HORIZONTAL CALENDAR RIBBON (7-DAY PULSE)
  // ===========================================================================
  // ===========================================================================
  // 🚀 THE ELITE HORIZONTAL CALENDAR RIBBON (FIXED ALIGNMENT)
  // ===========================================================================
  // ===========================================================================
  // 🚀 THE COMPACT ELITE DATE PILL
  // ===========================================================================
  Widget _buildEliteDatePill(BuildContext context, DietPlanState state, DietPlanNotifier notifier, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(state.selectedDate, now);
    final isYesterday = DateUtils.isSameDay(state.selectedDate, now.subtract(const Duration(days: 1)));

    // Smart Text Formatting
    String dateString;
    if (isToday) {
      dateString = "TODAY";
    } else if (isYesterday) {
      dateString = "YESTERDAY";
    } else {
      dateString = DateFormat('MMM d, yyyy').format(state.selectedDate).toUpperCase();
    }

    // Elite Palette
    final neonGreen = const Color(0xFF00E676);
    final surfaceColor = isDark ? const Color(0xFF121826) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ⬅️ PREVIOUS DAY BUTTON
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.selectDate(state.selectedDate.subtract(const Duration(days: 1)));
            },
            icon: Icon(Icons.chevron_left_rounded, color: theme.hintColor),
            style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          ),

          // 📅 CENTER: DEEP CALENDAR SELECTOR
          Expanded(
            child: InkWell(
              onTap: () async {
                HapticFeedback.selectionClick();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(), // Prevent future selection
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        dialogTheme: DialogThemeData(
                          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        colorScheme: colorScheme.copyWith(
                          primary: neonGreen,
                          onPrimary: Colors.black, // Text on the selected date
                          surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          onSurface: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) notifier.selectDate(picked);
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: isToday ? neonGreen : colorScheme.onSurface),
                    const SizedBox(width: 8),
                    Text(
                      dateString,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                        color: isToday ? neonGreen : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, size: 18, color: theme.hintColor),
                  ],
                ),
              ),
            ),
          ),

          // ➡️ NEXT DAY BUTTON (Disabled if on Today)
          IconButton(
            onPressed: isToday ? null : () {
              HapticFeedback.lightImpact();
              notifier.selectDate(state.selectedDate.add(const Duration(days: 1)));
            },
            icon: Icon(Icons.chevron_right_rounded, color: isToday ? theme.disabledColor : theme.hintColor),
            style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          ),
        ],
      ),
    );
  }// 🚀 THE TIMELINE (WITH "NOW" FOCUS LOGIC)
  // ===========================================================================
  Widget _buildDailyMealList(
      BuildContext context,
      List<FlatDietPlanItem> dayItems,
      ClientLogModel? dailyRecord,
      FlatClientDietPlanModel activePlan,
      DietPlanNotifier notifier,
      DateTime selectedDate
      ) {
    final uniqueMealIds = dayItems.map((e) => e.mealId).toSet().toList();

    uniqueMealIds.sort((a, b) {
      final orderA = _safeInt(dayItems.firstWhere((i) => i.mealId == a).mealOrder);
      final orderB = _safeInt(dayItems.firstWhere((i) => i.mealId == b).mealOrder);
      return orderA.compareTo(orderB);
    });

    // 🎯 FIND THE CURRENT FOCUS (First unlogged meal of today)
    String? focusedMealId;
    if (DateUtils.isSameDay(selectedDate, DateTime.now())) {
      for (final id in uniqueMealIds) {
        final fItem = dayItems.firstWhere((i) => i.mealId == id);
        if (dailyRecord == null || !(dailyRecord.mealLogs.containsKey(fItem.mealName))) {
          focusedMealId = id;
          break;
        }
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final mealId = uniqueMealIds[index];
            final allItemsInThisMeal = dayItems.where((i) => i.mealId == mealId).toList();
            final firstItem = allItemsInThisMeal.firstWhere(
                    (i) => i.itemType != DietItemType.alternative && i.itemType != DietItemType.bundleChild,
                orElse: () => allItemsInThisMeal.first
            );

            final mealName = firstItem.mealName;
            final mealTime = firstItem.mealTime;

            MealEntry? mealLog;
            if (dailyRecord != null && dailyRecord.mealLogs.isNotEmpty) {
              final searchKey = mealName.trim().toLowerCase();
              for (var entry in dailyRecord.mealLogs.entries) {
                if (entry.key.trim().toLowerCase() == searchKey) {
                  mealLog = entry.value;
                  break;
                }
              }
            }
            return EliteMealCard(
              mealName: mealName,
              mealTime: mealTime,
              mealItems: allItemsInThisMeal,
              mealLog: mealLog,
              isFocused: mealId == focusedMealId,
              isOverdue: _isMealOverdue(mealTime, selectedDate),
              notifier: notifier,     // 🚀 Ensure this is passed
              activePlan: activePlan, // 🚀 Ensure this is passed
              onQuickLog: () {
                _showImageSourceSelector(context, notifier, mealName);
              },
            );
          },
          childCount: uniqueMealIds.length,
        ),
      ),
    );
  }

  // ===========================================================================
  // 🕒 TIME LOGIC HELPER
  // ===========================================================================
  bool _isMealOverdue(String? timeStr, DateTime selectedDate) {
    if (timeStr == null || timeStr.isEmpty) return false;
    final now = DateTime.now();

    // If it's a past day, it's definitely overdue
    if (selectedDate.year < now.year ||
        (selectedDate.year == now.year && selectedDate.month < now.month) ||
        (selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day < now.day)) {
      return true;
    }
    // If it's a future day, it can't be overdue
    if (!DateUtils.isSameDay(selectedDate, now)) return false;

    // If it's today, check the exact time
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

      // A meal is considered "Late/Overdue" if 30 minutes have passed since the planned time
      return now.isAfter(mealTime.add(const Duration(minutes: 30)));
    } catch (e) {
      return false;
    }
  }

  // 🛡️ SAFE PARSING HELPERS
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

  Widget _buildWellnessRail(BuildContext context, FlatClientDietPlanModel plan, ClientLogModel? log, DietPlanNotifier notifier) {
    final waterGoal = _safeDouble(plan.dailyWaterGoal);
    final waterCurrent = _safeDouble(log?.hydrationLiters);

    final stepGoal = _safeInt(plan.dailyStepGoal);
    final stepCurrent = _safeInt(log?.stepCount);

    final sleepGoal = _safeDouble(plan.dailySleepGoal);
    final sleepCurrent = _safeDouble(log?.totalSleepDurationHours);

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
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
          _buildStandardRailingShell(
            context: context, index: 1,
            onTap: () => _openSheet(context, MovementDetailSheet.withSteps(notifier: notifier, activePlan: plan, dailyLog: log, currentSteps: stepCurrent)),
            child: AnimatedMovementContent(
              progress: stepGoal > 0 ? (stepCurrent / stepGoal) : 0,
              title: "Movement",
              subtitle: "$stepCurrent / $stepGoal",
            ),
          ),
          _buildStandardRailingShell(
            context: context, index: 2,
            onTap: () => _openSheet(context, SleepDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log)),
            child: AnimatedSleepContent(
              progress: sleepGoal > 0 ? (sleepCurrent / sleepGoal) : 0,
              title: "Sleep",
              subtitle: "${sleepCurrent.toStringAsFixed(1)} / $sleepGoal h",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardRailingShell({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
    required int index,
    double? progress,
    Color? progressColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeOutBack,
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

  Widget _buildHabitTile(String task, bool isDone, DietPlanNotifier notifier, ClientLogModel? dailyRecord, FlatClientDietPlanModel plan) {
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
                HapticFeedback.selectionClick();
                final list = List<String>.from(dailyRecord?.completedMandatoryTasks ?? []);
                if(val == true) list.add(task); else list.remove(task);

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

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(isDismissible: false, context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }

  void _showGuidelinesSheet(BuildContext context, Map<String, String> guidelines, ThemeData theme) {
    // ... keep existing guidelines sheet logic ...
  }
}

// =============================================================================
// --- 🌊 WELLNESS WIDGETS ---
// =============================================================================
// [Keep AnimatedLiquidWave, _LiquidWavePainter, AnimatedMovementContent, AnimatedSleepContent, _buildSmoothProgressBar unchanged from your code]

class AnimatedLiquidWave extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;
  final IconData icon;
  const AnimatedLiquidWave({super.key, required this.progress, required this.title, required this.subtitle, required this.icon});
  @override State<AnimatedLiquidWave> createState() => _AnimatedLiquidWaveState();
}
class _AnimatedLiquidWaveState extends State<AnimatedLiquidWave> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  @override void initState() { super.initState(); _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); }
  @override void dispose() { _waveController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(animation: _waveController, builder: (context, _) {
              return CustomPaint(painter: _LiquidWavePainter(progress: widget.progress, animationValue: _waveController.value, frontColor: Colors.blue.shade400.withOpacity(0.8), backColor: Colors.lightBlueAccent.shade200.withOpacity(0.5)));
            }),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(widget.icon, color: widget.progress > 0.6 ? Colors.white : Colors.blue.shade600, size: 20),
                if (widget.progress >= 1.0) const Icon(Icons.check_circle, color: Colors.white, size: 16),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.progress > 0.4 ? Colors.white : theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.progress > 0.4 ? Colors.white.withOpacity(0.9) : theme.hintColor)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
class _LiquidWavePainter extends CustomPainter {
  final double progress; final double animationValue; final Color frontColor; final Color backColor;
  _LiquidWavePainter({required this.progress, required this.animationValue, required this.frontColor, required this.backColor});
  @override void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    final waterHeight = size.height * (1 - progress.clamp(0.0, 1.0));
    final waveWidth = size.width;
    final amplitude = progress < 0.1 || progress > 0.9 ? 3.0 : 6.0;
    _drawWave(canvas, size, waterHeight, waveWidth, amplitude, animationValue, backColor);
    _drawWave(canvas, size, waterHeight, waveWidth, amplitude, animationValue + 0.5, frontColor);
  }
  void _drawWave(Canvas canvas, Size size, double waterHeight, double waveWidth, double amplitude, double phase, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path(); path.moveTo(0, size.height); path.lineTo(0, waterHeight);
    for (double x = 0; x <= size.width; x++) { final y = waterHeight + math.sin((x / waveWidth * 2 * math.pi) + (phase * 2 * math.pi)) * amplitude; path.lineTo(x, y); }
    path.lineTo(size.width, size.height); path.close(); canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant _LiquidWavePainter oldDelegate) { return oldDelegate.animationValue != animationValue || oldDelegate.progress != progress; }
}

class AnimatedMovementContent extends StatefulWidget {
  final double progress; final String title; final String subtitle;
  const AnimatedMovementContent({super.key, required this.progress, required this.title, required this.subtitle});
  @override State<AnimatedMovementContent> createState() => _AnimatedMovementContentState();
}
class _AnimatedMovementContentState extends State<AnimatedMovementContent> with SingleTickerProviderStateMixin {
  late AnimationController _runController;
  @override void initState() { super.initState(); _runController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true); }
  @override void dispose() { _runController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AnimatedBuilder(animation: _runController, builder: (context, child) { return Transform.translate(offset: Offset(0, -3 * _runController.value), child: const Icon(Icons.directions_run_rounded, color: Colors.orange, size: 22));}),
          if (widget.progress >= 1.0) const Icon(Icons.check_circle, color: Colors.orange, size: 16),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
          Text(widget.subtitle, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)),
        ]),
        _buildSmoothProgressBar(widget.progress, Colors.orange),
      ],
    );
  }
}

class AnimatedSleepContent extends StatefulWidget {
  final double progress; final String title; final String subtitle;
  const AnimatedSleepContent({super.key, required this.progress, required this.title, required this.subtitle});
  @override State<AnimatedSleepContent> createState() => _AnimatedSleepContentState();
}
class _AnimatedSleepContentState extends State<AnimatedSleepContent> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  @override void initState() { super.initState(); _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true); }
  @override void dispose() { _glowController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AnimatedBuilder(animation: _glowController, builder: (context, child) { return Icon(Icons.bedtime_rounded, color: Colors.indigo, size: 20, shadows: [Shadow(color: Colors.indigoAccent.withOpacity(0.8 * _glowController.value), blurRadius: 15 * _glowController.value)]);}),
          if (widget.progress >= 1.0) const Icon(Icons.check_circle, color: Colors.indigo, size: 16),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
          Text(widget.subtitle, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)),
        ]),
        _buildSmoothProgressBar(widget.progress, Colors.indigo),
      ],
    );
  }
}

Widget _buildSmoothProgressBar(double progress, Color color) {
  return TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic, tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
    builder: (context, val, _) => ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: val, minHeight: 4, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color))),
  );
}


// ===========================================================================
// 📸 PREMIUM IMAGE SOURCE SELECTOR
// ===========================================================================
// ===========================================================================
// 📸 PREMIUM IMAGE SOURCE SELECTOR (WITH ADHERENCE BY DEFAULT)
// ===========================================================================
void _showImageSourceSelector(BuildContext context, DietPlanNotifier notifier, String mealName) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final colorScheme = theme.colorScheme;
  final neonGreen = const Color(0xFF00E676);

  // 🚀 THE FIX: Enforce "Adherence Followed" by default for all Quick Logs
  final Map<String, dynamic> defaultAdherentPayload = {
    'mealLogs': {
      mealName: {
        'status': 'completed', // Assumes they ate it
        'isDeviation': false,  // Assumes they followed the plan
        'loggedAt': DateTime.now().toIso8601String(),
      }
    }
  };

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121826) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),

              // 📸 Camera Option
              ListTile(
                onTap: () async {
                  Navigator.pop(context); // Close sheet instantly
                  final photo = await ImageHelperService.pickAndCompressToWebP(source: ImageSource.camera);
                  if (photo != null) {
                    notifier.updateDailyRecord(
                      data: defaultAdherentPayload, // 🚀 Applies perfect adherence
                      newPhotos: [photo],
                      mealNameForPhotos: mealName,
                    );
                  }
                },
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: neonGreen.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt_rounded, color: neonGreen),
                ),
                title: const Text("Take Photo", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                subtitle: Text("Snap your current meal", style: TextStyle(color: theme.hintColor, fontSize: 12)),
              ),

              const SizedBox(height: 8),
              Divider(color: isDark ? Colors.white10 : Colors.black12),
              const SizedBox(height: 8),

              // 🖼️ Gallery Option
              ListTile(
                onTap: () async {
                  Navigator.pop(context);
                  final photo = await ImageHelperService.pickAndCompressToWebP(source: ImageSource.gallery);
                  if (photo != null) {
                    notifier.updateDailyRecord(
                      data: defaultAdherentPayload, // 🚀 Applies perfect adherence
                      newPhotos: [photo],
                      mealNameForPhotos: mealName,
                    );
                  }
                },
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.photo_library_rounded, color: colorScheme.primary),
                ),
                title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                subtitle: Text("Upload a previously taken photo", style: TextStyle(color: theme.hintColor, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    },
  );
}