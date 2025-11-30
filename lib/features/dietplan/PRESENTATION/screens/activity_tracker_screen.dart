import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/client_meditation_Screen.dart';
import 'package:nutricare_connect/core/utils/client_vitals_history_screen.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:collection/collection.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// 🎯 CORE UTILS
import 'package:nutricare_connect/core/utils/activity_trend_chart.dart';
import 'package:nutricare_connect/core/utils/workout_entry_dialog.dart';

// 🎯 SCREENS (Navigation Targets)

import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';

// 🎯 PROVIDERS & MODELS
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class ActivityTrackerScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const ActivityTrackerScreen({super.key, required this.client});

  @override
  ConsumerState<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends ConsumerState<ActivityTrackerScreen> with WidgetsBindingObserver {
  Stream<StepCount>? _stepCountStream;
  int _liveSensorSteps = 0;
  bool _sensorActive = false;
  DateTime _lastAutoSaveTime = DateTime.now();
  int _stepsAtLastSave = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(stepSensorEnabledProvider)) _initPedometer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _forceSaveSteps();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _forceSaveSteps();
  }

  // --- PEDOMETER LOGIC ---
  void _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((StepCount event) {
        if (mounted) {
          setState(() {
            _liveSensorSteps = event.steps;
            _sensorActive = true;
          });
          _smartAutoSync();
        }
      });
    }
  }

  void _smartAutoSync() {
    final now = DateTime.now();
    final stepDiff = (_liveSensorSteps - _stepsAtLastSave).abs();
    final timeDiff = now.difference(_lastAutoSaveTime).inMinutes;
    if ((stepDiff > 500 && timeDiff > 5) || stepDiff > 1000) {
      _forceSaveSteps();
    }
  }

  Future<void> _forceSaveSteps() async {
    if (_liveSensorSteps == 0) return;
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final state = ref.read(activeDietPlanProvider);
    if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) return;

    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;
    int newBaseline = baseline;
    if (baseline == 0 && _liveSensorSteps > 0) newBaseline = _liveSensorSteps;

    final int calculatedDailySteps = (newBaseline == 0) ? 0 : (_liveSensorSteps - newBaseline);
    if (calculatedDailySteps <= (dailyLog?.stepCount ?? 0)) return;

    final logToSave = dailyLog ?? ClientLogModel(
      id: '', clientId: state.activePlan!.clientId, dietPlanId: state.activePlan!.id,
      mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: DateTime.now(),
    );

    final updatedLog = logToSave.copyWith(sensorStepsBaseline: newBaseline, stepCount: calculatedDailySteps);
    _lastAutoSaveTime = DateTime.now();
    _stepsAtLastSave = _liveSensorSteps;
    await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
  }

  // --- ACTIONS ---
  Future<void> _logWorkout(ClientLogModel? log, int calories, int durationMinutes) async {
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final state = ref.read(activeDietPlanProvider);
      final logToSave = log ?? ClientLogModel(
        id: '', clientId: state.activePlan!.clientId, dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: state.selectedDate,
      );

      final updatedLog = logToSave.copyWith(
        caloriesBurned: (logToSave.caloriesBurned ?? 0) + calories,
        activityScore: ((logToSave.activityScore ?? 0) + 15).clamp(0, 100),
      );

      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nice! Workout Logged 🔥"), backgroundColor: Colors.green));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleTask(ClientLogModel? log, String task) async {
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
      final state = ref.read(activeDietPlanProvider);
      final logToSave = log ?? ClientLogModel(
        id: '', clientId: state.activePlan!.clientId, dietPlanId: state.activePlan!.id,
        mealName: 'DAILY_WELLNESS_CHECK', actualFoodEaten: ['Daily Wellness Data'], date: state.selectedDate,
      );

      final current = List<String>.from(logToSave.completedMandatoryTasks);
      if (current.contains(task)) current.remove(task); else current.add(task);

      await notifier.createOrUpdateLog(log: logToSave.copyWith(completedMandatoryTasks: current), mealPhotoFiles: const []);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeDietPlanProvider);

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.activePlan == null) return const Center(child: Text("No active plan."));

    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    // Calculate Steps
    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;
    int displaySteps = dailyLog?.stepCount ?? 0;
    if (_sensorActive && DateUtils.isSameDay(state.selectedDate, DateTime.now()) && baseline > 0 && _liveSensorSteps >= baseline) {
      displaySteps = _liveSensorSteps - baseline;
    }

    // Calculate Metrics
    final int dbCals = dailyLog?.caloriesBurned ?? 0;
    final int liveStepCals = ((displaySteps - (dailyLog?.stepCount ?? 0)) * 0.04).round();
    final int totalDisplayCals = dbCals + liveStepCals;
    final int stepGoal = state.activePlan!.dailyStepGoal > 0 ? state.activePlan!.dailyStepGoal : 8000;
    final int score = dailyLog?.activityScore ?? 0;
    final mandatoryTasks = state.activePlan!.mandatoryDailyTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER
          SliverToBoxAdapter(child: _buildHeader()),

          // 2. ACTIVITY TREND CHART
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.only(top: 20, bottom: 20, right: 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
              child: ActivityTrendChart(clientId: widget.client.id, stepGoal: stepGoal),
            ),
          ),

          // 3. SCORE CARD
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: const Color(0xFF2575FC).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Daily Activity Score", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("$score", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 1.0)),
                      const SizedBox(height: 8),
                      const Text("Keep moving to boost your score!", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  ),
                  SizedBox(height: 70, width: 70, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: 1.0, color: Colors.white24, strokeWidth: 6), CircularProgressIndicator(value: (score / 100).clamp(0.0, 1.0), color: Colors.greenAccent, strokeWidth: 6, strokeCap: StrokeCap.round), const Icon(Icons.bolt, color: Colors.white, size: 28)])),
                ],
              ),
            ),
          ),

          // 4. METRICS ROW
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: _buildMetricTile("Steps", "$displaySteps", " / $stepGoal", Icons.directions_walk, Colors.orange)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricTile("Burned", "$totalDisplayCals", " kcal", Icons.local_fire_department, Colors.red)),
                ],
              ),
            ),
          ),

          // 🎯 5. HEALTH RECORDS (Integrated Vitals History & Labs)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Health Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // A. Vitals History (Opens Clinical Graphs)
                      Expanded(
                        child: _buildActionCard(
                          "Vitals History", "View Trends", Icons.show_chart, Colors.indigo,
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientVitalsHistoryScreen(clientId: widget.client.id))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // B. Lab Reports
                      Expanded(
                        child: _buildActionCard(
                          "Lab Reports", "Medical Files", Icons.folder_open, Colors.teal,
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabReportListScreen(client: widget.client))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          "Medicines",
                          "My Pills",
                          Icons.medication,
                          Colors.pink,
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientMedicationScreen(clientId: widget.client.id))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 6. QUICK WORKOUT (Manual Entry)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildWideActionCard(
                "Log Workout", "Add Manual Exercise", Icons.fitness_center, Colors.purple,
                    () => showDialog(context: context, builder: (_) => WorkoutEntryDialog(onSave: (t, d, c) => _logWorkout(dailyLog, c, d))),
              ),
            ),
          ),

          // 7. MISSIONS
          if (mandatoryTasks.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 10), child: Text("Mission Checklist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final task = mandatoryTasks[index];
                final isCompleted = dailyLog?.completedMandatoryTasks.contains(task) ?? false;
                return _buildTaskCard(task, isCompleted, () => _toggleTask(dailyLog, task));
              }, childCount: mandatoryTasks.length)),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
          color: Colors.white.withOpacity(0.8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Activity & Health", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Icon(Icons.favorite, color: Colors.orange.shade800, size: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String suffix, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 12),
        RichText(text: TextSpan(children: [TextSpan(text: value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), TextSpan(text: suffix, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _buildWideActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))])),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildTaskCard(String title, bool isCompleted, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: isCompleted ? Colors.green.shade50 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200)),
        child: Row(children: [
          Icon(isCompleted ? Icons.check_circle : Icons.circle_outlined, color: isCompleted ? Colors.green : Colors.grey.shade400),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isCompleted ? Colors.green.shade900 : Colors.black87, decoration: isCompleted ? TextDecoration.lineThrough : null))),
        ]),
      ),
    );
  }
}