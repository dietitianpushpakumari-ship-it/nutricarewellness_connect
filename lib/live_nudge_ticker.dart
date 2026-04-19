import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

// 🎯 Models & Providers
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/models/vitals_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 Sheets & Screens
import 'package:pure_shift/new/dietplan/meal_detail_sheet.dart';
import 'package:pure_shift/new/dietplan/hydration_detail_screen.dart';
import 'package:pure_shift/new/dashboard/daily_log_logging_screen.dart';

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
// 🚀 2. THE LIVE TICKER WIDGET (Fixed Pill Design & Text Clipping)
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

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
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

    final now = DateTime.now();
    final double currentHourDouble = now.hour + (now.minute / 60.0);
    const double dayStart = 6.0;
    const double dayEnd = 22.0;
    double dayProgress = ((currentHourDouble - dayStart) / (dayEnd - dayStart)).clamp(0.0, 1.0);

    nudges.add(TickerNudge(
        title: "INBOX: You have new clinical messages in your inbox.",
        priority: "high_info",
        onTap: () {
          HapticFeedback.mediumImpact();
        }
    ));

    final double currentWater = dailyRecord?.hydrationLiters ?? 0.0;
    final double waterGoal = plan!.dailyWaterGoal > 0 ? plan.dailyWaterGoal : 2.0;
    final double waterProgress = (currentWater / waterGoal).clamp(0.0, 1.0);
    String waterPriority = (dayProgress > 0.2 && waterProgress < (dayProgress - 0.2)) ? "medium" : "low";

    nudges.add(TickerNudge(
      title: "HYDRATION: ${(waterGoal - currentWater).toStringAsFixed(1)}L remaining to hit goal.",
      priority: waterPriority,
      onTap: () => _launchHydrationSheet(context, state, dailyRecord, currentWater),
    ));

    final int currentSteps = dailyRecord?.stepCount ?? 0;
    const int stepGoal = 10000;
    final double stepProgress = (currentSteps / stepGoal).clamp(0.0, 1.0);
    String stepPriority = (dayProgress > 0.6 && stepProgress < 0.4) ? "medium" : "low";

    nudges.add(TickerNudge(
      title: "ACTIVITY: $currentSteps steps logged (${(currentSteps * 0.04).round()} kcal).",
      priority: stepPriority,
    ));

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
  // 🎨 Priority Colors mapped cleanly
  // ===========================================================================
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return const Color(0xFFFF3D00); // Neon Red
      case 'medium': return const Color(0xFFFFC107); // Amber
      case 'low': return const Color(0xFF00E676); // Neon Green
      case 'high_info': return const Color(0xFFBB86FC); // Violet
      default: return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeNudges = _generateLiveNudges();
    if (activeNudges.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return SizedBox(
      height: 38, // Keeps the compact height
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

                // 🚀 THE FIX: Split the string into Title and Message
                final parts = nudge.title.split(':');
                final String categoryTitle = parts.isNotEmpty ? parts[0].trim() : "";
                final String subMessage = parts.length > 1 ? parts.sublist(1).join(':').trim() : "";

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
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: glowColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: glowColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated pulsing icon
                        Icon(
                            Icons.auto_awesome_rounded,
                            color: glowColor.withOpacity(0.6 + (_glowAnimation.value / 20)),
                            size: 16
                        ),
                        const SizedBox(width: 8),

                        // 🚀 THE FIX: RichText allows different styles in the same sentence
                        RichText(
                          text: TextSpan(
                            children: [
                              // 1. GLOWING TITLE (e.g., "MISSED MEAL")
                              TextSpan(
                                text: "$categoryTitle: ",
                                style: TextStyle(
                                  color: glowColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900, // Extra bold
                                  letterSpacing: 0.5,
                                  // This adds the neon glow effect exactly matching the priority color
                                  shadows: [
                                    Shadow(
                                      color: glowColor.withOpacity(0.6),
                                      blurRadius: 4 + (_glowAnimation.value / 2), // Pulses with the animation!
                                    ),
                                  ],
                                ),
                              ),
                              // 2. CLEAN SUB-MESSAGE (e.g., "Tap to log")
                              TextSpan(
                                text: subMessage,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
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