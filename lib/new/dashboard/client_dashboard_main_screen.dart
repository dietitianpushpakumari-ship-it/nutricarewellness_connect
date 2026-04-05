import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/custom_gradient_app_bar.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/chat/client_chat_screen.dart';
import 'package:nutricare_connect/new/coach/coach_tab.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/new/feed/feed_tab.dart';
import 'package:nutricare_connect/core/utils/mantra_uploader.dart';
import 'package:nutricare_connect/new/dashboard/modern_bottom_bar.dart';
import 'package:nutricare_connect/new/dashboard/profile_Screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/new/wellnesshub/wellness_hub_screen.dart';
import 'package:nutricare_connect/new/activityhub/activity_tracker_screen.dart' hide vitalsHistoryProvider;
import 'package:nutricare_connect/new/dashboard/home_screen.dart';
import 'package:nutricare_connect/new/dietplan/plan_screen.dart';
import 'package:nutricare_connect/new/repositories/diet_repositories.dart';
import 'package:collection/collection.dart';

// Import necessary core files
import '../../core/utils/geeta_uploader.dart';
import '../service/client_service.dart';
// FlatClientDietPlanModel
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

final unreadChatCountProvider = StreamProvider.autoDispose<int>((ref) {
  final clientId = ref.watch(currentClientIdProvider);

  if (clientId == null || clientId.isEmpty) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('clients')
      .doc(clientId)
      .collection('chat')
      .where('isSenderClient', isEqualTo: false)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

class ClientDashboardScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const ClientDashboardScreen({super.key, required this.client});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      ClientDashboardScreenState();
}

class ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  int _selectedIndex = 0;

  // 🚀 THE FIX: Strongly typed to Flat Model
  FlatClientDietPlanModel? activePlan;

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
    final unreadCountAsync = ref.watch(unreadChatCountProvider);
    final int unreadCount = unreadCountAsync.value ?? 0;

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
          HomeScreen(client: client),
          PlanScreen(client: client),
          ActivityTrackerScreen(client: client),
          WellnessHubScreen(client: client),
          const FeedTab(),
          ClientChatScreen(clientName: client.name!),
          CoachTab(client: client),
        ];

        ref.listen<DietPlanState>(activeDietPlanProvider, (prev, next) {
          if (!next.isLoading && next.activePlan != null) {
            localReminderService.reScheduleAllReminders(
                client: client,
                activePlan: next.activePlan,
                dailyRecord: next.dailyRecord
            );
          }
        });

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          extendBody: true,
          body: widgetOptions[_selectedIndex],
          bottomNavigationBar: SafeArea(
            child: ModernBottomBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              unreadChatCount: unreadCount,
            ),
          ),);
      },
    );
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
      decoration: _getGlassDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Theme(
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

            // 1. DAILY LOGS CHART (Steps, Calories, Sleep, Hydration)
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
                  final log = groupedLogs[date];

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

            // 2. CLINICAL VITALS CHART (Weight, BP, Sugar)
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

  Widget _buildChartContainer(BuildContext context, String title, Widget chart) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface
            )
        ),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: chart),
      ],
    );
  }

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
          show: true,
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
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6))
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
                          style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6))
                      ),
                    );
                  }
              )
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
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