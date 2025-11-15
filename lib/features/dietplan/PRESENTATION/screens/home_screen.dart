import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/wave_clipper.dart' hide WaveClipper;
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/animated_step_meter.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/breathing_excercise_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/daily_wellness_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/female_body_clipper.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/human_body_clipper.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/male_body_clipper.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/progress_report_card.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/sleep_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/water_quick_add_model.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/wave_clipper.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const HomeScreen({required this.client});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {

  // 🎯 1. Controller for the continuous wave animation
  late AnimationController _waveController;
  late AnimationController _stepMeterController;
  Stream<StepCount>? _stepCountStream;
  int _liveSensorSteps = 0; // Live steps from sensor since app opened
  bool _sensorActive = false;
  late bool _isMaleFigure;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // How long one wave cycle takes
    )..repeat(); // 🎯 Make it loop forever
    _stepMeterController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _isMaleFigure = (widget.client.gender?.toLowerCase() ?? 'male') != 'female';
    _initPedometer();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _stepMeterController.dispose();
    super.dispose();
  }

  void _initPedometer() async {
    final bool sensorEnabled = ref.read(stepSensorEnabledProvider);
    if (!sensorEnabled) return;

    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((StepCount event) {
        if (mounted) {
          setState(() {
            _liveSensorSteps = event.steps; // Update live TOTAL steps
          });
          // 🎯 Auto-sync data to save progress and set baseline
          _autoSyncSteps(event.steps);
        }
      });
    }
  }


  void _autoSyncSteps(int totalSensorSteps) {
    // We use ref.read here because this is a callback
    final state = ref.read(activeDietPlanProvider);
    // 🎯 We only auto-sync for TODAY'S date
    if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) return;

    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;
    final int calculatedDailySteps = (baseline == 0) ? 0 : totalSensorSteps - baseline;
    final int savedSteps = dailyLog?.stepCount ?? 0;

    // Only save if...
    // 1. The baseline is NOT set (first sync of the day)
    // 2. OR the new calculated steps are higher than what's saved
    if (state.activePlan != null && (baseline == 0 || calculatedDailySteps > savedSteps)) {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);

      final int newBaseline = (baseline == 0) ? totalSensorSteps : baseline;
      final int newDailySteps = (baseline == 0) ? 0 : calculatedDailySteps;

      final logToSave = dailyLog ?? ClientLogModel(
        id: '', clientId: state.activePlan!.clientId, dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'],
        date: notifier.state.selectedDate,
      );

      final int stepGoal = state.activePlan?.dailyStepGoal ?? 8000;
      final int calories = (newDailySteps * 0.04).round();
      int score = 0;
      if (stepGoal > 0) {
        score += ((newDailySteps / stepGoal) * 50).round().clamp(0, 50);
      }
      final int completedTasks = dailyLog?.completedMandatoryTasks.length ?? 0;
      score += (completedTasks * 10).clamp(0, 50);

      final updatedLog = logToSave.copyWith(
        sensorStepsBaseline: newBaseline, // 🎯 Save the baseline
        stepCount: newDailySteps,        // 🎯 Save the calculated daily steps
        stepGoal: stepGoal,
        caloriesBurned: calories,
        activityScore: score,
      );

      notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
    }
  }
  @override
  Widget build(BuildContext context) {
    // 1. Watch the date-sensitive provider
    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);

    final ClientLogModel? dailyWellnessLog = state.dailyLogs.firstWhereOrNull(
            (log) => log.mealName == 'DAILY_WELLNESS_CHECK'
    );

    // --- Data Extraction ---
    final double currentIntake = dailyWellnessLog?.hydrationLiters ?? 0.0;
    const double goalLiters = 3.0;



    // 🎯 CRITICAL FIX: Calculate daily steps for display
    final int baseline = dailyWellnessLog?.sensorStepsBaseline ?? 0;
    final int savedSteps = dailyWellnessLog?.stepCount ?? 0;

    // If sensor is active AND today is selected AND baseline is set, use live steps.
    // Otherwise, just show what's saved in the database for that day.
    final bool isToday = DateUtils.isSameDay(state.selectedDate, DateTime.now());

    final int displaySteps = (_sensorActive && isToday && baseline > 0 && _liveSensorSteps >= baseline)
        ? _liveSensorSteps - baseline
        : savedSteps;

    final int stepGoal = state.activePlan?.dailyStepGoal ?? 8000;

    final weeklyHistoryAsync = ref.watch(weeklyLogHistoryProvider(widget.client.id));

    if (state.isLoading && state.activePlan == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildGreetingCard(context, widget.client),
        const SizedBox(height: 20),
        _buildDateSelector(context, notifier, state.selectedDate),
        const SizedBox(height: 20),
        _buildStepTracker(
            context,
            displaySteps,
            stepGoal,
            _stepMeterController,
           // weeklyHistoryAsync,
                () {
              final navBarState = context.findAncestorStateOfType<ClientDashboardScreenState>();
              navBarState?.onItemTapped(2); // Navigate to Tab 2
            }
        ),
        const SizedBox(height: 20),

        _buildSleepTracker(context, dailyWellnessLog, weeklyHistoryAsync, () {
          if (state.activePlan == null) return;
          showDialog(
              context: context,
              builder: (_) => SleepEntryDialog(
                notifier: notifier,
                activePlan: state.activePlan!,
                dailyMetricsLog: dailyWellnessLog,
              )
          );
        }),
        const SizedBox(height: 20),

        _buildHydrationTracker(context, currentIntake, goalLiters, _waveController, _isMaleFigure, () {
          if (state.activePlan == null) return;
          showDialog(
              context: context,
              builder: (_) => WaterQuickAddModal(
                notifier: notifier,
                activePlan: state.activePlan!,
                dailyMetricsLog: dailyWellnessLog,
                currentIntake: currentIntake,
              )
          );
        }),

        // 🎯 NEW: Toggle Button for Hydration Figure
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isMaleFigure = !_isMaleFigure;
                });
              },
              icon: Icon(_isMaleFigure ? Icons.female : Icons.male, size: 18),
              label: Text(_isMaleFigure ? 'Show Female Figure' : 'Show Male Figure'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.secondary,
                side: BorderSide(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)),
              ),
            ),
          ),
        ),


        const SizedBox(height: 20),

        // 🎯 NEW: Breathing Exercise Card
        _buildBreathingExerciseCard(context, dailyWellnessLog, () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BreathingExerciseScreen(client: widget.client))
          );
        }),
        ProgressReportCard(clientId: widget.client.id),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBreathingExerciseCard(BuildContext context, ClientLogModel? dailyLog, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    final minutesLogged = dailyLog?.breathingMinutes ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        color: const Color(0xFFF0F4F8), // A light, calm blue-grey
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.self_improvement, color: colorScheme.secondary, size: 52),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'MINDFUL BREATHING',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54)
                    ),
                    Text(
                        'Start Session',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold
                        )
                    ),
                    const SizedBox(height: 10),
                    Text(
                        minutesLogged > 0
                            ? 'You logged $minutesLogged minutes today.'
                            : 'Tap here to start a session.',
                        style: const TextStyle(color: Colors.black87)
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildStepTracker(
      BuildContext context,
      int currentSteps,
      int goalSteps,
      Animation<double> animation,
     // AsyncValue<Map<DateTime, List<ClientLogModel>>> weeklyHistory,
      VoidCallback onLogSteps
      ) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile( // 🎯 Made collapsible
        leading: Icon(Icons.directions_walk, color: Theme.of(context).colorScheme.primary, size: 30),
        title: Text('DAILY MOVEMENT', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text('$currentSteps / $goalSteps Steps', style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: IconButton( // 🎯 Add separate tap for navigation
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: onLogSteps,
          tooltip: 'Log Activity',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // 🎯 The animated "battery" meter
                AnimatedStepMeter(
                  currentSteps: currentSteps,
                  goalSteps: goalSteps,
                  continuousAnimation: animation,
                ),
                const SizedBox(height: 10),
                const Text(
                  '"The journey of a thousand miles begins with a single step."',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 20),

                // 🎯 NEW: Weekly Progress Graph
            //    Text('Your 7-Day Progress (Steps & Cals)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              //  const SizedBox(height: 16),
                //_buildWeeklyActivityChart(context, weeklyHistory, stepGoal),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSleepTracker(
      BuildContext context,
      ClientLogModel? dailyLog,
      AsyncValue<Map<DateTime, List<ClientLogModel>>> weeklyHistory,
      VoidCallback onLogSleep
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Get data from the log
    final double duration = dailyLog?.totalSleepDurationHours ?? 0.0;
    final int score = dailyLog?.sleepScore ?? 0;

    // 1. Get Emoji
    String emoji;
    if (score == 0) emoji = '❔'; // Not logged
    else if (score >= 80) emoji = '😴'; // Excellent
    else if (score >= 60) emoji = '😌'; // Good
    else if (score >= 40) emoji = '😐'; // Fair
    else emoji = '😫'; // Poor

    // 2. Get Weekly Trend
    String trend = "No trend data yet";
    if (weeklyHistory is AsyncData) {
      final logsMap = weeklyHistory.value!;
      if (logsMap.length > 1) {
        // Simple average of past 7 days
        double totalScore = 0;
        int validDays = 0;
        logsMap.values.forEach((logs) {
          final log = logs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
          if (log?.sleepScore != null) {
            totalScore += log!.sleepScore!;
            validDays++;
          }
        });

        if (validDays > 0) {
          final avg = totalScore / validDays;
          trend = "Avg. ${avg.toStringAsFixed(0)}/100 this week";
        }
      }
    }

    return GestureDetector(
      onTap: onLogSleep,
      child: Card(
        elevation: 4,
        color: const Color(0xFF2E3A59), // Deep indigo
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // 1. Emoji
              Text(emoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(width: 20),

              // 2. Data
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'SLEEP SCORE',
                        style: textTheme.labelMedium?.copyWith(color: Colors.white70)
                    ),
                    Text(
                        score == 0 ? 'Not Logged' : '$score / 100',
                        style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold
                        )
                    ),

                    const SizedBox(height: 10),

                    // 3. Duration & Trend
                    Text(
                        '${duration.toStringAsFixed(1)} hours | $trend',
                        style: const TextStyle(color: Colors.white70)
                    ),
                  ],
                ),
              ),

              // 4. Icon
              Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard(BuildContext context, ClientModel clientInfo) {
    // Gradient Background for the top card
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary.withOpacity(0.9), Theme.of(context).colorScheme.primary.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${clientInfo.name}!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white70),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoBox(context, label: 'Age', value: '${clientInfo.age ?? 'N/A'} yrs', icon: Icons.cake, color: Colors.white),
                _buildInfoBox(context, label: 'Weight', value: '75.5 kg', icon: Icons.monitor_weight, color: Colors.white),
                _buildInfoBox(context, label: 'BMI', value: '25.3', icon: Icons.straighten, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHydrationTracker(
      BuildContext context,
      double currentIntake,
      double goalLiters,
      Animation<double> waveAnimation,
      bool isMale, // 🎯 New parameter for gender
      VoidCallback onAddWater
      ) {
    final effectiveGoal = goalLiters == 0 ? 3.0 : goalLiters;
    final double fillProgress = (currentIntake / effectiveGoal).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    const double containerHeight = 180.0;

    // 🎯 Select Clipper based on gender
    final CustomClipper<Path> bodyClipper =
    isMale ? MaleBodyClipper() : FemaleBodyClipper(); // Default to Male if not female

    // 🎯 Emoji Logic
    String emoji;
    if (fillProgress < 0.3) emoji = '😫'; // Tired
    else if (fillProgress < 0.6) emoji = '😐'; // Okay
    else if (fillProgress < 0.9) emoji = '😊'; // Good
    else emoji = '💪'; // Energized

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Hydration Goal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Visual Container (The "Human")
                SizedBox(
                  width: 100,
                  height: containerHeight,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // --- The Empty Body (Background) ---
                      ClipPath(
                        clipper: bodyClipper, // 🎯 Use selected clipper
                        child: Container(
                          color: Colors.blueGrey.shade50,
                          height: containerHeight,
                          width: 100,
                        ),
                      ),

                      // --- The Animated Wavy Water ---
                      AnimatedBuilder(
                        animation: waveAnimation,
                        builder: (context, child) {
                          return ClipPath(
                            clipper: bodyClipper, // 🎯 Use selected clipper to clip the wave
                            child: ClipPath(
                              // Use the wave clipper *inside* the human clip
                              clipper: WaveClipper(
                                  waveProgress: waveAnimation.value,
                                  fillProgress: fillProgress
                              ),
                              child: Container(
                                height: containerHeight,
                                width: 100,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF0077B6), Color(0xFF00B4D8)], // Ocean Blue
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // --- 🎯 The "Shine" (Glass Reflection) ---
                      ClipPath(
                        clipper: bodyClipper, // 🎯 Use selected clipper
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.6],
                            ),
                          ),
                        ),
                      ),

                      // --- 🎯 The Goal Marker ---
                      Positioned(
                        top: containerHeight * (1.0 - 1.0), // 100% goal line (at the top)
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // 2. Status and Goal Text (Right side)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🎯 Emoji Text
                      Text(
                          emoji,
                          style: const TextStyle(fontSize: 32)
                      ),
                      Text(
                          'Target: ${effectiveGoal.toStringAsFixed(1)} L',
                          style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600)
                      ),
                      Text(
                          'Logged: ${currentIntake.toStringAsFixed(1)} L',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      const SizedBox(height: 10),

                      // Action: Button launches the callback
                      ElevatedButton.icon(
                        onPressed: onAddWater,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Water'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          backgroundColor: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // 🎯 MODIFIED: Quick Tracker (Uses daily data)

  Widget _buildInfoBox(BuildContext context, {required String label, required String value, required IconData icon, VoidCallback? onTap, Color color = Colors.black}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  // 🎯 This function must be accessible to _HomeScreen
  Widget _buildDateSelector(BuildContext context, DietPlanNotifier notifier, DateTime selectedDate) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    String formatDate(DateTime date) {
      if (DateUtils.isSameDay(date, DateTime.now())) return 'Today';
      if (DateUtils.isSameDay(date, DateTime.now().subtract(const Duration(days: 1)))) return 'Yesterday';
      return DateFormat('EEE, MMM d').format(date);
    }

    return Card(
      elevation: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () {
              final previousDay = selectedDate.subtract(const Duration(days: 1));
              notifier.selectDate(previousDay); // 🎯 Triggers loadInitialData
            },
          ),

          GestureDetector(
            onTap: () async {
              final newDate = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(), // Don't allow future logging
              );
              if (newDate != null && !DateUtils.isSameDay(newDate, selectedDate)) {
                notifier.selectDate(newDate); // 🎯 Triggers loadInitialData
              }
            },
            child: Text(
              formatDate(selectedDate),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isToday ? Theme.of(context).colorScheme.primary : Colors.black87
              ),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            onPressed: isToday ? null : () {
              final nextDay = selectedDate.add(const Duration(days: 1));
              notifier.selectDate(nextDay); // 🎯 Triggers loadInitialData
            },
            color: isToday ? Colors.grey : Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
