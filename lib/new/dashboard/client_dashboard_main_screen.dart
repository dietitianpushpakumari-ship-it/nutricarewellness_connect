import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/custom_gradient_app_bar.dart';
import 'package:nutricare_connect/core/localization/localization_extension.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/features/appointments/coach_tab.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/features/content/feed_tab.dart';
import 'package:nutricare_connect/core/utils/mantra_uploader.dart';
import 'package:nutricare_connect/new/dashboard/modern_bottom_bar.dart';
import 'package:nutricare_connect/features/profile/profile_Screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/core/utils/wellness_hub_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/activity_tracker_screen.dart';
import 'package:nutricare_connect/new/dashboard/home_screen.dart';
import 'package:nutricare_connect/features/diet_plan/plan_screen.dart';
import 'package:nutricare_connect/new/repositories/diet_repositories.dart';
import 'package:collection/collection.dart';

// Import necessary core files
import '../../core/utils/geeta_uploader.dart';
import '../../features/auth/client_service.dart';
import '../models/client_diet_plan_model.dart';
import '../../features/dietplan/domain/entities/client_log_model.dart';
import '../provider/diet_plan_provider.dart';
import 'package:nutricare_connect/main.dart';

// --- MOCK/CONCEPTUAL DATA STRUCTURES ---
class ActivityData {
  final double waterL;
  final int steps;
  final int calories;
  final double goalWaterLiters;
  final int goalSteps;

  ActivityData({
    this.waterL = 1.5,
    this.steps = 4500,
    this.calories = 1200,
    this.goalWaterLiters = 3.0,
    this.goalSteps = 8000,
  });

  ActivityData copyWith({double? waterL, int? steps, int? calories}) =>
      ActivityData(
        waterL: waterL ?? this.waterL,
        steps: steps ?? this.steps,
        calories: calories ?? this.calories,
        goalWaterLiters: goalWaterLiters,
        goalSteps: goalSteps,
      );
}

class WaterSize {
  final String label;
  final double volumeL;
  final IconData icon;

  const WaterSize({
    required this.label,
    required this.volumeL,
    required this.icon,
  });
}

const List<WaterSize> standardSizes = [
  WaterSize(label: 'Small Glass', volumeL: 0.25, icon: Icons.local_drink),
  WaterSize(label: 'Large Glass', volumeL: 0.40, icon: Icons.local_drink_outlined),
  WaterSize(label: 'Small Bottle', volumeL: 0.75, icon: Icons.water_drop),
  WaterSize(label: 'Big Bottle', volumeL: 1.0, icon: Icons.water_drop_outlined),
];

final activityDataProvider = StateProvider((ref) => ActivityData());

class ClientDashboardScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const ClientDashboardScreen({super.key, required this.client});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      ClientDashboardScreenState();
}

class ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  int _selectedIndex = 0;
  ClientDietPlanModel? activePlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SyncManager().checkAppLaunchSync();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProfileFutureProvider);

    // 🎯 THEME VARIABLES
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return clientAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: Text('Error: $err', style: TextStyle(color: colorScheme.error))),
      ),
      data: (client) {
        if (client == null) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: const Center(child: Text('Client not found.')));

        final List<Widget> widgetOptions = <Widget>[
          HomeScreen(client: client),              // 0: Home
          PlanScreen(client: client),              // 1: Plan
          ActivityTrackerScreen(client: client),   // 2: Move
          WellnessHubScreen(client: client),       // 3: Wellness
          const FeedTab(),                         // 4: Feed
          CoachTab(client: client),                // 5: Coach
        ];

        ref.listen<DietPlanState>(activeDietPlanProvider, (prev, next) {
          if (!next.isLoading && next.activePlan != null) {
            localReminderService.reScheduleAllReminders(
                client: client,
                activePlan: next.activePlan,
                dailyLogs: next.dailyLogs
            );
          }
        });

        // Only show AppBar on non-Home screens
        final bool showAppBar = _selectedIndex != 0;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          extendBody: true,

          // 🎯 FIXED: CONSISTENT APP BAR
          appBar: showAppBar
              ? AppBar(
            // 1. Force Left Alignment to match page headers
            centerTitle: false,

            // 2. Remove default back button spacing issues
            titleSpacing: 20,

            // 3. Match Text Style to Page Headers
            title: Text(
              _getPageTitle(_selectedIndex),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, // Extra bold for consistency
                fontSize: 22,
                color: colorScheme.onSurface,
              ),
            ),

            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0, // Keep flat on scroll
            iconTheme: IconThemeData(color: colorScheme.onSurface),

            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              // Only show dev tools if needed, or keep hidden/conditional
              IconButton(
                onPressed: () { MantraUploader().uploadMantras(); },
                icon: const Icon(Icons.self_improvement),
              )
            ],
          )
              : null,

          body:  widgetOptions[_selectedIndex],

          // 🎯 Floating Glass Bottom Bar
          bottomNavigationBar: SafeArea(child: ModernBottomBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          )),
        );
      },
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 1: return context.tr("My Meal Plan");
      case 2: return context.tr("Activity Hub");
      case 3: return context.tr("Wellness Center");
      case 4: return "Feed"; // Added Feed Title
      case 5: return context.tr("My Coach");
      default: return "";
    }
  }
}

// =================================================================
// 🎯 PREMIUM GLASSMORPHIC PROGRESS REPORT CARD
// =================================================================

class _ProgressReportCard extends ConsumerStatefulWidget {
  final String clientId;
  const _ProgressReportCard({required this.clientId});

  @override
  ConsumerState<_ProgressReportCard> createState() => _ProgressReportCardState();
}

class _ProgressReportCardState extends ConsumerState<_ProgressReportCard> {
  int _selectedDays = 7;
  final List<int> _dayOptions = [7, 15, 30, 90];

  // 🎯 Reusable Glass Decoration Helper
  BoxDecoration _getGlassDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color baseColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    Color borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.4);

    if (theme.cardTheme.shape is RoundedRectangleBorder) {
      borderColor = (theme.cardTheme.shape as RoundedRectangleBorder).side.color;
    }

    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(24.0),
      border: Border.all(color: borderColor, width: 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dailyLogHistoryAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final vitalsHistoryAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: _getGlassDecoration(context), // 🎯 Apply Glass Look
      clipBehavior: Clip.antiAlias, // Keep expansion ripple inside borders
      child: Theme(
        // 🎯 Removes the ugly default divider lines from ExpansionTile
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: colorScheme.primary,
          collapsedIconColor: colorScheme.onSurface.withOpacity(0.6),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.show_chart, color: colorScheme.primary, size: 20),
          ),
          title: Text(
              'Your Progress Report',
              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)
          ),
          subtitle: Text(
              'Showing trends from the last $_selectedDays days.',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)
          ),
          children: [
            // --- 1. Date Range Filter Buttons ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SegmentedButton<int>(
                segments: _dayOptions.map((days) => ButtonSegment<int>(
                  value: days,
                  label: Text('$days D'),
                )).toList(),
                selected: {_selectedDays},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() { _selectedDays = newSelection.first; });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: colorScheme.primary.withOpacity(0.2),
                  selectedForegroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onSurface,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
                ),
              ),
            ),

            // --- 2. Vitals Line Chart ---
            vitalsHistoryAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (vitalsList) {
                  final Map<String, double> weightData = {};
                  final Map<String, double> fbsData = {};

                  final startDate = DateTime.now().subtract(Duration(days: _selectedDays));
                  final filtered = vitalsList.where((v) => !v.date.isBefore(startDate)).toList()
                    ..sort((a, b) => a.date.compareTo(b.date));

                  for (final v in filtered) {
                    final dayLabel = DateFormat('d/M').format(v.date);
                    if (v.weightKg > 0) weightData[dayLabel] = v.weightKg;

                    // 🎯 FIX: Direct access to map value (it is already double)
                    if (v.labResults.containsKey('fbs')) {
                      final val = v.labResults['fbs'];
                      if (val != null) fbsData[dayLabel] = val;
                    }
                  }

                  if (weightData.isEmpty && fbsData.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(children: [
                      Divider(color: colorScheme.onSurface.withOpacity(0.1)),
                      if (weightData.isNotEmpty)
                        _buildChartContainer(context, 'Weight (kg)', _buildLineChart(context, weightData, {})),
                      if (fbsData.isNotEmpty)
                        _buildChartContainer(context, 'Fasting Sugar (mg/dL)', _buildLineChart(context, fbsData, {})),
                    ]),
                  );
                }
            ),

            // --- 3. Daily Logs Graph (Steps, Cals, etc.) ---
            dailyLogHistoryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, s) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading chart: $e', style: TextStyle(color: colorScheme.error)),
              ),
              data: (groupedLogs) {
                final Map<String, double> stepData = {};
                final Map<String, double> calorieData = {};
                final Map<String, double> sleepData = {};
                final Map<String, double> hydrationData = {};

                final sortedDates = groupedLogs.keys.toList()..sort();

                for (var date in sortedDates) {
                  final dayLabel = DateFormat('d/M').format(date);
                  final log = groupedLogs[date]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

                  stepData[dayLabel] = (log?.stepCount ?? 0).toDouble();
                  calorieData[dayLabel] = (log?.caloriesBurned ?? 0).toDouble();
                  sleepData[dayLabel] = (log?.totalSleepDurationHours ?? 0).toDouble();
                  hydrationData[dayLabel] = (log?.hydrationLiters ?? 0).toDouble();
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildChartContainer(context, 'Steps & Calories Burned', _buildLineChart(context, stepData, calorieData)),
                      const SizedBox(height: 20),
                      _buildChartContainer(context, 'Sleep Duration & Hydration', _buildLineChart(context, sleepData, hydrationData, isSleep: true)),
                    ],
                  ),
                );
              },
            ),

            // --- 4. Deep Vitals Graph (Blood Sugar & Weight) ---
            vitalsHistoryAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading vitals chart: $e', style: TextStyle(color: colorScheme.error)),
                ),
                data: (vitalsList) {
                  final Map<String, double> fbsData = {};
                  final Map<String, double> ppbsData = {};
                  final Map<String, double> weightData = {};
                  final Map<String, double> bpSystolicData = {};
                  final Map<String, double> bpDiastolicData = {};

                  final startDate = DateTime.now().subtract(Duration(days: _selectedDays));
                  final filteredVitals = vitalsList
                      .where((v) => !v.date.isBefore(startDate))
                      .toList()
                    ..sort((a, b) => a.date.compareTo(b.date));

                  for (final vitals in filteredVitals) {
                    final dayLabel = DateFormat('d/M').format(vitals.date);

                    // 🎯 FIX: Removing double.parse() wrappers.
                    // labResults is Map<String, double>, so values are ALREADY doubles.

                    if (vitals.labResults['fbs'] != null) {
                      fbsData[dayLabel] = vitals.labResults['fbs']!;
                    }
                    if (vitals.labResults['ppbs'] != null) {
                      ppbsData[dayLabel] = vitals.labResults['ppbs']!;
                    }
                    if (vitals.weightKg > 0) weightData[dayLabel] = vitals.weightKg;
                    if (vitals.bloodPressureSystolic != null) {
                      bpSystolicData[dayLabel] = vitals.bloodPressureSystolic!.toDouble();
                    }
                    if (vitals.bloodPressureDiastolic != null) {
                      bpDiastolicData[dayLabel] = vitals.bloodPressureDiastolic!.toDouble();
                    }
                  }

                  if (weightData.isEmpty && bpSystolicData.isEmpty && fbsData.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          'No Vitals data (Weight, BP, Sugar) logged for this period.',
                          style: TextStyle(fontStyle: FontStyle.italic, color: colorScheme.onSurface.withOpacity(0.5))
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (weightData.isNotEmpty) ...[
                          _buildChartContainer(context, 'Weight Progress (kg)', _buildLineChart(context, weightData, {})),
                          const SizedBox(height: 20),
                        ],
                        if (bpSystolicData.isNotEmpty) ...[
                          _buildChartContainer(context, 'Blood Pressure (mmHg)', _buildLineChart(context, bpSystolicData, bpDiastolicData, isBloodPressure: true)),
                          const SizedBox(height: 20),
                        ],
                        if (fbsData.isNotEmpty || ppbsData.isNotEmpty) ...[
                          _buildChartContainer(context, 'Blood Sugar (mg/dL)', _buildLineChart(context, fbsData, ppbsData, isSugar: true)),
                        ],
                      ],
                    ),
                  );
                }
            ),
          ],
        ),
      ),
    );
  }

  // --- Graph Builder Helpers ---

  Widget _buildChartContainer(BuildContext context, String title, Widget chart) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface // 🎯 Adaptive Text
            )
        ),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: chart),
      ],
    );
  }

  // 🎯 THEME-ADAPTIVE CHART BUILDER
  Widget _buildLineChart(BuildContext context, Map<String, double> data1, Map<String, double> data2, {bool isSleep = false, bool isSugar = false, bool isBloodPressure = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<FlSpot> spots1 = [];
    final List<FlSpot> spots2 = [];

    final allKeys = (data1.keys.toSet()..addAll(data2.keys)).toList();
    try {
      allKeys.sort((a, b) {
        final aDate = DateFormat('d/M').parse(a);
        final bDate = DateFormat('d/M').parse(b);
        return aDate.compareTo(bDate);
      });
    } catch (e) {
      allKeys.sort();
    }

    for (int i = 0; i < allKeys.length; i++) {
      final key = allKeys[i];
      if (data1.containsKey(key)) spots1.add(FlSpot(i.toDouble(), data1[key]!));
      if (data2.containsKey(key)) spots2.add(FlSpot(i.toDouble(), data2[key]!));
    }

    Color color1 = colorScheme.primary;
    Color color2 = isDark ? Colors.redAccent : Colors.red;
    if (isSleep) color2 = colorScheme.secondary;
    if (isSugar) {
      color1 = isDark ? Colors.redAccent : Colors.red.shade700;
      color2 = isDark ? Colors.orangeAccent : Colors.orange.shade700;
    }
    if (isBloodPressure) {
      color1 = isDark ? Colors.blueAccent : Colors.blue.shade700;
      color2 = isDark ? Colors.lightBlueAccent : Colors.blue.shade300;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true, // 🎯 Added subtle grid lines for premium look
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.onSurface.withOpacity(0.05),
              strokeWidth: 1,
              dashArray: [5, 5]
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= allKeys.length) return const SizedBox();
                if (_selectedDays > 10 && index % 3 != 0) return const SizedBox();

                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                      allKeys[index],
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6)) // 🎯 Adaptive text
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 8,
                      child: Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6)) // 🎯 Adaptive text
                      ),
                    );
                  }
              )
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        // 🎯 Adaptive chart border
        borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: colorScheme.onSurface.withOpacity(0.2), width: 1),
              left: BorderSide(color: colorScheme.onSurface.withOpacity(0.2), width: 1),
              right: BorderSide.none,
              top: BorderSide.none,
            )
        ),
        lineBarsData: [
          if(spots1.isNotEmpty)
            LineChartBarData(
              spots: spots1, isCurved: true, color: color1, barWidth: 3,
              isStrokeCapRound: true, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color1.withOpacity(0.15)),
            ),
          if(spots2.isNotEmpty)
            LineChartBarData(
              spots: spots2, isCurved: true, color: color2, barWidth: 3,
              isStrokeCapRound: true, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color2.withOpacity(0.15)),
            ),
        ],
      ),
    );
  }
}