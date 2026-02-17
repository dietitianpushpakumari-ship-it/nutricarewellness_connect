import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/localization/localization_extension.dart';
import 'package:nutricare_connect/core/utils/daily_log_logging_screen.dart';
import 'package:nutricare_connect/core/utils/master_data_provider.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/new/models/diet_plan_item_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:collection/collection.dart';

// Sheets & Data
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';
import 'package:nutricare_connect/features/diet_plan/meal_detail_sheet.dart';
import 'package:nutricare_connect/core/utils/hydration_detail_screen.dart';

class _NudgeCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String btnLabel;
  final bool isUrgent;
  final String? fullBody;

  _NudgeCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.btnLabel,
    this.isUrgent = false,
    this.fullBody,
  });
}

class SmartNudgeBar extends ConsumerStatefulWidget {
  final String clientId;
  const SmartNudgeBar({super.key, required this.clientId});

  @override
  ConsumerState<SmartNudgeBar> createState() => _SmartNudgeBarState();
}

class _SmartNudgeBarState extends ConsumerState<SmartNudgeBar> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _currentPage = 0;

  late AnimationController _wobbleController;
  late Animation<double> _shakeAnimation;

  final List<_NudgeCardData> _contentNudges = [];

  @override
  void initState() {
    super.initState();

    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: false);

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.03), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: -0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
    ]).animate(_wobbleController);

    _loadDailyContent();
    _startTimer();
  }

  Future<void> _loadDailyContent() async {
    if (mounted) {
      setState(() {
        if (_contentNudges.isEmpty) {
          _contentNudges.add(_NudgeCardData(
              title: context.tr("daily_tips") ?? "Daily Tips",
              subtitle: "${context.tr("stay_hydrated") ?? "Stay Hydrated"}!",
              icon: Icons.water_drop,
              color: Colors.blue,
              onTap: (){},
              btnLabel: "Read"
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
        curve: Curves.easeInOutQuart,
      ).catchError((e) {
        _pageController.jumpToPage(0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(activeDietPlanProvider);
    final masterMealsAsync = ref.watch(masterMealNamesProvider);
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    final ClientDietPlanModel? plan = state.activePlan;
    final dailyLog = IterableExtension(state.dailyLogs).firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    if (plan == null) return const SizedBox.shrink();

    List<_NudgeCardData> actionNudges = [];

    // 🎯 2. MEDICATION NUDGE LOGIC (FIXED)
    if (vitalsAsync.value != null && vitalsAsync.value!.isNotEmpty) {
      final sortedVitals = List<VitalsModel>.from(vitalsAsync.value!)
        ..sort((a, b) => b.date.compareTo(a.date));

      if (sortedVitals.isNotEmpty) {
        // 🛠️ FIX: Use 'medications' (List) instead of 'prescribedMedications' (Map)
        final latestMeds = sortedVitals.first.medications;

        final now = TimeOfDay.now();
        // Check for meds due in current hour
        final dueMed = IterableExtension(latestMeds).firstWhereOrNull((m) {
          // If reminderTime is missing, skip or fallback logic
          if (m.reminderTime == null) return false;

          final parts = m.reminderTime!.split(':');
          if (parts.length < 2) return false;

          final medHour = int.tryParse(parts[0]) ?? -1;
          if (medHour == -1) return false;

          return (now.hour == medHour || now.hour == medHour + 1);
        });

        if (dueMed != null) {
          actionNudges.add(_NudgeCardData(
            title: context.tr("medication_reminder") ?? "Medication",
            subtitle: "${context.tr("time_to_take") ?? "Time to take"} ${dueMed.medicineName}",
            icon: Icons.medication,
            color: colorScheme.tertiary,
            btnLabel: context.tr("taken") ?? "Taken",
            isUrgent: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${context.tr("marked_as_taken") ?? "Marked as taken"}!"), backgroundColor: Colors.green)
              );
            },
          ));
        }
      }
    }

    // A. MEALS
    if (masterMealsAsync.value != null && plan.days.isNotEmpty) {
      final masterMeals = masterMealsAsync.value!;
      final todayMeals = plan.days.first.meals;
      final now = TimeOfDay.now();
      final nowDouble = now.hour + now.minute / 60.0;

      List<DietPlanMealModel> overdueMeals = [];
      for (var meal in todayMeals) {
        final isLogged = state.dailyLogs.any((l) => l.mealName == meal.mealName && l.logStatus != LogStatus.skipped);
        if (isLogged) continue;

        final config = IterableExtension(masterMeals).firstWhereOrNull((m) => m.id == meal.mealNameId || m.enName == meal.mealName);

        if (config != null && config.endTime != null) {
          final parts = config.endTime!.split(':');
          if (parts.length >= 2) {
            final endDouble = int.parse(parts[0]) + int.parse(parts[1]) / 60.0;
            if (nowDouble >= endDouble) overdueMeals.add(meal);
          }
        }
      }

      if (overdueMeals.isNotEmpty) {
        final first = overdueMeals.first;
        actionNudges.add(_NudgeCardData(
          title: "${context.tr("meal_time") ?? "Meal Time"}!",
          subtitle: "${context.tr("have_you_had_your") ?? "Have you had your"} ${first.mealName}?",
          icon: Icons.restaurant,
          color: colorScheme.error,
          btnLabel: "${context.tr("log") ?? "Log"}",
          isUrgent: true,
          onTap: () => _launchMealLogger(context, first, plan),
        ));
      }
    }

    // B. HYDRATION
    if ((dailyLog?.hydrationLiters ?? 0) < (plan.dailyWaterGoal * 0.8) && DateTime.now().hour > 18) {
      final double remaining = plan.dailyWaterGoal - (dailyLog?.hydrationLiters ?? 0);
      actionNudges.add(_NudgeCardData(
        title: "${context.tr("hydration_check") ?? "Hydration"}",
        subtitle: "${remaining.toStringAsFixed(1)}L ${context.tr("left") ?? "left"}. ${context.tr("hydration_check") ?? "Drink up"}!",
        icon: Icons.water_drop,
        color: Colors.blue,
        btnLabel: "${context.tr("add") ?? "Add"}",
        onTap: () => _launchHydrationSheet(context, state, dailyLog, dailyLog?.hydrationLiters ?? 0),
      ));
    }

    // --- MERGE & RENDER ---
    List<_NudgeCardData> allNudges = [...actionNudges, ..._contentNudges];

    if (allNudges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tips_and_updates, size: 18, color: colorScheme.secondary),
                  const SizedBox(width: 6),
                  Text(
                      "${context.tr("daily_focus") ?? "DAILY FOCUS"}",
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: colorScheme.onSurfaceVariant
                      )
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _openDailyGoals(context),
                icon: Icon(Icons.checklist_rtl, size: 16, color: colorScheme.primary),
                label: Text(
                    "${context.tr("goals") ?? "Goals"}",
                    style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary
                    )
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index % allNudges.length),
            itemBuilder: (context, index) {
              final item = allNudges[index % allNudges.length];
              return _buildNudgeCard(context, item, index % allNudges.length, allNudges.length);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNudgeCard(BuildContext context, _NudgeCardData data, int index, int totalCount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
              data.color.withOpacity(isDark ? 0.2 : 0.1),
              theme.cardColor
            ],
            begin: Alignment.centerLeft, end: Alignment.centerRight
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2)
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
              children: [
                Text(
                    data.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface
                    )
                ),
                const SizedBox(height: 2),
                Text(
                    data.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis
                ),

                if (totalCount > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(min(totalCount, 6), (dotIndex) => Container(
                      width: 5, height: 5, margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotIndex == index ? data.color : colorScheme.outlineVariant
                      ),
                    )),
                  )
                ]
              ],
            ),
          ),
          ElevatedButton(
            onPressed: data.onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: data.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 30),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(data.btnLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (data.isUrgent) {
      return GestureDetector(
        onTap: data.onTap,
        child: RotationTransition(turns: _shakeAnimation, child: cardContent),
      );
    }
    return GestureDetector(onTap: data.onTap, child: cardContent);
  }

  void _openDailyGoals(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DailyGoalsLoggingScreen(clientId: widget.clientId)));
  }

  void _launchMealLogger(BuildContext context, DietPlanMealModel meal, ClientDietPlanModel plan) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MealDetailSheet(notifier: notifier, mealName: meal.mealName, activePlan: plan, logToEdit: null, plannedItems: meal.items));
  }

  void _launchHydrationSheet(BuildContext context, DietPlanState state, ClientLogModel? log, double current) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.clientId).notifier);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => HydrationDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: log, currentIntake: current));
  }
}