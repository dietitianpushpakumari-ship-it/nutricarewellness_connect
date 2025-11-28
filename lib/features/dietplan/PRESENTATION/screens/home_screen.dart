import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:collection/collection.dart';

// 🎯 CORE WIDGETS & SCREENS
import 'package:nutricare_connect/core/utils/dashboard_widgets.dart';
import 'package:nutricare_connect/core/utils/daily_completion_banner.dart';
import 'package:nutricare_connect/core/utils/followup_banner.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/smart_nudge_bar.dart'; // Smart Nudge
import 'package:nutricare_connect/core/utils/feature_spotlight.dart';
import 'package:nutricare_connect/core/utils/daily_wisdom_card.dart';
import 'package:nutricare_connect/core/utils/wellness_trend_card.dart';
import 'package:nutricare_connect/core/utils/profile_Screen.dart';
import 'package:nutricare_connect/core/utils/rating_dialog.dart';
import 'package:nutricare_connect/core/utils/rating_service.dart';
import 'package:nutricare_connect/core/utils/unified_insight_carousal.dart';
import 'package:nutricare_connect/core/utils/comapct_trend_grid.dart'; // Compact Trend

// 🎯 DETAIL SHEETS
import 'package:nutricare_connect/core/utils/hydration_detail_screen.dart';
import 'package:nutricare_connect/core/utils/movement_Details_sheet.dart';
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';
import 'package:nutricare_connect/core/utils/analytics_detail_screen.dart';

// 🎯 PROVIDERS & ENTITIES
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const HomeScreen({super.key, required this.client});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late AnimationController _waveController;
  Stream<StepCount>? _stepCountStream;
  int _liveSensorSteps = 0;
  bool _sensorActive = false;
  DateTime _lastSaveTime = DateTime.now().subtract(const Duration(hours: 7));
  final List<double> _milestones = [0.25, 0.50, 0.75, 1.0];

  // 🎯 Controller for Highlights Carousel
  final PageController _highlightsController = PageController(viewportFraction: 0.92);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initPedometer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSwitchDate();
    });

    Future.delayed(const Duration(seconds: 3), () async {
      final ratingService = RatingService();
      if (await ratingService.shouldAsk()) {
        if (mounted) {
          showDialog(context: context, builder: (_) => const RatingDialog());
          ratingService.markAsAsked(rated: false);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveController.dispose();
    _highlightsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _performSync(_liveSensorSteps, forceSave: true);
    }
    if (state == AppLifecycleState.resumed) {
      _checkAndSwitchDate();
    }
  }

  void _initPedometer() async {
    final bool sensorEnabled = ref.read(stepSensorEnabledProvider);
    if (!sensorEnabled) return;

    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((StepCount event) {
        if (mounted) {
          setState(() {
            _liveSensorSteps = event.steps;
            _sensorActive = true;
          });
          _throttledAutoSync(event.steps);
        }
      }).onError((e) {
        print("Pedometer Error: $e");
      });
    }
  }

  void _checkAndSwitchDate() {
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final currentState = ref.read(activeDietPlanProvider);

    if (!DateUtils.isSameDay(currentState.selectedDate, DateTime.now())) {
      notifier.selectDate(DateTime.now());
    }
  }

  void _throttledAutoSync(int totalSensorSteps) {
    _checkAndSwitchDate();
    final durationDiff = DateTime.now().difference(_lastSaveTime).inMinutes;
    if (durationDiff < 360) return;
    _performSync(totalSensorSteps);
  }

  void _performSync(int totalSensorSteps, {bool forceSave = false}) {
    if (totalSensorSteps == 0) return;

    final state = ref.read(activeDietPlanProvider);
    if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) return;

    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;
    final int calculatedDailySteps = (baseline == 0) ? 0 : totalSensorSteps - baseline;
    final int savedSteps = dailyLog?.stepCount ?? 0;

    if (state.activePlan != null && (baseline == 0 || calculatedDailySteps > savedSteps)) {
      _lastSaveTime = DateTime.now();

      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final int newBaseline = (baseline == 0) ? totalSensorSteps : baseline;
      final int newDailySteps = (baseline == 0) ? 0 : calculatedDailySteps;

      final logToSave = dailyLog ?? ClientLogModel(
        id: '',
        clientId: state.activePlan!.clientId,
        dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: DateTime.now(),
      );

      final int stepGoal = state.activePlan?.dailyStepGoal ?? 8000;
      final int calories = (newDailySteps * 0.04).round();
      int score = 0;

      if (stepGoal > 0) score += ((newDailySteps / stepGoal) * 50).round().clamp(0, 50);
      final int completedTasks = dailyLog?.completedMandatoryTasks.length ?? 0;
      score += (completedTasks * 10).clamp(0, 50);

      _checkAndShowStepAchievement(savedSteps, newDailySteps, stepGoal);

      final updatedLog = logToSave.copyWith(
        sensorStepsBaseline: newBaseline,
        stepCount: newDailySteps,
        stepGoal: stepGoal,
        caloriesBurned: calories,
        activityScore: score,
      );

      notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
    }
  }

  void _checkAndShowStepAchievement(int previousSteps, int currentSteps, int stepGoal) {
    if (stepGoal == 0) return;
    for (double milestone in _milestones) {
      int threshold = (stepGoal * milestone).toInt();
      if (previousSteps < threshold && currentSteps >= threshold) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showVictoryDialog(milestone);
        });
        break;
      }
    }
  }

  void _showVictoryDialog(double milestone) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Goal Reached!"), content: Text("You hit ${(milestone*100).toInt()}% of your step goal.")));
  }

  // --- HANDLERS ---
  void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel activePlan, ClientLogModel? dailyLog) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Choose a Mode", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPresetTile(ctx, "Focus & Clarity", "Box Breathing (4-4-4-4)", Icons.crop_square, Colors.teal, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.box)),
            _buildPresetTile(ctx, "Sleep & Anxiety", "4-7-8 Relaxing Breath", Icons.nightlight_round, Colors.indigo, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.relax)),
            _buildPresetTile(ctx, "Energy Boost", "Rapid Awakening", Icons.bolt, Colors.orange, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.energy)),
          ],
        ),
      ),
    );
  }

  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel plan, ClientLogModel? log, BreathingConfig config) {
    Navigator.pop(context);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: config));
  }

  Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _quickAddWater(DietPlanNotifier notifier, dynamic activePlan, ClientLogModel? log, double current) async {
    try {
      final newTotal = (current + 0.25).clamp(0.0, 10.0);
      final logToSave = log ?? ClientLogModel(
        id: '',
        clientId: activePlan.clientId,
        dietPlanId: activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: DateTime.now(),
      );
      final updatedLog = logToSave.copyWith(hydrationLiters: newTotal);
      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('+250ml Added!'), duration: Duration(milliseconds: 800), backgroundColor: Colors.blue));
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);

    final ClientLogModel? dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    // 🎯 DATA BINDING
    final double waterIntake = dailyLog?.hydrationLiters ?? 0.0;
    final double waterGoal = state.activePlan?.dailyWaterGoal ?? 3.0;

    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;
    final int savedSteps = dailyLog?.stepCount ?? 0;
    final int displaySteps = (_sensorActive && DateUtils.isSameDay(state.selectedDate, DateTime.now()) && baseline > 0 && _liveSensorSteps >= baseline)
        ? _liveSensorSteps - baseline
        : savedSteps;
    final int stepGoal = state.activePlan?.dailyStepGoal ?? 8000;

    final double sleepHours = dailyLog?.totalSleepDurationHours ?? 0.0;
    final int sleepScore = dailyLog?.sleepScore ?? 0;
    final int breathMin = dailyLog?.breathingMinutes ?? 0;

    double waterScore = (waterIntake / waterGoal).clamp(0.0, 1.0) * 100;
    double stepScore = (displaySteps / stepGoal).clamp(0.0, 1.0) * 100;
    double sleepCalc = (sleepHours / (state.activePlan?.dailySleepGoal ?? 7.0)).clamp(0.0, 1.0) * 100;
    int dailyScore = ((waterScore + stepScore + sleepCalc) / 3).round();

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: Stack(
          children: [
            // 🎯 1. SUBTLE BACKGROUND GLOW (Fixed Decoration)
            Positioned(
              top: -100, right: -100,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // 🎯 FIX: Replaced 'blurRadius' property with 'boxShadow'
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.15),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            CustomScrollView(
              slivers: [
                // 2. PREMIUM HEADER
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.5)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Hello, ${widget.client.name?.split(' ').first ?? 'Friend'}",
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
                            ),
                          ],
                        ),

                        // Profile Avatar
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.teal.withOpacity(0.3), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.teal.shade50,
                              backgroundImage: widget.client.photoUrl != null ? NetworkImage(widget.client.photoUrl!) : null,
                              child: widget.client.photoUrl == null
                                  ? Text(widget.client.name?[0] ?? 'U', style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🎯 REMOVED: DailyCompletionBanner (Consolidated into Nudge Bar)

                // 3. FOLLOW UP (Appointments)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FollowUpBanner(clientId: widget.client.id),
                  ),
                ),

                // 4. SMART NUDGES (Focus Rail)
                SliverToBoxAdapter(
                  child: SmartNudgeBar(clientId: widget.client.id),
                ),

                // 5. BENTO GRID (Compact)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.4,
                    children: [
                      MiniHydrationCard(
                        currentLiters: waterIntake,
                        goalLiters: waterGoal,
                        waveAnimation: _waveController,
                        onTap: () {
                          if (state.activePlan == null) return;
                          showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => HydrationDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyLog, currentIntake: waterIntake));
                        },
                        onQuickAdd: () {
                          if (state.activePlan == null) return;
                          _quickAddWater(notifier, state.activePlan!, dailyLog, waterIntake);
                        },
                      ),
                      MiniStepCard(
                        steps: displaySteps,
                        goal: stepGoal,
                        onTap: () {
                          if (state.activePlan == null) return;
                          showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MovementDetailSheet.withSteps(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyLog, currentSteps: displaySteps));
                        },
                      ),
                      MiniSleepCard(
                        hours: sleepHours,
                        score: sleepScore,
                        onTap: () {
                          if (state.activePlan == null) return;
                          showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => SleepDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyLog));
                        },
                      ),
                      MiniBreathingCard(
                        minutesLogged: breathMin,
                        onTap: () {
                          if (state.activePlan == null) return;
                          _showBreathingMenu(context, notifier, state.activePlan!, dailyLog);
                        },
                      ),
                    ],
                  ),
                ),

                // 🎯 6. COMPACT INSIGHTS & TRENDS
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      children: [
                        // A. Weekly Pulse (Slim)
                        CompactTrendCard(clientId: widget.client.id),

                        const SizedBox(height: 16),

                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}