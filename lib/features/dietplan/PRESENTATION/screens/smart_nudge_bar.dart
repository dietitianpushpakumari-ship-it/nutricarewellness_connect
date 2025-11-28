import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For DateFormat
import 'package:nutricare_connect/core/utils/daily_log_logging_screen.dart';
import 'package:nutricare_connect/core/utils/master_data_provider.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:collection/collection.dart';

// Sheets & Data
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';
import 'package:nutricare_connect/core/utils/meal_detail_sheet.dart';
import 'package:nutricare_connect/core/utils/hydration_detail_screen.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_registry.dart'; // For Feature Spotlight

class _NudgeCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String btnLabel;
  final bool isUrgent;
  final String? fullBody; // For Knowledge Cards

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

  // 🎯 CONTENT STATE
  List<_NudgeCardData> _contentNudges = []; // Wisdom + Feature
  bool _isLoadingContent = true;

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

    _loadDailyContent(); // 🎯 Fetch Knowledge & Features
    _startTimer();
  }

  // 🎯 NEW: FETCH DAILY WISDOM & FEATURE
  Future<void> _loadDailyContent() async {
    List<_NudgeCardData> loaded = [];

    // 1. CALCULATE DAY SEED (For rotation)
    final int dayOfYear = int.parse(DateFormat("D").format(DateTime.now()));

    // 2. FEATURE SPOTLIGHT (1 Card)
    if (WellnessRegistry.allTools.isNotEmpty) {
      final int featureIndex = dayOfYear % WellnessRegistry.allTools.length;
      final WellnessTool tool = WellnessRegistry.allTools[featureIndex];

      loaded.add(_NudgeCardData(
        title: "Try ${tool.title}",
        subtitle: tool.subtitle,
        icon: tool.icon,
        color: tool.color,
        btnLabel: "Open",
        onTap: () {
          // Basic nav hint - ideally route via home screen handler or deep link
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opening ${tool.title}...")));
        },
      ));
    }

    // 3. DAILY WISDOM (5 Cards)
    try {
      final query = await FirebaseFirestore.instance
          .collection('wellness_library')
          .limit(20) // Fetch pool
          .get();

      if (query.docs.isNotEmpty) {
        int count = query.docs.length;
        // Pick 5 items starting from daySeed
        for (int i = 0; i < 5; i++) {
          int index = (dayOfYear + i) % count;
          final data = query.docs[index].data();

          final type = data['type']?.toString().toUpperCase() ?? 'TIP';
          final title = data['title'] ?? '';
          final body = data['body'] ?? '';

          Color color = Colors.teal;
          IconData icon = Icons.lightbulb_outline;
          if (type == 'MYTH') { color = Colors.purple; icon = Icons.help_outline; }
          else if (type == 'WARNING') { color = Colors.orange; icon = Icons.warning_amber_rounded; }

          loaded.add(_NudgeCardData(
            title: "Daily $type",
            subtitle: title,
            fullBody: body,
            icon: icon,
            color: color,
            btnLabel: "Read",
            onTap: () => _showWisdomDialog(type, title, body, color, icon),
          ));
        }
      } else {
        // Fallback if empty DB
        loaded.add(_NudgeCardData(
          title: "Daily Wisdom",
          subtitle: "Drink water before meals to aid digestion.",
          icon: Icons.water_drop,
          color: Colors.blue,
          btnLabel: "Read",
          onTap: () {},
        ));
      }
    } catch (e) {
      print("Error loading wisdom: $e");
    }

    if (mounted) {
      setState(() {
        _contentNudges = loaded;
        _isLoadingContent = false;
      });
    }
  }

  void _showWisdomDialog(String type, String title, String body, Color color, IconData icon) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got it"))
        ],
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 8), (Timer timer) {
      // We check the *total* list length dynamically in build,
      // but here we just trigger a safe next page.
      if (!_pageController.hasClients) return;

      // Determine total pages (Action + Content)
      // This is approximate since we don't have the exact 'activeNudges' list here easily.
      // We rely on the controller's knowledge or just animate.
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutQuart,
      ).catchError((e) {
        // If we hit end, jump to 0 (PageView loop workaround)
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
    final state = ref.watch(activeDietPlanProvider);
    final masterMealsAsync = ref.watch(masterMealNamesProvider);
    final ClientDietPlanModel? plan = state.activePlan;
    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    if (plan == null) return const SizedBox.shrink();

    // --- 1. GENERATE ACTION NUDGES (Priority 1) ---
    List<_NudgeCardData> actionNudges = [];

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

        final config = masterMeals.firstWhereOrNull((m) => m.id == meal.mealNameId || m.enName == meal.mealName);
        if (config != null && config.startTime != null) {
          final parts = config.startTime!.split(':');
          final startDouble = int.parse(parts[0]) + int.parse(parts[1]) / 60.0;
          if (nowDouble >= startDouble) overdueMeals.add(meal);
        }
      }
      if (overdueMeals.isNotEmpty) {
        final first = overdueMeals.first;
        actionNudges.add(_NudgeCardData(
          title: "Meal Time!",
          subtitle: overdueMeals.length > 1 ? "Log ${overdueMeals.length} meals pending." : "Time for ${first.mealName}.",
          icon: Icons.restaurant,
          color: Colors.red,
          btnLabel: "Log",
          onTap: () => _launchMealLogger(context, first, plan),
          isUrgent: true,
        ));
      }
    }

    // B. HYDRATION
    if ((dailyLog?.hydrationLiters ?? 0) < plan.dailyWaterGoal) {
      final double remaining = plan.dailyWaterGoal - (dailyLog?.hydrationLiters ?? 0);
      actionNudges.add(_NudgeCardData(
        title: "Hydration",
        subtitle: "${remaining.toStringAsFixed(1)}L left to hit goal.",
        icon: Icons.water_drop,
        color: Colors.blue,
        btnLabel: "Add",
        onTap: () => _launchHydrationSheet(context, state, dailyLog, dailyLog?.hydrationLiters ?? 0),
      ));
    }

    // C. MOVEMENT
    if ((dailyLog?.stepCount ?? 0) < plan.dailyStepGoal) {
      actionNudges.add(_NudgeCardData(
        title: "Steps",
        subtitle: "${plan.dailyStepGoal - (dailyLog?.stepCount ?? 0)} steps remaining.",
        icon: Icons.directions_run,
        color: Colors.orange,
        btnLabel: "Check",
        onTap: () {},
      ));
    }

    // D. SLEEP (Contextual)
    final int hour = DateTime.now().hour;
    if ((dailyLog?.sleepQualityRating ?? 0) == 0 && (hour < 10 || hour > 20)) {
      actionNudges.add(_NudgeCardData(
        title: "Sleep Log",
        subtitle: "How did you sleep?",
        icon: Icons.bedtime,
        color: Colors.indigo,
        btnLabel: "Log",
        onTap: () => _launchSleep(context, state, dailyLog),
      ));
    }

    // --- 2. MERGE LISTS ---
    // Order: Urgent Actions -> Feature -> Tips
    List<_NudgeCardData> allNudges = [...actionNudges, ..._contentNudges];

    if (allNudges.isEmpty) return const SizedBox.shrink();

    // --- 3. RENDER ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tips_and_updates, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  const Text("DAILY FOCUS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
                ],
              ),
              TextButton.icon(
                onPressed: () => _openDailyGoals(context),
                icon: const Icon(Icons.checklist_rtl, size: 16, color: Colors.indigo),
                label: const Text("Goals", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Carousel
        SizedBox(
          height: 120, // Adjusted height
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              // Handle infinite loop via modulo if desired, or simple list for now
              setState(() => _currentPage = index % allNudges.length);
            },
            // Use a large number to simulate infinite scrolling or just standard list
            itemBuilder: (context, index) {
              final item = allNudges[index % allNudges.length];
              return _buildNudgeCard(item, index % allNudges.length, allNudges.length);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNudgeCard(_NudgeCardData data, int index, int totalCount) {
    Widget cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [data.color.withOpacity(0.1), Colors.white],
            begin: Alignment.centerLeft, end: Alignment.centerRight
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withOpacity(0.2), width: 1),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: data.color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(data.icon, color: data.color.withOpacity(0.9), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(data.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(data.subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),

                if (totalCount > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(min(totalCount, 6), (dotIndex) => Container(
                      width: 5, height: 5, margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotIndex == index ? data.color : Colors.grey.shade300
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

  // --- HANDLERS ---
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

  void _launchBreathing(BuildContext context, DietPlanState state, ClientLogModel? log) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => BreathingDetailSheet(notifier: ref.read(dietPlanNotifierProvider(widget.clientId).notifier), activePlan: state.activePlan!, dailyLog: log, config: BreathingConfig.energy));
  }

  void _launchSleep(BuildContext context, DietPlanState state, ClientLogModel? log) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => SleepDetailSheet(notifier: ref.read(dietPlanNotifierProvider(widget.clientId).notifier), activePlan: state.activePlan!, dailyLog: log));
  }

  Future<void> _markHabitDone(WidgetRef ref, ClientDietPlanModel plan, ClientLogModel? log, List<String> currentCompleted, String habit) async {
    // Simplified for this snippet - logic same as before
  }
}