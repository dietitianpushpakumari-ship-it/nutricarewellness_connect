import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:health/health.dart';

import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/activityhub/client_vitals_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
import 'package:nutricare_connect/core/vitals_comprasion_screen.dart';
import 'package:nutricare_connect/core/client_meditation_Screen.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 GLOBAL SETTING (Toggled from settings)
final useHealthConnectProvider = StateProvider<bool>((ref) => false);


final vitalsHistoryProvider = StreamProvider.autoDispose.family<List<ClientLogModel>, String>((ref, clientId) {
  // Optional: Only fetch the last 30 days to save Firestore reads and improve performance
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  return FirebaseFirestore.instance
      .collection('clients')
      .doc(clientId)
      .collection('daily_logs')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => ClientLogModel.fromMap(doc.data(), doc.id)).toList();
  });
});

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

  // 🔥 NEW: SMART TREND STATE
  String _selectedTrendMetric = 'Weight';
  final List<String> _trendOptions = ['Weight', 'Steps', 'Calories', 'Heart Rate', 'Systolic', 'Diastolic', 'FBS', 'PPBS'];

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

  // 🎯 CLINICAL THRESHOLDS HELPER
  List<double>? _getClinicalThresholds(String metric) {
    switch (metric) {
      case 'Heart Rate': return [60.0, 100.0]; // Normal resting HR
      case 'Systolic': return [90.0, 120.0];   // Normal BP
      case 'Diastolic': return [60.0, 80.0];   // Normal BP
      case 'FBS': return [70.0, 100.0];        // Fasting Sugar
      case 'PPBS': return [0.0, 140.0];        // Post-meal Sugar Max
      case 'Steps': return [8000.0, 8000.0];   // Single Target Line
      default: return null; // Weight, Calories, etc. have dynamic/personal goals
    }
  }

  Widget _buildSmartTrendSection(ThemeData theme, ColorScheme colorScheme, WidgetRef ref) {
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.client.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Smart Trends", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
          const SizedBox(height: 12),

          // Scrollable Metric Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _trendOptions.map((metric) {
                final isSelected = _selectedTrendMetric == metric;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(metric, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : theme.hintColor)),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val) setState(() => _selectedTrendMetric = metric);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // The Chart Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: vitalsAsync.when(
                loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                error: (e, s) => const SizedBox(height: 150, child: Center(child: Text("Error loading trends"))),
                data: (history) {
                  final sorted = List.of(history)..sort((a, b) => a.date.compareTo(b.date));
                  final last7 = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;

                  if (last7.isEmpty) {
                    return SizedBox(height: 120, child: Center(child: Text("No data to plot.", style: TextStyle(color: theme.hintColor))));
                  }

                  // 1. Extract values
                  List<double> values = last7.map((v) => _getTrendValue(v, _selectedTrendMetric)).toList();
                  double maxVal = values.fold(0.0, (max, v) => v > max ? v : max);

                  // 2. Get Thresholds
                  List<double>? thresholds = _getClinicalThresholds(_selectedTrendMetric);

                  // 3. Ensure chart scales high enough to show the threshold even if current values are low
                  if (thresholds != null && thresholds.last > maxVal) {
                    maxVal = thresholds.last;
                  }

                  // Add 20% headroom so the top line isn't touching the ceiling and labels don't get cut
                  maxVal = maxVal == 0 ? 10 : maxVal * 1.20;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("$_selectedTrendMetric Progress", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.hintColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(_getTrendUnit(_selectedTrendMetric), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                          )
                        ],
                      ),
                      const SizedBox(height: 24), // Extra space for labels

                      // 📈 THE PURE FLUTTER CURVED LINE GRAPH (With Thresholds!)
                      SizedBox(
                        height: 110,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: TrendLinePainter(
                            data: values,
                            maxVal: maxVal,
                            primaryColor: colorScheme.primary,
                            textColor: colorScheme.onSurface,
                            backgroundColor: theme.cardColor,
                            thresholds: thresholds, // 🔥 PASSING THE SAFE ZONES
                          ),
                        ),
                      ),

                      // 📅 X-Axis Date Labels
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: last7.map((v) => SizedBox(
                          width: 30, // Forces dates to align roughly under their dots
                          child: Text(
                              DateFormat('dd MMM').format(v.date),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: theme.hintColor)
                          ),
                        )).toList(),
                      ),
                    ],
                  );
                }
            ),
          )
        ],
      ),
    );
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
  // 📋 MODULE 3: HABIT TOGGLE
  // ==========================================
  Future<void> _toggleHabit(ClientLogModel? record, String habit) async {
    setState(() => _isSaving = true);
    try {
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
              SliverToBoxAdapter(child: _buildHeader(theme, colorScheme, useHealthConnect)),

              if (useHealthConnect)
                _buildHealthConnectSlivers(theme, colorScheme)
              else
                _buildPedometerSlivers(theme, colorScheme, state.dailyRecord, stepGoal, isToday),

              // 📈 MULTI-METRIC SMART TREND CHART
              SliverToBoxAdapter(child: _buildSmartTrendSection(theme, colorScheme, ref)),

              SliverToBoxAdapter(child: _buildCompactHealthRecords(theme, colorScheme, state, ref)),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, bool useHealthConnect) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(child: Text("Activity & Health", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: colorScheme.onSurface))),
          if (useHealthConnect && _isAuthorizedHealth)
            IconButton(icon: Icon(Icons.sync_rounded, color: colorScheme.primary), onPressed: _fetchAdvancedHealthData)
        ],
      ),
    );
  }

  // --- 📱 PEDOMETER VIEW ---
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

  // --- 🧬 HEALTH CONNECT VIEW ---
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

  // ==========================================
  // 🔥 THE NEW MULTI-METRIC SMART TREND
  // ==========================================

  // Safe data extractor (Uses dynamic to prevent model-mismatch crashes)
  double _getTrendValue(dynamic record, String metric) {
    try {
      switch (metric) {
        case 'Weight': return (record.weightKg ?? 0).toDouble();
        case 'Steps': return (record.stepCount ?? 0).toDouble();
        case 'Calories': return (record.caloriesBurned ?? 0).toDouble();
        case 'Heart Rate': return (record.heartRate ?? record.heartRateBpm ?? 0).toDouble();
        case 'Systolic': return (record.bloodPressureSystolic ?? 0).toDouble();
        case 'Diastolic': return (record.bloodPressureDiastolic ?? 0).toDouble();
        case 'FBS':
          if (record.fbsMgDl != null) return record.fbsMgDl.toDouble();
          if (record.labResults != null && record.labResults['fbs'] != null) return record.labResults['fbs'].toDouble();
          return 0.0;
        case 'PPBS':
          if (record.ppbsMgDl != null) return record.ppbsMgDl.toDouble();
          if (record.labResults != null && record.labResults['ppbs'] != null) return record.labResults['ppbs'].toDouble();
          return 0.0;
        default: return 0.0;
      }
    } catch (e) {
      return 0.0; // Fail safely if a property doesn't exist on this model
    }
  }

  String _getTrendUnit(String metric) {
    switch (metric) {
      case 'Weight': return 'kg';
      case 'Steps': return 'steps';
      case 'Calories': return 'kcal';
      case 'Heart Rate': return 'bpm';
      case 'Systolic':
      case 'Diastolic': return 'mmHg';
      case 'FBS':
      case 'PPBS': return 'mg/dL';
      default: return '';
    }
  }


  // --- 🩺 REDESIGNED HEALTH RECORDS ---
  Widget _buildCompactHealthRecords(ThemeData theme, ColorScheme colorScheme, dynamic state, WidgetRef ref) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Health & Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildActionCard("Log Vitals", "Daily tracking", Icons.add_chart_rounded, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogVitalsScreen(notifier: notifier, activePlan: state.activePlan, dailyLog: state.dailyRecord))), theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildActionCard("My Trends", "Report", Icons.trending_up_rounded, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientVitalsHistoryScreen(clientId: widget.client.id))), theme)),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // --- ✅ PREMIUM HABIT TILE ---
  Widget _buildPremiumHabitTile(String title, bool isCompleted, ThemeData theme, ColorScheme colorScheme, VoidCallback onTap) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isCompleted ? LinearGradient(colors: [primary.withOpacity(0.8), primary], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: isCompleted ? null : theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isCompleted ? Colors.transparent : theme.dividerColor.withOpacity(isDark ? 0.2 : 0.1), width: 1.5),
          boxShadow: isCompleted ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))] : [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isCompleted ? Colors.white.withOpacity(0.2) : colorScheme.surfaceContainerHighest.withOpacity(0.5), shape: BoxShape.circle), child: Icon(_guessIconForHabit(title), size: 20, color: isCompleted ? Colors.white : primary)),
                if (isCompleted) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24) else Icon(Icons.circle_outlined, color: theme.hintColor.withOpacity(0.3), size: 24),
              ],
            ),
            Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2, color: isCompleted ? Colors.white : colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  IconData _guessIconForHabit(String habit) {
    final lower = habit.toLowerCase();
    if (lower.contains('water') || lower.contains('drink')) return Icons.water_drop_rounded;
    if (lower.contains('walk') || lower.contains('step')) return Icons.directions_walk_rounded;
    if (lower.contains('sleep') || lower.contains('bed')) return Icons.bedtime_rounded;
    if (lower.contains('meditate') || lower.contains('breathe')) return Icons.self_improvement_rounded;
    if (lower.contains('read') || lower.contains('book')) return Icons.menu_book_rounded;
    if (lower.contains('eat') || lower.contains('meal')) return Icons.restaurant_rounded;
    return Icons.star_rounded;
  }

  Widget _buildUnauthorizedState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.health_and_safety_rounded, size: 60, color: theme.hintColor.withOpacity(0.3)), const SizedBox(height: 16), Text("Connect Health Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)), const SizedBox(height: 8), Text("Authorize sync to automatically track steps, stairs, cycling, and calories.", style: TextStyle(fontSize: 13, color: theme.hintColor), textAlign: TextAlign.center), const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _fetchAdvancedHealthData, style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Authorize", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))))]));
  }
}





// ==========================================
// 🎨 PURE FLUTTER CURVED LINE GRAPH (WITH SAFE ZONES)
// ==========================================
// ==========================================
// 🎨 PURE FLUTTER CURVED LINE GRAPH (WITH SAFE ZONES)
// ==========================================
class TrendLinePainter extends CustomPainter {
  final List<double> data;
  final double maxVal;
  final Color primaryColor;
  final Color textColor;
  final Color backgroundColor; // Needed to make the label pill match the card
  final List<double>? thresholds; // [min, max] for the green safe zone

  TrendLinePainter({
    required this.data,
    required this.maxVal,
    required this.primaryColor,
    required this.textColor,
    required this.backgroundColor,
    this.thresholds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double width = size.width;
    // Leave 30px of headroom so the text numbers don't get clipped at the top
    final double height = size.height - 30;
    const double bottomOffset = 30.0;

    // 🟢 1. DRAW CLINICAL SAFE ZONES (THRESHOLDS)
    if (thresholds != null && maxVal > 0) {
      double minT = thresholds![0];
      double maxT = thresholds!.length > 1 ? thresholds![1] : minT;

      double yMinLine = height - ((maxT / maxVal) * height) + bottomOffset;
      double yMaxLine = height - ((minT / maxVal) * height) + bottomOffset;

      // Draw the light green band between min and max
      if (minT != maxT) {
        final safeZonePaint = Paint()..color = Colors.green.withOpacity(0.08)..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTRB(0, yMinLine, width, yMaxLine), safeZonePaint);
      }

      // Draw dashed threshold lines
      _drawDashedLine(canvas, yMinLine, width, Colors.green.withOpacity(0.5));
      if (minT != maxT) {
        _drawDashedLine(canvas, yMaxLine, width, Colors.green.withOpacity(0.5));
      }
    }

    final Path path = Path();
    final Path fillPath = Path();

    if (data.length == 1) {
      double x = width / 2;
      double y = height - ((data[0] / maxVal) * height) + bottomOffset;
      _drawPointAndText(canvas, Offset(x, y), data[0]);
      return;
    }

    final double xStep = width / (data.length - 1);
    List<Offset> points = [];

    // Calculate Coordinates
    for (int i = 0; i < data.length; i++) {
      double x = i * xStep;
      double y = height - ((data[i] / maxVal) * height) + bottomOffset;
      points.add(Offset(x, y));
    }

    // 2. Generate Smooth Cubic Bezier Curve
    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      var p0 = points[i];
      var p1 = points[i + 1];

      double controlX = p0.dx + (p1.dx - p0.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // 3. Draw Gradient Fill Below the Line
    final Gradient gradient = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [primaryColor.withOpacity(0.4), primaryColor.withOpacity(0.0)],
    );
    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, width, size.height)));

    // 4. Draw the Solid Line
    final Paint linePaint = Paint()..color = primaryColor..strokeWidth = 3.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // 5. Draw Dots and High-Contrast Values
    for (int i = 0; i < points.length; i++) {
      _drawPointAndText(canvas, points[i], data[i]);
    }
  }

  void _drawDashedLine(Canvas canvas, double y, double width, Color color) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    double dashWidth = 5, dashSpace = 5, startX = 0;
    while (startX < width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  void _drawPointAndText(Canvas canvas, Offset point, double value) {
    if (value == 0) return; // Skip 0s

    // Draw Dot
    canvas.drawCircle(point, 4, Paint()..color = Colors.white);
    canvas.drawCircle(point, 4, Paint()..color = primaryColor..strokeWidth = 2.5..style = PaintingStyle.stroke);

    // Format Text
    String valText = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

    // Determine if value is out of bounds (to make text red instead of primary color)
    Color labelColor = textColor;
    if (thresholds != null) {
      if (value < thresholds![0] || (thresholds!.length > 1 && value > thresholds![1])) {
        labelColor = Colors.redAccent;
      }
    }

    final TextPainter tp = TextPainter(
      text: TextSpan(text: valText, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    // Draw a subtle background "pill" behind the text so it is ALWAYS readable
    final Rect bgRect = Rect.fromCenter(
        center: Offset(point.dx, point.dy - 18),
        width: tp.width + 10,
        height: tp.height + 6
    );

    final Paint bgPaint = Paint()
      ..color = backgroundColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(8)), bgPaint);

    // Paint Text over the pill
    tp.paint(canvas, Offset(point.dx - (tp.width / 2), point.dy - 18 - (tp.height / 2)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}