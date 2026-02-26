import 'dart:async';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/new/dashboard/daily_log_logging_screen.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/new/models/diet_plan_item_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:collection/collection.dart';

// Sheets & Data
import 'package:nutricare_connect/new/dietplan/meal_detail_sheet.dart';
import 'package:nutricare_connect/new/dietplan/hydration_detail_screen.dart';

class _NudgeCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String btnLabel;
  final bool isUrgent;
  final String timeText;

  _NudgeCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.btnLabel,
    this.isUrgent = false,
    this.timeText = "Now",
  });
}

class SmartNudgeBar extends ConsumerStatefulWidget {
  final String clientId;
  const SmartNudgeBar({super.key, required this.clientId});

  @override
  ConsumerState<SmartNudgeBar> createState() => _SmartNudgeBarState();
}

class _SmartNudgeBarState extends ConsumerState<SmartNudgeBar> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.95);
  Timer? _timer;
  int _currentPage = 0;

  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  final List<_NudgeCardData> _contentNudges = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDailyContent();
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTimer();
  }

  Future<void> _loadDailyContent() async {
    if (mounted) {
      setState(() {
        if (_contentNudges.isEmpty) {
          _contentNudges.add(_NudgeCardData(
              title: context.tr("daily_tips") ?? "Daily Focus",
              subtitle: "${context.tr("stay_hydrated") ?? "Consistency is key today. Keep your water intake steady!"}",
              icon: Icons.lightbulb_circle,
              color: Colors.blueAccent,
              onTap: (){},
              btnLabel: "View"
          ));
        }
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 8), (Timer timer) {
      if (!_pageController.hasClients || _contentNudges.isEmpty) return;

      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn,
      ).then((_) {
        final items = _getAllNudges(context);
        if (items.isNotEmpty) {
          final currentIndex = _pageController.page?.round() ?? 0;
          final currentItem = items[currentIndex % items.length];
          if (currentItem.isUrgent) {
            HapticFeedback.mediumImpact();
          }
        }
      }).catchError((e) {
        _pageController.jumpToPage(0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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

  // 🎯 ATOMIC LOGIC APPLIED TO NUDGE GENERATION
  List<_NudgeCardData> _getAllNudges(BuildContext context) {
    final state = ref.watch(activeDietPlanProvider);
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));
    final ClientDietPlanModel? plan = state.activePlan;

    // 🎯 Use the Single Source of Truth
    final dailyRecord = state.dailyRecord;

    List<_NudgeCardData> nudges = [];

    // 🔴 1. MEDICATION
    if (vitalsAsync.value != null && vitalsAsync.value!.isNotEmpty) {
      final sortedVitals = List<VitalsModel>.from(vitalsAsync.value!)
        ..sort((a, b) => b.date.compareTo(a.date));

      if (sortedVitals.isNotEmpty) {
        final latestMeds = sortedVitals.first.medications;
        final now = TimeOfDay.now();

        final dueMed = IterableExtensions(latestMeds).firstWhereOrNull((m) {
          if (m.reminderTime == null) return false;
          final parts = m.reminderTime!.split(':');
          if (parts.length < 2) return false;
          final medHour = int.tryParse(parts[0]) ?? -1;
          return (now.hour == medHour || now.hour == medHour + 1);
        });

        if (dueMed != null) {
          nudges.add(_NudgeCardData(
            title: "Medication Alert",
            subtitle: "It's time to take ${dueMed.medicineName}.",
            icon: Icons.medication_liquid_rounded,
            color: const Color(0xFFFF1744),
            btnLabel: "Log",
            isUrgent: true,
            timeText: "Now",
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as taken!"), backgroundColor: Colors.green));
            },
          ));
        }
      }
    }

    if (plan == null) return nudges;

    // 🟠 2. MEALS
    if (plan.days.isNotEmpty) {
      final todayMeals = plan.days.first.meals;
      final now = TimeOfDay.now();
      final nowDouble = now.hour + now.minute / 60.0;

      for (var meal in todayMeals) {
        // 🎯 Read directly from the mealLogs map
        final mealLog = dailyRecord?.mealLogs[meal.mealName];
        final isLogged = mealLog != null && mealLog.status != LogStatus.skipped;

        if (isLogged) continue;

        double targetEndDouble = 24.0;
        if (meal.time != null && meal.time!.isNotEmpty) {
          targetEndDouble = _parseTimeStrToDouble(meal.time!) + 1.0;
        } else {
          final name = meal.mealName.toLowerCase();
          if (name.contains('wake')) targetEndDouble = 9.0;
          else if (name.contains('lunch')) targetEndDouble = 15.5;
          else if (name.contains('dinner')) targetEndDouble = 22.5;
        }

        if (nowDouble >= targetEndDouble) {
          nudges.add(_NudgeCardData(
            title: "Missed Meal?",
            subtitle: "You haven't logged your ${meal.mealName} yet.",
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFFF9100),
            btnLabel: "Log Now",
            isUrgent: true,
            timeText: "1h ago",
            onTap: () => _launchMealLogger(context, meal, plan),
          ));
          break;
        }
      }
    }

    // 💧 3. HYDRATION
    if (plan != null) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final double waterGoal = plan.dailyWaterGoal > 0 ? plan.dailyWaterGoal : 2.0;

      // 🎯 Read hydration directly from dailyRecord
      final double currentWater = dailyRecord?.hydrationLiters ?? 0.0;

      const double dayStart = 8.0;
      const double dayEnd = 20.0;

      if (currentHour >= dayStart && currentHour <= dayEnd) {
        double hoursPassed = currentHour - dayStart;
        double totalActiveHours = dayEnd - dayStart;
        double expectedIntake = (hoursPassed / totalActiveHours) * waterGoal;

        if (currentWater < (expectedIntake - 0.3)) {
          nudges.add(_NudgeCardData(
            title: "Falling Behind!",
            subtitle: "You should have had ${expectedIntake.toStringAsFixed(1)}L by now. Drink a glass of water!",
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF00E5FF),
            btnLabel: "Drink Now",
            isUrgent: true,
            timeText: "Alert",
            onTap: () => _launchHydrationSheet(context, state, dailyRecord, currentWater),
          ));
        }
      }
    }

    // 🟢 4. DAILY TIP
    nudges.add(_NudgeCardData(
        title: "Daily Focus",
        subtitle: "Consistency is key today. Keep your habits steady!",
        icon: Icons.self_improvement_rounded,
        color: const Color(0xFF00E676),
        btnLabel: "View",
        onTap: (){}
    ));

    return nudges;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allNudges = _getAllNudges(context);

    // 🎯 Fetch Progress State
    final dietPlanState = ref.watch(activeDietPlanProvider);
    final progressData = _calculateGoalProgress(dietPlanState);
    final int completed = progressData['completed'];
    final int total = progressData['total'];
    final double progress = progressData['progress'];
    final bool isDone = progressData['isDone'];

    if (allNudges.isEmpty && total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🎯 FIX 1: Wrapped the left title area in an Expanded widget
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    // 🎯 FIX 2: Wrapped the text itself so it truncates safely
                    Expanded(
                      child: Text(
                          context.tr("daily_focus") ?? "DAILY FOCUS",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: colorScheme.onSurfaceVariant
                          )
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12), // Safe spacing

              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openDailyGoals(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withOpacity(0.15)
                        : (progress < 0.3 ? colorScheme.error.withOpacity(0.1) : colorScheme.primary.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDone
                          ? Colors.green.withOpacity(0.5)
                          : (progress < 0.3 ? colorScheme.error.withOpacity(0.5) : colorScheme.primary.withOpacity(0.3)),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isDone && progress < 0.5)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Icon(Icons.priority_high_rounded, size: 14, color: colorScheme.error),
                        ),
                      SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            backgroundColor: colorScheme.onSurface.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(
                                isDone ? Colors.green : (progress < 0.3 ? colorScheme.error : colorScheme.primary)
                            ),
                          )
                      ),
                      const SizedBox(width: 8),
                      Text(
                          isDone ? "All Done!" : "$completed/$total Tasks",
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.green : (progress < 0.3 ? colorScheme.error : colorScheme.primary),
                          )
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (allNudges.isNotEmpty)
          SizedBox(
            height: 110,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index % allNudges.length);
                if (allNudges[index % allNudges.length].isUrgent) {
                  HapticFeedback.selectionClick();
                }
              },
              itemBuilder: (context, index) {
                return _buildNotificationCard(context, allNudges[index % allNudges.length]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationCard(BuildContext context, _NudgeCardData data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return GestureDetector(
            onTap: () {
              if (data.isUrgent) HapticFeedback.lightImpact();
              data.onTap();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                      data.color.withOpacity(isDark ? 0.15 : 0.08),
                      theme.cardColor
                    ],
                    begin: Alignment.centerLeft, end: Alignment.centerRight
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: data.isUrgent
                      ? data.color.withOpacity((0.4 + (_glowAnimation.value / 15)).clamp(0.0, 1.0))
                      : data.color.withOpacity(0.3),
                  width: data.isUrgent
                      ? 1.5 + (_glowAnimation.value / 10)
                      : 1.0,
                ),
                boxShadow: [
                  if (data.isUrgent)
                    BoxShadow(
                      color: data.color.withOpacity(0.3 + (_glowAnimation.value / 25)),
                      blurRadius: 15 + _glowAnimation.value,
                      spreadRadius: 2,
                      offset: const Offset(0, 0),
                      blurStyle: BlurStyle.inner,
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: data.color.withOpacity(0.15),
                        shape: BoxShape.circle
                    ),
                    child: Icon(data.icon, color: data.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // 🎯 FIX 1: Keeps the column as tight as possible
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                  data.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface
                                  )
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                                data.timeText,
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontSize: 10)
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // 🎯 FIX 2: Wrapped the subtitle in Flexible.
                        // This acts as a vertical safety valve, forcing truncation
                        // if it runs out of vertical space.
                        Flexible(
                          child: Text(
                              data.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 🎯 FIX: Wrapped the ElevatedButton in a Flexible widget
                  // and added overflow handling to its text.
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () {
                        if (data.isUrgent) HapticFeedback.lightImpact();
                        data.onTap();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: data.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 30),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                          data.btnLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
  void _launchMealLogger(BuildContext context, DietPlanMealModel meal, ClientDietPlanModel plan) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);
    // 🎯 Passes null for logToEdit since this is a nudge for a missed/unlogged meal
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MealDetailSheet(notifier: notifier, mealName: meal.mealName, activePlan: plan, logToEdit: null, plannedItems: meal.items));
  }

  void _launchHydrationSheet(BuildContext context, DietPlanState state, ClientLogModel? dailyRecord, double current) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);
    // 🎯 Passes dailyRecord directly
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => HydrationDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord, currentIntake: current));
  }

  void _openDailyGoals(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DailyGoalsLoggingScreen(clientId: widget.clientId)));
  }

  // 🎯 ATOMIC LOGIC APPLIED TO PROGRESS CALCULATION
  Map<String, dynamic> _calculateGoalProgress(DietPlanState state) {
    int totalTasks = 0;
    int completedTasks = 0;

    final plan = state.activePlan;
    final dailyRecord = state.dailyRecord;

    if (plan != null) {
      // 1. Count Meals
      if (plan.days.isNotEmpty) {
        for (var meal in plan.days.first.meals) {
          totalTasks++;
          final mealLog = dailyRecord?.mealLogs[meal.mealName];
          if (mealLog != null && mealLog.status != LogStatus.skipped) {
            completedTasks++;
          }
        }
      }

      // 2. Count Hydration Goal
      totalTasks++;
      if ((dailyRecord?.hydrationLiters ?? 0) >= (plan.dailyWaterGoal > 0 ? plan.dailyWaterGoal : 2.0)) {
        completedTasks++;
      }

      // 3. Count Movement/Activity
      totalTasks++;
      if ((dailyRecord?.stepCount ?? 0) > 0 || (dailyRecord?.activityScore ?? 0) > 0) {
        completedTasks++;
      }
    }

    return {
      'total': totalTasks,
      'completed': completedTasks,
      'progress': totalTasks == 0 ? 0.0 : completedTasks / totalTasks,
      'isDone': totalTasks > 0 && completedTasks >= totalTasks,
    };
  }
}