import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/core/theme_provider.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

// 🎯 WIDGETS
import 'package:nutricare_connect/new/dashboard/dashboard_widgets.dart';
import 'package:nutricare_connect/core/utils/followup_banner.dart';
import 'package:nutricare_connect/new/home/smart_nudge_bar.dart';
import 'package:nutricare_connect/new/dashboard/profile_Screen.dart';
import 'package:nutricare_connect/core/utils/rating_dialog.dart';
import 'package:nutricare_connect/core/utils/rating_service.dart';
import 'package:nutricare_connect/new/dashboard/comapct_trend_grid.dart';

// 🎯 DETAIL SHEETS
import 'package:nutricare_connect/new/dietplan/hydration_detail_screen.dart';
import 'package:nutricare_connect/new/dietplan/movement_Details_sheet.dart';
import 'package:nutricare_connect/new/dietplan/sleep_details_screen.dart';
import 'package:nutricare_connect/new/wellnesshub/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';
import 'package:nutricare_connect/new/dashboard/analytics_detail_screen.dart';

// 🎯 PROVIDERS & ENTITIES
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/new/service/client_service.dart';

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
        debugPrint("Pedometer Error: $e");
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

  // 🎯 ATOMIC SYNC: Uses updateDailyRecord map logic
  void _performSync(int totalSensorSteps, {bool forceSave = false}) {
    if (totalSensorSteps == 0) return;

    final state = ref.read(activeDietPlanProvider);
    if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) return;

    // 🎯 NEW: Read directly from dailyRecord instead of searching a list
    final dailyRecord = state.dailyRecord;
    final int baseline = dailyRecord?.sensorStepsBaseline ?? 0;
    final int calculatedDailySteps = (baseline == 0) ? 0 : totalSensorSteps - baseline;
    final int savedSteps = dailyRecord?.stepCount ?? 0;

    if (state.activePlan != null && (baseline == 0 || calculatedDailySteps > savedSteps)) {
      _lastSaveTime = DateTime.now();

      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final int newBaseline = (baseline == 0) ? totalSensorSteps : baseline;
      final int newDailySteps = (baseline == 0) ? 0 : calculatedDailySteps;

      final int stepGoal = state.activePlan?.dailyStepGoal ?? 8000;
      final int calories = (newDailySteps * 0.04).round();
      int score = 0;

      if (stepGoal > 0) score += ((newDailySteps / stepGoal) * 50).round().clamp(0, 50);
      final int completedTasks = dailyRecord?.completedMandatoryTasks.length ?? 0;
      score += (completedTasks * 10).clamp(0, 50);

      _checkAndShowStepAchievement(savedSteps, newDailySteps, stepGoal);

      // 🎯 NEW: Atomic Map Update
      final updateData = {
        'sensorStepsBaseline': newBaseline,
        'stepCount': newDailySteps,
        'stepGoal': stepGoal,
        'caloriesBurned': calories,
        'activityScore': score,
      };

      notifier.updateDailyRecord(data: updateData);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.2))
          ),
          title: Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: isDark ? Colors.amberAccent : Colors.amber, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text("Goal Reached!", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
              "You hit ${(milestone*100).toInt()}% of your step goal.",
              style: TextStyle(color: theme.hintColor)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Awesome!", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            )
          ],
        )
    );
  }

  // --- HANDLERS ---

  // 🎯 ATOMIC FIX: Passes dailyRecord to sheets instead of finding logs
  void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel activePlan, ClientLogModel? dailyRecord, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr("lbl_choose_mode"), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(height: 20),
            _buildPresetTile(ctx, context.tr("focus_and_clarity"), context.tr("lbl_box_breathing"), Icons.crop_square_rounded, Colors.teal, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.box), theme, colorScheme),
            _buildPresetTile(ctx, context.tr("sleep_and_anxiety"), context.tr("lbl_relax_breath"), Icons.nightlight_round, Colors.indigo, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.relax), theme, colorScheme),
            _buildPresetTile(ctx, context.tr("lbl_energy_boost"), context.tr("lbl_rapid_awakening"), Icons.bolt_rounded, Colors.orange, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.energy), theme, colorScheme),
          ],
        ),
      ),
    );
  }

  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel plan, ClientLogModel? dailyRecord, BreathingConfig config) {
    Navigator.pop(context);
    showModalBottomSheet(isDismissible:false,context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyRecord, config: config));
  }

  Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, ThemeData theme, ColorScheme colorScheme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color)
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.hintColor)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.iconTheme.color?.withOpacity(0.5)),
      onTap: onTap,
    );
  }

  // 🎯 ATOMIC QUICK ADD WATER
  Future<void> _quickAddWater(DietPlanNotifier notifier, double current) async {
    try {
      final newTotal = (current + 0.25).clamp(0.0, 10.0);

      await notifier.updateDailyRecord(data: {
        'hydrationLiters': newTotal,
      });

      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('+250ml Added!'), duration: const Duration(milliseconds: 800), backgroundColor: theme.colorScheme.primary));
      }
    } catch (e) {
      debugPrint("Failed to add water: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);

    // 🎯 NEW: Single Source of Truth
    final dailyRecord = state.dailyRecord;

    // 🎯 Read top-level properties directly from the record
    final double waterIntake = dailyRecord?.hydrationLiters ?? 0.0;
    final double waterGoal = state.activePlan?.dailyWaterGoal ?? 3.0;

    final int baseline = dailyRecord?.sensorStepsBaseline ?? 0;
    final int savedSteps = dailyRecord?.stepCount ?? 0;
    final int displaySteps = (_sensorActive && DateUtils.isSameDay(state.selectedDate, DateTime.now()) && baseline > 0 && _liveSensorSteps >= baseline)
        ? _liveSensorSteps - baseline
        : savedSteps;
    final int stepGoal = state.activePlan?.dailyStepGoal ?? 8000;

    final double sleepHours = dailyRecord?.totalSleepDurationHours ?? 0.0;
    final int sleepScore = dailyRecord?.sleepScore ?? 0;
    final int breathMin = dailyRecord?.breathingMinutes ?? 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: -150, right: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(isDark ? 0.15 : 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -150,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondary.withOpacity(isDark ? 0.15 : 0.2),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.6))
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${context.tr("dash_hello")}, ${widget.client.name?.split(' ').first ?? 'Friend'}",
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.person_outline_rounded, color: colorScheme.primary, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FollowUpBanner(clientId: widget.client.id),
                ),
              ),

              SliverToBoxAdapter(
                child: SmartNudgeBar(clientId: widget.client.id),
              ),

              // 🎯 ATOMIC DATA INJECTION TO BENTO CARDS
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.45,
                  children: [
                    MiniHydrationCard(
                      currentLiters: waterIntake, goalLiters: waterGoal, waveAnimation: _waveController,
                      onTap: () => showModalBottomSheet(isDismissible:false,context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => HydrationDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord, currentIntake: waterIntake)),
                      onQuickAdd: () => _quickAddWater(notifier, waterIntake),
                    ),
                    MiniStepCard(
                      steps: displaySteps, goal: stepGoal,
                      onTap: () => showModalBottomSheet(isDismissible:false,context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MovementDetailSheet.withSteps(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord, currentSteps: displaySteps)),
                    ),
                    MiniSleepCard(
                      hours: sleepHours, score: sleepScore,
                      onTap: () => showModalBottomSheet(isDismissible:false,context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => SleepDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord)),
                    ),
                    MiniBreathingCard(
                      minutesLogged: breathMin,
                      onTap: () => _showBreathingMenu(context, notifier, state.activePlan!, dailyRecord, theme, colorScheme, isDark),
                    ),
                  ],
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                sliver: SliverToBoxAdapter(
                  child: CompactTrendCard(clientId: widget.client.id),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
            ],
          ),
        ],
      ),
    );
  }
}