import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

// 🎯 Models & Providers
import 'package:nutricare_connect/new/flat_diet_plan_model.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 Sheets & Screens
import 'package:nutricare_connect/new/dietplan/meal_detail_sheet.dart';
import 'package:nutricare_connect/new/dietplan/hydration_detail_screen.dart';
import 'package:nutricare_connect/new/dashboard/daily_log_logging_screen.dart';

// ===========================================================================
// 🧠 1. THE NUDGE DATA MODEL
// ===========================================================================
class TickerNudge {
  final String title;
  final String priority; // 'high', 'medium', 'low'
  final VoidCallback? onTap;

  TickerNudge({required this.title, required this.priority, this.onTap});
}

// ===========================================================================
// 🚀 2. THE SENSEX TICKER WIDGET
// ===========================================================================
class LiveNudgeTicker extends ConsumerStatefulWidget {
  final String clientId;
  const LiveNudgeTicker({super.key, required this.clientId});

  @override
  ConsumerState<LiveNudgeTicker> createState() => _LiveNudgeTickerState();
}

class _LiveNudgeTickerState extends ConsumerState<LiveNudgeTicker> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  // Animation for the inner glow pulse
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation mirroring the old SmartNudgeBar
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        final double currentScroll = _scrollController.offset;

        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + 1.0);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // ⚙️ 3. CORE BUSINESS LOGIC
  // ===========================================================================
  double _parseTimeStrToDouble(String timeStr) {
    try {
      final cleanStr = timeStr.trim().toUpperCase();
      bool isPM = cleanStr.contains("PM");
      bool isAM = cleanStr.contains("AM");
      String timePart = cleanStr.replaceAll("AM", "").replaceAll("PM", "").trim();
      final parts = timePart.split(":");

      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0]);
        int min = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return hour + (min / 60.0);
      }
    } catch (e) {}
    return 24.0;
  }

  Map<String, dynamic> _calculateGoalProgress(DietPlanState state) {
    int totalTasks = 0;
    int completedTasks = 0;
    final plan = state.activePlan;
    final dailyRecord = state.dailyRecord;

    if (plan != null) {
      if (plan.allItems.isNotEmpty) {
        final uniqueMealIds = plan.allItems.map((e) => e.mealId).toSet();
        for (var mealId in uniqueMealIds) {
          final mealName = plan.allItems.firstWhere((i) => i.mealId == mealId).mealName;
          totalTasks++;
          final mealLog = dailyRecord?.mealLogs[mealName];
          if (mealLog != null && mealLog.status != LogStatus.skipped) {
            completedTasks++;
          }
        }
      }
      totalTasks++;
      if ((dailyRecord?.hydrationLiters ?? 0) >= (plan.dailyWaterGoal > 0 ? plan.dailyWaterGoal : 2.0)) {
        completedTasks++;
      }
      totalTasks++;
      if ((dailyRecord?.stepCount ?? 0) > 0 || (dailyRecord?.activityScore ?? 0) > 0) {
        completedTasks++;
      }
    }

    return {
      'total': totalTasks,
      'completed': completedTasks,
      'isDone': totalTasks > 0 && completedTasks >= totalTasks,
    };
  }

  List<TickerNudge> _generateLiveNudges() {
    final state = ref.watch(activeDietPlanProvider);
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));
    final FlatClientDietPlanModel? plan = state.activePlan;
    final dailyRecord = state.dailyRecord;
    List<TickerNudge> nudges = [];
    // 🕒 Time-based calculation for Smart Glow (6 AM to 10 PM)

    // 🟣 1. INBOX (High Priority Glow)
    // 🕒 CIRCADIAN WINDOW: 6 AM to 10 PM
    final now = DateTime.now();
    final double currentHourDouble = now.hour + (now.minute / 60.0);
    const double dayStart = 6.0;
    const double dayEnd = 22.0;

    // Percentage of the active day passed (0.0 to 1.0)
    double dayProgress = ((currentHourDouble - dayStart) / (dayEnd - dayStart)).clamp(0.0, 1.0);

    // 🟣 1. INBOX (Violet High Alert Glow)
    nudges.add(TickerNudge(
        title: "INBOX: You have new clinical messages in your inbox.",
        priority: "high_info",
        onTap: () {
          HapticFeedback.mediumImpact();
          // Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
        }
    ));

    // 🟠 2. HYDRATION (Smart Glow Escalation)
    final double currentWater = dailyRecord?.hydrationLiters ?? 0.0;
    final double waterGoal = plan!.dailyWaterGoal > 0 ? plan.dailyWaterGoal : 2.0;
    final double waterProgress = (currentWater / waterGoal).clamp(0.0, 1.0);

    // Escalates to Amber if we are >20% behind the day's expected progress
    String waterPriority = (dayProgress > 0.2 && waterProgress < (dayProgress - 0.2)) ? "medium" : "low";

    nudges.add(TickerNudge(
      title: "HYDRATION: ${(waterGoal - currentWater).toStringAsFixed(1)}L remaining to hit goal.",
      priority: waterPriority,
      onTap: () => _launchHydrationSheet(context, state, dailyRecord, currentWater),
    ));

    // 🟢 3. STEPS (Smart Glow Escalation)
    final int currentSteps = dailyRecord?.stepCount ?? 0;
    const int stepGoal = 10000;
    final double stepProgress = (currentSteps / stepGoal).clamp(0.0, 1.0);

    // Escalates to Amber if it's after 4 PM (dayProgress > 0.6) and steps are low
    String stepPriority = (dayProgress > 0.6 && stepProgress < 0.4) ? "medium" : "low";

    nudges.add(TickerNudge(
      title: "ACTIVITY: $currentSteps steps logged (${(currentSteps * 0.04).round()} kcal).",
      priority: stepPriority,
    ));

    // 🔴 1. MEDICATION LOGIC
    if (vitalsAsync.value != null && vitalsAsync.value!.isNotEmpty) {
      final sortedVitals = List<VitalsModel>.from(vitalsAsync.value!)..sort((a, b) => b.date.compareTo(a.date));
      if (sortedVitals.isNotEmpty) {
        final latestMeds = sortedVitals.first.medications;
        final now = TimeOfDay.now();
        final dueMed = latestMeds.firstWhereOrNull((m) {
          if (m.reminderTime == null) return false;
          final parts = m.reminderTime!.split(':');
          if (parts.length < 2) return false;
          final medHour = int.tryParse(parts[0]) ?? -1;
          return (now.hour == medHour || now.hour == medHour + 1);
        });

        if (dueMed != null) {
          nudges.add(TickerNudge(
            title: "MED ALERT: Time for ${dueMed.medicineName}. Tap to log.",
            priority: "high",
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as taken!"))),
          ));
        }
      }
    }



    if (plan == null) return nudges;

    // 🔴 2. MISSED MEAL LOGIC (Queues all missed meals)
    if (plan.allItems.isNotEmpty) {
      final now = TimeOfDay.now();
      final nowDouble = now.hour + now.minute / 60.0;
      final bool isWeekly = plan.allItems.map((e) => e.dayId).toSet().length > 1;
      List<FlatDietPlanItem> itemsForDay = isWeekly
          ? plan.allItems.where((item) => item.dayName.toLowerCase() == DateFormat('EEEE').format(state.selectedDate).toLowerCase()).toList()
          : plan.allItems;

      final uniqueMealIds = itemsForDay.map((e) => e.mealId).toSet().toList();
      uniqueMealIds.sort((a, b) => itemsForDay.firstWhere((i) => i.mealId == a).mealOrder.compareTo(itemsForDay.firstWhere((i) => i.mealId == b).mealOrder));

      for (var mealId in uniqueMealIds) {
        final mealItems = itemsForDay.where((i) => i.mealId == mealId).toList();
        final mealName = mealItems.first.mealName;
        final mealLog = dailyRecord?.mealLogs[mealName];
        if (mealLog != null && mealLog.status != LogStatus.skipped) continue;

        double targetEndDouble = 24.0;
        if (mealItems.first.mealTime != null && mealItems.first.mealTime!.isNotEmpty) {
          targetEndDouble = _parseTimeStrToDouble(mealItems.first.mealTime!) + 1.0;
        } else {
          final name = mealName.toLowerCase();
          if (name.contains('wake')) targetEndDouble = 9.0;
          else if (name.contains('lunch')) targetEndDouble = 15.5;
          else if (name.contains('dinner')) targetEndDouble = 22.5;
        }

        if (nowDouble >= targetEndDouble) {
          nudges.add(TickerNudge(
            title: "MISSED MEAL: $mealName is pending. Tap to log.",
            priority: "high",
            onTap: () {
              final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);
              showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MealDetailSheet(notifier: notifier, mealName: mealName, activePlan: plan, logToEdit: null, plannedItems: mealItems));
            },
          ));
        }
      }
    }




    // 🟢 6. GENERAL PROGRESS & FOCUS
    final progressData = _calculateGoalProgress(state);
    nudges.add(TickerNudge(
      title: "DAILY PROGRESS: ${progressData['completed']}/${progressData['total']} clinical tasks completed.",
      priority: "low",
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyGoalsLoggingScreen(clientId: widget.clientId))),
    ));

    nudges.add(TickerNudge(
      title: "DAILY FOCUS: Consistency is key today. Maintain your logs!",
      priority: "low",
    ));

    return nudges;
  }

  // ===========================================================================
  // 🎨 Updated Color Engine
  // ===========================================================================
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return const Color(0xFFFF3D00); // Neon Red
      case 'medium': return const Color(0xFFFFC107); // Amber
      case 'low': return const Color(0xFF00E676); // Neon Green
      case 'info': return const Color(0xFFBB86FC); // Premium Violet for Inbox
      default: return Colors.blueAccent;
    }
  }

  // ===========================================================================
  // 🎨 4. VISUAL ENGINE (Clean Inner-Glow Pill Shape)


  @override
  Widget build(BuildContext context) {
    final activeNudges = _generateLiveNudges();
    if (activeNudges.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 40, // Leaner, professional ticker height
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF070A11) : Colors.grey.shade900,
        border: Border.symmetric(horizontal: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
      ),
      child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: activeNudges.length * 20,
              itemBuilder: (context, index) {
                final nudge = activeNudges[index % activeNudges.length];
                final glowColor = _getPriorityColor(nudge.priority);
                final isHigh = nudge.priority == 'high';

                // Split the title into Category and Message for the Sensex look
                final parts = nudge.title.split(':');
                final category = parts[0].trim();
                final message = parts.length > 1 ? parts[1].trim() : "";

                return GestureDetector(
                  onPanDown: (_) => _timer?.cancel(),
                  onPanCancel: () => _startAutoScroll(),
                  onTap: () {
                    if (nudge.onTap != null) {
                      HapticFeedback.mediumImpact();
                      nudge.onTap!();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 2), // Tight spacing like a real ticker
                    child: Row(
                      children: [
                        // 1. 🚀 THE "STOCK CODE" BOX (Category)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isHigh
                                ? glowColor.withOpacity(0.2 + (_glowAnimation.value / 40))
                                : glowColor.withOpacity(0.1),
                            border: Border(
                              left: BorderSide(color: glowColor, width: isHigh ? 3 : 2),
                              // 🚀 Subtle top glow line
                              top: BorderSide(color: isHigh ? glowColor.withOpacity(0.5) : Colors.transparent),
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isHigh ? Colors.white : glowColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        // 2. 🚀 THE "VALUE" TEXT (Message)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            // Subtle inner glow bleed
                            gradient: LinearGradient(
                              colors: [
                                glowColor.withOpacity(isHigh ? 0.1 : 0.03),
                                Colors.transparent
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            // 🚀 Radioactive bottom glow for high priority
                            boxShadow: [
                              if (isHigh)
                                BoxShadow(
                                  color: glowColor.withOpacity(0.2),
                                  blurRadius: 10 + _glowAnimation.value,
                                  offset: const Offset(0, 2),
                                  blurStyle: BlurStyle.outer,
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                message,
                                style: TextStyle(
                                  color: isHigh ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isHigh ? FontWeight.w600 : FontWeight.w400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 24), // Gap before next card
                              // Sensex Separator
                              Container(width: 1, height: 15, color: Colors.white10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
      ),
    );
  }
  // 🚀 THE FIX: Navigation to Meal Detail Sheet
  void _launchMealLogger(BuildContext context, String mealName, List<FlatDietPlanItem> mealItems, FlatClientDietPlanModel plan) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MealDetailSheet(
            notifier: notifier,
            mealName: mealName,
            activePlan: plan,
            logToEdit: null,
            plannedItems: mealItems
        )
    );
  }

  // 🚀 THE FIX: Navigation to Hydration Sheet
  void _launchHydrationSheet(BuildContext context, DietPlanState state, ClientLogModel? dailyRecord, double current) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HydrationDetailSheet(
            notifier: notifier,
            activePlan: state.activePlan!,
            dailyLog: dailyRecord,
            currentIntake: current
        )
    );
  }
}


