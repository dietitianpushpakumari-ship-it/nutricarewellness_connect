import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:health/health.dart';

import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/activityhub/client_vitals_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';
import 'package:nutricare_connect/core/client_meditation_Screen.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 GLOBAL SETTING (Toggled from settings)
final useHealthConnectProvider = StateProvider<bool>((ref) => false);

class ActivityTrackerScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const ActivityTrackerScreen({super.key, required this.client});

  @override
  ConsumerState<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends ConsumerState<ActivityTrackerScreen> with WidgetsBindingObserver {
  // --- 📱 BASIC PEDOMETER STATE ---
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _pedestrianSub;
  int _liveSensorSteps = 0;
  String _pedestrianStatus = 'stopped';
  bool _sensorActive = false;

  DateTime _lastAutoSaveTime = DateTime.now();
  int _stepsAtLastSave = 0;
  bool _isSaving = false;

  // --- 🧬 HEALTH CONNECT STATE ---
  bool _isLoadingHealth = false;
  bool _isAuthorizedHealth = false;
  int _hcSteps = 0, _hcFlights = 0, _hcActiveCals = 0;
  double _hcCyclingKm = 0.0, _hcRunningKm = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Health().configure();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepSub?.cancel();
    _pedestrianSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !ref.read(useHealthConnectProvider)) {
      _forceSaveSteps();
    }
  }

  void _manageDataStreams(bool useHealthConnect) {
    if (useHealthConnect) {
      _stepSub?.cancel();
      _pedestrianSub?.cancel();
      _sensorActive = false;
      _fetchAdvancedHealthData();
    } else {
      _initPedometer();
    }
  }

  // ==========================================
  // 📱 MODULE 1: MOBILE PEDOMETER LOGIC
  // ==========================================
  void _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _stepSub ??= Pedometer.stepCountStream.listen((StepCount event) {
        if (mounted) {
          setState(() { _liveSensorSteps = event.steps; _sensorActive = true; });
          _smartAutoSync();
        }
      });
      _pedestrianSub ??= Pedometer.pedestrianStatusStream.listen((PedestrianStatus event) {
        if (mounted) setState(() => _pedestrianStatus = event.status);
      });
    }
  }

  void _smartAutoSync() {
    final now = DateTime.now();
    if (((_liveSensorSteps - _stepsAtLastSave).abs() > 500 && now.difference(_lastAutoSaveTime).inMinutes > 5) ||
        (_liveSensorSteps - _stepsAtLastSave).abs() > 1000) {
      _forceSaveSteps();
    }
  }

  Future<void> _forceSaveSteps() async {
    if (!mounted || _liveSensorSteps == 0) return;
    final state = ref.read(activeDietPlanProvider);
    if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) return;

    final baseline = state.dailyRecord?.sensorStepsBaseline ?? 0;
    final newBaseline = (baseline == 0 && _liveSensorSteps > 0) ? _liveSensorSteps : baseline;
    final calculatedDailySteps = (newBaseline == 0) ? 0 : (_liveSensorSteps - newBaseline);

    if (calculatedDailySteps <= (state.dailyRecord?.stepCount ?? 0)) return;

    _lastAutoSaveTime = DateTime.now();
    _stepsAtLastSave = _liveSensorSteps;

    await ref.read(dietPlanNotifierProvider(widget.client.id).notifier).updateDailyRecord(data: {
      'sensorStepsBaseline': newBaseline,
      'stepCount': calculatedDailySteps,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  // ==========================================
  // 🧬 MODULE 2: HEALTH CONNECT LOGIC
  // ==========================================
  Future<void> _fetchAdvancedHealthData() async {
    setState(() => _isLoadingHealth = true);
    final types = [HealthDataType.STEPS, HealthDataType.FLIGHTS_CLIMBED, HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.DISTANCE_CYCLING, HealthDataType.DISTANCE_WALKING_RUNNING];

    try {
      if (Platform.isAndroid) await Permission.activityRecognition.request();
      bool authorized = await Health().requestAuthorization(types, permissions: types.map((e) => HealthDataAccess.READ).toList());

      if (authorized) {
        final now = DateTime.now();
        List<HealthDataPoint> healthData = await Health().getHealthDataFromTypes(startTime: DateTime(now.year, now.month, now.day), endTime: now, types: types);

        int tSteps = 0, tFlights = 0;
        double tCals = 0, tCycle = 0, tRun = 0;

        for (var data in healthData) {
          final val = double.tryParse(data.value.toString()) ?? 0.0;
          switch (data.type) {
            case HealthDataType.STEPS: tSteps += val.toInt(); break;
            case HealthDataType.FLIGHTS_CLIMBED: tFlights += val.toInt(); break;
            case HealthDataType.ACTIVE_ENERGY_BURNED: tCals += val; break;
            case HealthDataType.DISTANCE_CYCLING: tCycle += val; break;
            case HealthDataType.DISTANCE_WALKING_RUNNING: tRun += val; break;
            default: break;
          }
        }
        if (mounted) setState(() { _hcSteps = tSteps; _hcFlights = tFlights; _hcActiveCals = tCals.toInt(); _hcCyclingKm = tCycle / 1000; _hcRunningKm = tRun / 1000; _isAuthorizedHealth = true; _isLoadingHealth = false; });
      } else {
        if (mounted) setState(() { _isAuthorizedHealth = false; _isLoadingHealth = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHealth = false);
    }
  }

  // ==========================================
  // 📋 MODULE 3: HABIT TOGGLE (Updated)
  // ==========================================
  Future<void> _toggleHabit(ClientLogModel? record, String habit) async {
    setState(() => _isSaving = true);
    try {
      // Assuming you keep storing them in 'completedMandatoryTasks' in the log model
      // If you changed the log model to 'completedHabits', update the strings below!
      final current = List<String>.from(record?.completedMandatoryTasks ?? []);
      if (current.contains(habit)) current.remove(habit); else current.add(habit);
      await ref.read(dietPlanNotifierProvider(widget.client.id).notifier).updateDailyRecord(data: {'completedMandatoryTasks': current});
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================
  // 🎨 COMPACT UI BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useHealthConnect = ref.watch(useHealthConnectProvider);
    final state = ref.watch(activeDietPlanProvider);

    ref.listen<bool>(useHealthConnectProvider, (prev, next) => _manageDataStreams(next));
    if (_stepSub == null && !useHealthConnect) _initPedometer();

    if (state.isLoading) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: const Center(child: CircularProgressIndicator()));
    if (state.activePlan == null) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: const Center(child: Text("No active plan.")));

    final isToday = DateUtils.isSameDay(state.selectedDate, DateTime.now());
    final stepGoal = state.activePlan!.dailyStepGoal > 0 ? state.activePlan!.dailyStepGoal : 8000;

    // 🎯 NEW: Pulling from assignedHabits instead of mandatoryDailyTasks
    final assignedHabits = state.activePlan!.assignedHabits;

    return SafeArea(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) { if (didPop && mounted && !useHealthConnect) _forceSaveSteps(); },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(theme, colorScheme, isToday, useHealthConnect)),

              // 📊 COMPACT METRICS
              if (useHealthConnect)
                _buildHealthConnectSlivers(theme, colorScheme)
              else
                _buildPedometerSlivers(theme, colorScheme, state.dailyRecord, stepGoal, isToday),

              // 🩺 COMPACT HEALTH RECORDS
              SliverToBoxAdapter(child: _buildCompactHealthRecords(theme, colorScheme)),

              // ✅ ASSIGNED HABITS LIST
              if (assignedHabits.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text("Dietitian's Habits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final habit = assignedHabits[index];
                          // Uses the existing log tracker structure
                          final isCompleted = state.dailyRecord?.completedMandatoryTasks.contains(habit) ?? false;
                          return _buildCompactHabitCard(habit, isCompleted, theme, colorScheme, () => _toggleHabit(state.dailyRecord, habit));
                        },
                        childCount: assignedHabits.length
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, bool isToday, bool useHealthConnect) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colorScheme.onSurface), onPressed: () { if (!useHealthConnect) _forceSaveSteps(); Navigator.pop(context); }),
          const SizedBox(width: 8),
          Expanded(child: Text("Activity & Habits", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: colorScheme.onSurface))),
          if (useHealthConnect && _isAuthorizedHealth)
            IconButton(icon: Icon(Icons.sync_rounded, color: colorScheme.primary), onPressed: _fetchAdvancedHealthData)
        ],
      ),
    );
  }

  // --- 📱 PEDOMETER VIEW (Compact) ---
  Widget _buildPedometerSlivers(ThemeData theme, ColorScheme colorScheme, ClientLogModel? dailyRecord, int stepGoal, bool isToday) {
    int displaySteps = dailyRecord?.stepCount ?? 0;
    if (_sensorActive && isToday && (dailyRecord?.sensorStepsBaseline ?? 0) > 0 && _liveSensorSteps >= (dailyRecord?.sensorStepsBaseline ?? 0)) {
      displaySteps = _liveSensorSteps - dailyRecord!.sensorStepsBaseline;
    }
    final int totalCals = (dailyRecord?.caloriesBurned ?? 0) + ((displaySteps - (dailyRecord?.stepCount ?? 0)) * 0.04).round();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
            children: [
              Expanded(child: _buildCompactMetric("Steps", "$displaySteps", "/$stepGoal", Icons.directions_walk_rounded, Colors.orange, theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactMetric("Burned", "$totalCals", "kcal", Icons.local_fire_department_rounded, Colors.redAccent, theme)),
            ]
        ),
      ),
    );
  }

  // --- 🧬 HEALTH CONNECT VIEW (Compact) ---
  Widget _buildHealthConnectSlivers(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoadingHealth) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())));
    if (!_isAuthorizedHealth) return SliverToBoxAdapter(child: _buildUnauthorizedState(theme, colorScheme));

    return SliverList(delegate: SliverChildListDelegate([
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
        Expanded(child: _buildCompactMetric("Steps", "$_hcSteps", "", Icons.directions_walk_rounded, Colors.orange, theme)),
        const SizedBox(width: 12),
        Expanded(child: _buildCompactMetric("Cals Burned", "$_hcActiveCals", "kcal", Icons.local_fire_department_rounded, Colors.redAccent, theme)),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
        Expanded(child: _buildCompactMetric("Stairs", "$_hcFlights", "flr", Icons.stairs_rounded, Colors.purpleAccent, theme)),
        const SizedBox(width: 12),
        Expanded(child: _buildCompactMetric("Cycling", _hcCyclingKm.toStringAsFixed(1), "km", Icons.pedal_bike_rounded, Colors.teal, theme)),
        const SizedBox(width: 12),
        Expanded(child: _buildCompactMetric("Running", _hcRunningKm.toStringAsFixed(1), "km", Icons.directions_run_rounded, Colors.blueAccent, theme)),
      ])),
    ]));
  }

  // --- COMPACT UI UTILS ---
  Widget _buildCompactMetric(String label, String value, String suffix, IconData icon, Color color, ThemeData theme) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 12),
              RichText(text: TextSpan(children: [
                TextSpan(text: value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                if (suffix.isNotEmpty) TextSpan(text: " $suffix", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor))
              ])),
              Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w600))
            ]
        )
    );
  }

  Widget _buildCompactHealthRecords(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Health Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildPillButton("Vitals", Icons.monitor_heart_rounded, colorScheme.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientVitalsHistoryScreen(clientId: widget.client.id))))),
          const SizedBox(width: 8),
          Expanded(child: _buildPillButton("Reports", Icons.folder_copy_rounded, colorScheme.secondary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabReportListScreen(client: widget.client))))),
          const SizedBox(width: 8),
          Expanded(child: _buildPillButton("Meds", Icons.medication_rounded, Colors.pinkAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientMedicationScreen(clientId: widget.client.id))))),
        ]),
      ]),
    );
  }

  Widget _buildPillButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: color.withOpacity(0.05)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHabitCard(String title, bool isCompleted, ThemeData theme, ColorScheme colorScheme, VoidCallback onTap) {
    final Color successColor = Colors.green.shade600;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: isCompleted ? successColor.withOpacity(0.1) : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCompleted ? successColor.withOpacity(0.4) : theme.dividerColor.withOpacity(0.1))
        ),
        child: Row(children: [
          Icon(isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined, color: isCompleted ? successColor : theme.hintColor.withOpacity(0.5), size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isCompleted ? successColor : colorScheme.onSurface, decoration: isCompleted ? TextDecoration.lineThrough : null)))
        ]),
      ),
    );
  }

  Widget _buildUnauthorizedState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.health_and_safety_rounded, size: 60, color: theme.hintColor.withOpacity(0.3)), const SizedBox(height: 16), Text("Connect Health Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)), const SizedBox(height: 8), Text("Authorize sync to automatically track steps, stairs, cycling, and calories.", style: TextStyle(fontSize: 13, color: theme.hintColor), textAlign: TextAlign.center), const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _fetchAdvancedHealthData, style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Authorize", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))))]));
  }
}