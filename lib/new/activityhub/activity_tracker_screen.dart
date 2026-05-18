import 'dart:async';
import 'dart:io' show Platform;

import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb and TargetPlatform
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart'; // Dual-Engine Fallback
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart'; // Samsung Bridge

import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/core/utils/performance_utils.dart';
import 'package:pure_shift/core/utils/sync_manager.dart';
import 'package:pure_shift/new/activityhub/client_vitals_history_screen.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:google_fonts/google_fonts.dart';
// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class ActivityTrackerScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const ActivityTrackerScreen({super.key, required this.client});

  @override
  ConsumerState<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends ConsumerState<ActivityTrackerScreen> with WidgetsBindingObserver {
  bool _isProcessingPermission = false;
  bool _hasPermissions = false;
  bool _isSyncing = false;
  // Add this near your _pedometerSubscription
  Timer? _stepDebounceTimer;
  int? _liveSteps; // Optimistic local state for real-time UI

  // 🚀 DUAL-ENGINE STATE
  Timer? _passiveUiTimer;
  String _activeStepEngine = "Initializing...";

  // --- 🔥 SMART TREND STATE ---
  String _selectedTrendMetric = 'Steps';
  final List<String> _trendOptions = ['Steps', 'Weight', 'Calories', 'Heart Rate', 'Systolic', 'Diastolic', 'FBS', 'PPBS'];
  bool _isSavingHabit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb) {
      Health().configure();
    }

    _initHealthKit();
  }

  @override
  void dispose() {
    _passiveUiTimer?.cancel(); // Kill the passive viewer
    _stepDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasPermissions && !kIsWeb) {
      if (_activeStepEngine == "Health Connect") {
        _fetchTodayStepsFromHealthConnect();
      }
    }
  }

  // ==========================================
  // 🏃 DUAL-ENGINE STEP SYNC LOGIC
  // ==========================================
  Future<void> _initHealthKit() async {
    if (_isProcessingPermission) return;
    _isProcessingPermission = true;

    try {
      if (kIsWeb) {
        if (mounted) setState(() => _activeStepEngine = "Manual Entry (Web)");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _liveSteps = prefs.getInt('steps_today') ?? 0;
        });
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final activityStatus = await Permission.activityRecognition.status;

        if (activityStatus.isGranted) {
          // 🚀 UPDATE THE FLAG
          if (mounted) setState(() => _hasPermissions = true);
          _initLivePedometerUI();
        } else {
          final requestStatus = await Permission.activityRecognition.request();
          if (!mounted) return;

          if (requestStatus.isGranted) {
            // 🚀 UPDATE THE FLAG
            setState(() {
              _hasPermissions = true;
              _activeStepEngine = "Live Hardware Sensor";
            });
            _initLivePedometerUI();
          } else {
            setState(() {
              _hasPermissions = false;
              _activeStepEngine = "Permission Denied";
            });
          }
        }
      }

      // This stays as a background task
      _tryInitHealthConnect();
    } catch (e) {
      debugPrint("Health Init Error: $e");
    } finally {
      _isProcessingPermission = false;
    }
  }
  void _initLivePedometerUI() {
    if (!mounted) return;

    setState(() => _activeStepEngine = "Live Hardware Sensor");
    final duration = PerformanceManager.isLowEndDevice
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 500);

    // 🚀 PASSIVE LISTENER: Check the shared memory twice a second
    _passiveUiTimer = Timer.periodic( duration, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      // Read the exact number the Home Screen is calculating
      int latestSteps = prefs.getInt('steps_today') ?? 0;

      // Only run math/cloud logic if the Home Screen actually recorded a new step
      if (_liveSteps != latestSteps) {
        setState(() {
          _liveSteps = latestSteps;
        });

        // Push to Firestore safely when it changes
        if (_stepDebounceTimer?.isActive ?? false) {
          _stepDebounceTimer!.cancel();
        }

        _stepDebounceTimer = Timer(const Duration(seconds: 3), () {
      //    _syncStepsToDatabase(latestSteps);
        });
      }
    });
  }

  Future<bool> _tryInitHealthConnect() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        var sdkStatus = await Health().getHealthConnectSdkStatus();
        if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
          return false;
        }
      }

      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      bool? hasPermissions = await Health().hasPermissions(types, permissions: permissions);
      if (hasPermissions != true) {
        hasPermissions = await Health().requestAuthorization(types, permissions: permissions);
      }

      if (hasPermissions == true) {
        final now = DateTime.now();
        int? steps = await Health().getTotalStepsInInterval(DateTime(now.year, now.month, now.day), now);

        if (steps != null && steps > 0 && mounted) {
          // We do NOT update the UI engine name here, because we want the user
          // to know the "Live Hardware Sensor" is driving the display.
          // We just quietly sync the Health Connect data to Firestore if needed.
          _syncStepsToDatabase(steps);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }



  Future<void> _fetchTodayStepsFromHealthConnect() async {
    if (_isSyncing || kIsWeb) return;
    setState(() => _isSyncing = true);

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      int? steps = await Health().getTotalStepsInInterval(midnight, now);
      if (steps != null && mounted) {
        _syncStepsToDatabase(steps);
      }
    } catch (e) {
      debugPrint("Health Connect fetch error: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ==========================================
  // ⚙️ ENGINE B: PEDOMETER FALLBACK
  // ==========================================


  Future<void> _syncStepsToDatabase(int accurateSteps) async {
    final state = ref.read(activeDietPlanProvider);
    if (state.activePlan == null || state.dailyRecord == null) return;
    if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) {
      ref.read(dietPlanNotifierProvider(widget.client.id).notifier).selectDate(DateTime.now());
      return; // Exit and let the next cycle handle the new day's 0 count
    }

    if (state.dailyRecord!.stepCount == accurateSteps) return;

    await ref.read(dietPlanNotifierProvider(widget.client.id).notifier).updateDailyRecord(data: {
      'stepCount': accurateSteps,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  // ==========================================
  // 📋 HABIT LOGIC
  // ==========================================
  Future<void> _toggleHabit(ClientLogModel? record, String habit) async {
    HapticFeedback.selectionClick();
    setState(() => _isSavingHabit = true);
    try {
      final current = List<String>.from(record?.completedMandatoryTasks ?? []);
      if (current.contains(habit)) current.remove(habit); else current.add(habit);
      await ref.read(dietPlanNotifierProvider(widget.client.id).notifier).updateDailyRecord(data: {'completedMandatoryTasks': current});
    } finally {
      if (mounted) setState(() => _isSavingHabit = false);
    }
  }

  // ==========================================
  // 🎨 UI BUILDERS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(activeDietPlanProvider);

    if (state.isLoading) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: const Center(child: CircularProgressIndicator()));
    if (state.activePlan == null) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: Center(child: Text("No active plan.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor))));

    final stepGoal = state.activePlan!.dailyStepGoal > 0 ? state.activePlan!.dailyStepGoal : 8000;
    final displaySteps = state.dailyRecord?.stepCount ?? 0;

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(theme, colorScheme)),

            // 🚀 THE SAMSUNG BRIDGE (Only appears on Android if steps are 0)
            _buildGlobalHealthBridge(theme, displaySteps),

            _buildMetricsRow(theme, colorScheme, state.dailyRecord, stepGoal),

            SliverToBoxAdapter(child: _buildSmartTrendSection(theme, colorScheme, ref)),

            SliverToBoxAdapter(child: _buildMedicalRecords(theme, colorScheme, state)),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void scheduleClinicalSync(String patientId) {
    if (kIsWeb) return;

    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    Workmanager().registerPeriodicTask(
      "pure_shift_step_sync_1",
      "clinicalDataSync",
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true),
      inputData: {'patientId': patientId},
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Activity & Health", style: TextStyle(fontFamily: kDisplayFont, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: colorScheme.onSurface)),
          if (_isSyncing)
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
        ],
      ),
    );
  }

  // ==========================================
  // 🚀 THE SAMSUNG HEALTH SYNC BRIDGE
  // ==========================================
  Widget _buildGlobalHealthBridge(ThemeData theme, int displaySteps) {
    // If we are on Web or already have steps, hide it.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || displaySteps > 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withOpacity(0.05), // Use your Clinical Green
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF059669).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.sync_rounded, color: Color(0xFF059669)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Sync Vital Activity", // 🚀 Generic, professional title
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF0F172A)
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "To track your progress, link your phone's activity data (Mi Fitness, Google Fit, etc.) to our clinical engine.",
              style: GoogleFonts.inter(fontSize: 12, color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  try {
                    // This opens the system settings where they can
                    // allow Mi Fitness to talk to Health Connect
                    final intent = AndroidIntent(
                      action: 'androidx.health.ACTION_HEALTH_CONNECT_SETTINGS',
                      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    await intent.launch();
                  } catch (e) {
                    await Health().installHealthConnect();
                  }
                },
                child: Text(
                    "ACTIVATE STEP SYNC",
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0
                    )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🚀 WEB-SAFE METRICS ROW
  // ==========================================
  Widget _buildMetricsRow(ThemeData theme, ColorScheme colorScheme, ClientLogModel? dailyRecord, int stepGoal) {

    final int displaySteps = _liveSteps ?? dailyRecord?.stepCount ?? 0;

    final int totalCals = (dailyRecord?.caloriesBurned ?? 0) + (displaySteps * 0.04).round();

    // Show Manual log if web, denied, or if Pedometer completely failed
    bool showManualFallback = kIsWeb || _activeStepEngine.contains("Manual") || _activeStepEngine.contains("Denied");

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
                children: [
                  Expanded(child: _buildCompactMetric("Steps Today", "$displaySteps", "/$stepGoal", Icons.directions_walk_rounded, Colors.orange, theme)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCompactMetric("Est. Burn", "$totalCals", "kcal", Icons.local_fire_department_rounded, Colors.redAccent, theme)),
                ]
            ),

            Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: Text("Source: $_activeStepEngine", style: TextStyle(fontSize: 9, color: theme.hintColor.withOpacity(0.5))),
            ),

            if (showManualFallback) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showManualStepDialog(displaySteps),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text("Log Steps Manually", style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showManualStepDialog(int currentSteps) {
    final TextEditingController stepController = TextEditingController(text: currentSteps > 0 ? currentSteps.toString() : "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Log Today's Steps", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: stepController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: "Total Steps",
            labelStyle: TextStyle(color: Theme.of(context).hintColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.directions_walk),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: Theme.of(context).hintColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              final int newSteps = int.tryParse(stepController.text) ?? 0;
              _syncStepsToDatabase(newSteps);
              Navigator.pop(ctx);
            },
            child: const Text("Save Steps", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(String label, String value, String suffix, IconData icon, Color color, ThemeData theme) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 16)),
              const SizedBox(height: 16),
              RichText(text: TextSpan(children: [
                TextSpan(text: value, style: TextStyle(fontFamily: kDisplayFont, fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface, letterSpacing: -0.5)),
                if (suffix.isNotEmpty) TextSpan(text: " $suffix", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: theme.hintColor))
              ])),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w500))
            ]
        )
    );
  }

  Widget _buildSmartTrendSection(ThemeData theme, ColorScheme colorScheme, WidgetRef ref) {
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.client.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SMART TRENDS", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.5))),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _trendOptions.map((metric) {
                final isSelected = _selectedTrendMetric == metric;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(metric, style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    backgroundColor: theme.cardColor,
                    elevation: 0,
                    side: BorderSide(color: isSelected ? Colors.transparent : theme.dividerColor.withOpacity(0.1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) { if (val) { HapticFeedback.selectionClick(); setState(() => _selectedTrendMetric = metric); } },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
            ),
            child: vitalsAsync.when(
                loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, s) => Center(child: Text("Data unavailable", style: TextStyle(fontFamily: kBodyFont, fontSize: 10, color: theme.hintColor))),
                data: (history) {
                  // 🚀 UPGRADE: Guarantee 7 days of data with Date Labels
                  DateTime now = DateTime.now();
                  List<double> values = [];
                  List<String> labels = [];

                  for (int i = 6; i >= 0; i--) {
                    DateTime currentDay = now.subtract(Duration(days: i));

                    // Add the Day Label (e.g., 'Mon', 'Tue')
                    labels.add(DateFormat('E').format(currentDay));

                    // Find if a record exists for this exact day
                    var recordsForDay = history.where((r) => DateUtils.isSameDay(r.date, currentDay));
                    var recordForDay = recordsForDay.isNotEmpty ? recordsForDay.first : null;

                    if (recordForDay != null) {
                      values.add(_getTrendValue(recordForDay, _selectedTrendMetric));
                    } else {
                      // 🚀 THE FIX: If they missed a day, show 0 so the graph dips accurately
                      values.add(0.0);
                    }
                  }

                  double maxVal = values.fold(10.0, (max, v) => v > max ? v : max) * 1.2;

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${_selectedTrendMetric.toUpperCase()} ANALYSIS", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 0.5)),
                          Text(_getTrendUnit(_selectedTrendMetric), style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 120, // Slightly taller to fit labels
                        width: double.infinity,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: TrendLinePainter(
                              data: values,
                              labels: labels, // 🚀 Pass the new labels here
                              maxVal: maxVal,
                              primaryColor: colorScheme.primary,
                              textColor: colorScheme.onSurface,
                              backgroundColor: theme.cardColor,
                              thresholds: _getClinicalThresholds(_selectedTrendMetric),
                            ),
                          ),
                        ),
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

  Widget _buildMedicalRecords(ThemeData theme, ColorScheme colorScheme, dynamic state) {
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("MEDICAL LOGS", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.5))),
          const SizedBox(height: 16),

          _buildHorizontalBar(
            "Self Check",
            "Log Weight, BP, or Sugar",
            Icons.monitor_heart_rounded,
            Colors.blueAccent,
                () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => LogVitalsSheet(notifier: notifier, activePlan: state.activePlan, dailyLog: state.dailyRecord),
              );
            },
            theme,
          ),
          const SizedBox(height: 12),

          _buildHorizontalBar(
            "Lab Reports",
            "Numerical trends & clinical history",
            Icons.biotech_rounded,
            colorScheme.primary,
                () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ClientVitalsHistorySheet(clientId: widget.client.id),
              );
            },
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBar(String title, String subtitle, IconData icon, Color color, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16)
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontFamily: kBodyFont, fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: theme.hintColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  double _getTrendValue(dynamic record, String metric) {
    try {
      switch (metric) {
        case 'Weight': return (record.weightKg ?? 0).toDouble();
        case 'Steps': return (record.stepCount ?? 0).toDouble();
        case 'Heart Rate': return (record.heartRateBpm ?? 0).toDouble();
        case 'Systolic': return (record.bloodPressureSystolic ?? 0).toDouble();
        case 'Diastolic': return (record.bloodPressureDiastolic ?? 0).toDouble();
        case 'FBS': return (record.fbsMgDl ?? 0).toDouble();
        case 'PPBS': return (record.ppbsMgDl ?? 0).toDouble();
        default: return 0.0;
      }
    } catch (e) { return 0.0; }
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

  List<double>? _getClinicalThresholds(String metric) {
    switch (metric) {
      case 'Heart Rate': return [60.0, 100.0];
      case 'Systolic': return [90.0, 120.0];
      case 'Diastolic': return [60.0, 80.0];
      case 'FBS': return [70.0, 100.0];
      case 'PPBS': return [0.0, 140.0];
      case 'Steps': return [8000.0, 8000.0];
      default: return null;
    }
  }
}

class TrendLinePainter extends CustomPainter {
  final List<double> data;
  final double maxVal;
  final List<String> labels;
  final Color primaryColor;
  final Color textColor;
  final Color backgroundColor;
  final List<double>? thresholds;

  TrendLinePainter({
    required this.data,
    required this.labels,
    required this.maxVal,
    required this.primaryColor,
    required this.textColor,
    required this.backgroundColor,
    this.thresholds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final bool isLiteMode = PerformanceManager.isLowEndDevice;
    final double width = size.width;
    final double height = size.height - 30;
    const double bottomOffset = 30.0;

    final double safeMax = maxVal <= 0 ? 1.0 : maxVal;

    if (thresholds != null && maxVal > 0) {
      double minT = thresholds![0];
      double maxT = thresholds!.length > 1 ? thresholds![1] : minT;

      double yMinLine = height - ((maxT / safeMax) * height) + bottomOffset;
      double yMaxLine = height - ((minT / safeMax) * height) + bottomOffset;

      if (minT != maxT) {
        final safeZonePaint = Paint()..color = Colors.green.withOpacity(0.08)..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTRB(0, yMinLine, width, yMaxLine), safeZonePaint);
      }

      _drawDashedLine(canvas, yMinLine, width, Colors.green.withOpacity(0.5));
      if (minT != maxT) {
        _drawDashedLine(canvas, yMaxLine, width, Colors.green.withOpacity(0.5));
      }
    }

    final Path path = Path();
    final Path fillPath = Path();

    if (data.length == 1) {
      double x = width / 2;
      double y = height - ((data[0] / safeMax) * height) + bottomOffset;
      _drawPointAndText(canvas, Offset(x, y), data[0]);
      return;
    }

    final double xStep = width / (data.length - 1);
    List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      double x = i * xStep;
      double y = height - ((data[i] / safeMax) * height) + bottomOffset;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length; i++) {
      // Draw the value bubble
      _drawPointAndText(canvas, points[i], data[i]);

      // 🚀 NEW: Draw the Day Label (Mon, Tue, etc.) underneath the point
      if (i < labels.length) {
        final TextPainter labelTp = TextPainter(
          text: TextSpan(
              text: labels[i],
              style: TextStyle(fontFamily: kBodyFont, color: textColor.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold)
          ),
          textDirection: TextDirection.ltr,
        );
        labelTp.layout();
        // Paint it near the very bottom edge of the canvas
        labelTp.paint(canvas, Offset(points[i].dx - (labelTp.width / 2), size.height - 15));
      }
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    if (!isLiteMode) {
      final Gradient gradient = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.0)],
      );

      canvas.drawPath(fillPath, Paint()
        ..shader = gradient.createShader(
            Rect.fromLTWH(0, 0, width, size.height)));
      // Draw path shadows only on high-end
      canvas.drawShadow(path, primaryColor.withOpacity(0.2), 3.0, false);
    }

    final Paint linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = isLiteMode ? 1.5 : 2.5 // 🚀 Thinner line is cheaper to render
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      _drawPointAndText(canvas, points[i], data[i]);
    }
  }

  void _drawDashedLine(Canvas canvas, double y, double width, Color color) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    double dashWidth = 4, dashSpace = 4, startX = 0;
    while (startX < width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  void _drawPointAndText(Canvas canvas, Offset point, double value) {
    if (value == 0) return;

    canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    canvas.drawCircle(point, 3, Paint()..color = primaryColor..strokeWidth = 2.0..style = PaintingStyle.stroke);

    String valText = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

    Color labelColor = textColor;
    if (thresholds != null) {
      if (value < thresholds![0] || (thresholds!.length > 1 && value > thresholds![1])) {
        labelColor = Colors.redAccent;
      }
    }

    final TextPainter tp = TextPainter(
      text: TextSpan(text: valText, style: TextStyle(fontFamily: kDisplayFont, color: labelColor, fontSize: 10, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final Rect bgRect = Rect.fromCenter(
        center: Offset(point.dx, point.dy - 16),
        width: tp.width + 10,
        height: tp.height + 4
    );

    final Paint bgPaint = Paint()..color = backgroundColor.withOpacity(0.9)..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), bgPaint);

    tp.paint(canvas, Offset(point.dx - (tp.width / 2), point.dy - 16 - (tp.height / 2)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}