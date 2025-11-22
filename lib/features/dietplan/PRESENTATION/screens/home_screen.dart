import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/daily_wisdom_card.dart';
import 'package:nutricare_connect/core/utils/dashboard_widgets.dart';
import 'package:nutricare_connect/core/utils/hydration_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';
import 'package:nutricare_connect/core/utils/movement_Details_sheet.dart';
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';
import 'package:nutricare_connect/core/utils/wellness_trend_card.dart' show WellnessTrendsCard;
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/breathing_excercise_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/progress_report_card.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/sleep_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/water_quick_add_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const HomeScreen({super.key, required this.client});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  // --- Animations ---
  late AnimationController _waveController;

  // --- Pedometer State ---
  Stream<StepCount>? _stepCountStream;
  int _liveSensorSteps = 0;
  bool _sensorActive = false;

  // --- Sync Logic Variables ---
  // 🎯 FIX 1: Initialize to 7 hours ago so the first sync happens immediately on open
  DateTime _lastSaveTime = DateTime.now().subtract(const Duration(hours: 7));
  int _lastSavedSensorSteps = 0;

  // --- Milestone Logic ---
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveController.dispose();
    super.dispose();
  }

  // 🎯 LIFECYCLE: Force Save on Exit (Crucial for long intervals)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      print("App minimizing. Force saving steps...");
      _performSync(_liveSensorSteps, forceSave: true);
    }
    if (state == AppLifecycleState.resumed) {
      _checkAndSwitchDate();
    }
  }
// 🎯 NEW: Show the Breathing Mode Selection Menu
  void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel activePlan, ClientLogModel? dailyLog) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Choose a Mode", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            _buildPresetTile(
              ctx,
              "Focus & Clarity",
              "Box Breathing (4-4-4-4)",
              Icons.crop_square,
              Colors.teal,
                  () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.box),
            ),
            _buildPresetTile(
              ctx,
              "Sleep & Anxiety",
              "4-7-8 Relaxing Breath",
              Icons.nightlight_round,
              Colors.indigo,
                  () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.relax),
            ),
            _buildPresetTile(
              ctx,
              "Energy Boost",
              "Rapid Awakening",
              Icons.bolt,
              Colors.orange,
                  () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.energy),
            ),
          ],
        ),
      ),)
    );
  }

  // 🎯 Helper to launch the sheet with specific config
  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel plan, ClientLogModel? log, BreathingConfig config) {
    Navigator.pop(context); // Close the menu
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BreathingDetailSheet(
        notifier: notifier,
        activePlan: plan,
        dailyLog: log,
        config: config, // Pass the selected config
      ),
    );
  }

  // 🎯 Helper for the menu tiles
  Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
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
      print("New Day Detected. Switching Dashboard to Today.");
      notifier.selectDate(DateTime.now());
    }
  }

  // 🎯 LOGIC: 6-Hour Throttling
  void _throttledAutoSync(int totalSensorSteps) {
    _checkAndSwitchDate();

    final durationDiff = DateTime.now().difference(_lastSaveTime).inMinutes;

    // 🎯 FIX 2: Only save if > 360 minutes (6 hours) have passed
    if (durationDiff < 360) {
      return; // Skip DB write, UI is already updated via setState
    }

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

    // Sync if:
    // 1. New Day (baseline is 0)
    // 2. New Steps > Saved Steps (AND timer expired or force save)
    if (state.activePlan != null && (baseline == 0 || calculatedDailySteps > savedSteps)) {

      _lastSaveTime = DateTime.now();
      _lastSavedSensorSteps = totalSensorSteps;

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

      print("Syncing Steps to Cloud (6hr Check): $newDailySteps");
      notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
    }
  }

  // ... (Keep _checkAndShowStepAchievement and _showVictoryDialog logic unchanged) ...
  // ... (Keep build method logic unchanged) ...

  // ⚠️ IMPORTANT: Re-paste the _checkAndShowStepAchievement and _showVictoryDialog methods here
  // if you are replacing the entire class, otherwise they will be missing.
  // I've included the headers above to remind you.

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
    // ... (Your existing elastic pop-up code) ...
    String title;
    String subtitle;
    String emoji;
    Color color;
    Color bgStart;
    Color bgEnd;

    if (milestone == 0.25) {
      title = "On the Move!";
      subtitle = "25% goal reached.";
      emoji = "👟";
      color = Colors.blue.shade700;
      bgStart = Colors.blue.shade50;
      bgEnd = Colors.white;
    } else if (milestone == 0.50) {
      title = "Halfway There!";
      subtitle = "50% done. Keep it up!";
      emoji = "🔥";
      color = Colors.orange.shade700;
      bgStart = Colors.orange.shade50;
      bgEnd = Colors.white;
    } else if (milestone == 0.75) {
      title = "So Close!";
      subtitle = "75% crushed.";
      emoji = "🚀";
      color = Colors.deepPurple.shade700;
      bgStart = Colors.deepPurple.shade50;
      bgEnd = Colors.white;
    } else {
      title = "Goal Smashed!";
      subtitle = "100% Complete. Amazing job!";
      emoji = "🏆";
      color = Colors.green.shade800;
      bgStart = Colors.green.shade100;
      bgEnd = Colors.white;
    }

    showGeneralDialog(
      context: context,
      barrierLabel: "Victory",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curvedValue = Curves.elasticOut.transform(anim.value);

        return Transform.scale(
          scale: curvedValue,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgStart, bgEnd],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 16),
                    Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 8),
                    Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text("Awesome!", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (Paste your existing build method here - no changes needed inside build) ...
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);

    final ClientLogModel? dailyLog = state.dailyLogs.firstWhereOrNull(
            (log) => log.mealName == 'DAILY_WELLNESS_CHECK'
    );

    final double waterIntake = dailyLog?.hydrationLiters ?? 0.0;
    final double waterGoal = 3.0;

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
    double stepScore = (displaySteps / (stepGoal == 0 ? 8000 : stepGoal)).clamp(0.0, 1.0) * 100;
    double sleepCalc = (sleepHours / 8.0).clamp(0.0, 1.0) * 100;
    int dailyScore = ((waterScore + stepScore + sleepCalc) / 3).round();

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Hello, ${widget.client.name?.split(' ').first ?? 'Client'}",
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                        ),
                      ],
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: dailyScore / 100,
                          backgroundColor: Colors.grey.shade200,
                          color: dailyScore > 70 ? Colors.green : Colors.orange,
                          strokeWidth: 6,
                        ),
                        Text(
                          "$dailyScore",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  MiniHydrationCard(
                    currentLiters: waterIntake,
                    goalLiters: waterGoal,
                    waveAnimation: _waveController,
                    onTap: () {
                      if (state.activePlan == null) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => HydrationDetailSheet(
                          notifier: notifier,
                          activePlan: state.activePlan!,
                          dailyLog: dailyLog,
                          currentIntake: waterIntake,
                        ),
                      );
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
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => MovementDetailSheet.withSteps(
                          notifier: notifier,
                          activePlan: state.activePlan!,
                          dailyLog: dailyLog,
                          currentSteps: displaySteps,
                        ),
                      );
                    },
                  ),
      
                  MiniSleepCard(
                    hours: sleepHours,
                    score: sleepScore,
                    onTap: () {
                      if (state.activePlan == null) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SleepDetailSheet(
                          notifier: notifier,
                          activePlan: state.activePlan!,
                          dailyLog: dailyLog,
                        ),
                      );
                    },
                  ),

                  // D. Breathing
                  MiniBreathingCard(
                    minutesLogged: breathMin,
                    onTap: () {
                      if (state.activePlan == null) return;
                      // 🎯 CALL THE NEW MENU
                      _showBreathingMenu(context, notifier, state.activePlan!, dailyLog);
                    },
                  ),
                ],
              ),
            ),
      
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text("Today's Insight", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    DailyWisdomCard(clientId: widget.client.id),
                    const SizedBox(height: 20),
                    WellnessTrendsCard(clientId: widget.client.id),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
    } catch (e) {
    }
  }
}