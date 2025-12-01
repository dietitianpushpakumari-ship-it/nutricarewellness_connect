import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/custom_gradient_app_bar.dart';
import 'package:nutricare_connect/core/utils/coach_tab.dart';
import 'package:nutricare_connect/core/utils/feed_tab.dart';
import 'package:nutricare_connect/core/utils/mantra_uploader.dart';
import 'package:nutricare_connect/core/utils/modern_bottom_bar.dart';
import 'package:nutricare_connect/core/utils/profile_Screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/core/utils/wellness_hub_screen.dart';
import 'package:nutricare_connect/core/wave_clipper.dart';
import 'package:nutricare_connect/features/chat/presentation/client_chat_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/activity_tracker_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/breathing_excercise_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_log_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_reminder_setting_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/daily_wellness_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/diet_plan_dashboard_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/home_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/plan_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/tracker_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/water_quick_add_model.dart';
import 'package:nutricare_connect/features/dietplan/dATA/repositories/diet_repositories.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/programme_feature_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/schedule_meeting_utils.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';

// 🎯 ADJUST IMPORTS

// Import necessary core files
import '../../../../core/utils/geeta_uploader.dart';
import '../../../../services/client_service.dart';
import '../../domain/entities/client_diet_plan_model.dart';
import '../../domain/entities/client_log_model.dart';
import '../providers/diet_plan_provider.dart';
import 'package:nutricare_connect/main.dart';

// --- MOCK/CONCEPTUAL DATA STRUCTURES (Must be defined/imported elsewhere) ---

class ActivityData {
  final double waterL;
  final int steps;
  final int calories;

  // 🎯 NEW FIELDS: Daily Goals (Assumed to be set by Admin)
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
        // Preserve goals
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

// 🎯 FIX: Define the required list of standard sizes
const List<WaterSize> standardSizes = [
  WaterSize(label: 'Small Glass', volumeL: 0.25, icon: Icons.local_drink),
  WaterSize(
    label: 'Large Glass',
    volumeL: 0.40,
    icon: Icons.local_drink_outlined,
  ),
  WaterSize(label: 'Small Bottle', volumeL: 0.75, icon: Icons.water_drop),
  WaterSize(label: 'Big Bottle', volumeL: 1.0, icon: Icons.water_drop_outlined),
];

//final dietitianInfoProvider = Provider((ref) => DietitianInfo());
final activityDataProvider = StateProvider((ref) => ActivityData());

// 🎯 UPDATED PROVIDER:
//final activityDataProvider = StateProvider((ref) => ActivityData(
//  waterL: 1.5, steps: 4500, calories: 1200,
//goalWaterLiters: 3.0, // Admin sets 3.0L goal
//goalSteps: 8000 // Admin sets 8000 steps goal
//));
//final upcomingMeetingsProvider = Provider((ref) => [MeetingModel(startTime: DateTime.now().add(const Duration(days: 2)), id: '', clil(std: '', meetingType: '', purpose: '', createdAt: null, updatedAt: null)]);
// --------------------------------------------------------------------------

class ClientDashboardScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const ClientDashboardScreen({super.key, required this.client});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      ClientDashboardScreenState();
}

class ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  int _selectedIndex = 0;

  //late final List<Widget> _widgetOptions;
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
  // Inside _ClientDashboardScreenState...

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProfileFutureProvider);

    return clientAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (client) {
        if (client == null) return const Scaffold(body: Center(child: Text('Client not found.')));

        // 🎯 CLEANED UP WIDGET LIST (Matches the 5 Tabs)
        final List<Widget> widgetOptions = <Widget>[
          HomeScreen(client: client),              // 0: Home
          PlanScreen(client: client),              // 1: Plan
          ActivityTrackerScreen(client: client),   // 2: Move (The new Bento Screen)
          WellnessHubScreen(client: client),
          const FeedTab(),// 3: Wellness
          CoachTab(client: client),            // 4: Coach
        ];

        // --- Reminder Logic Listener (Kept same) ---
        ref.listen<DietPlanState>(activeDietPlanProvider, (prev, next) {
          if (!next.isLoading && next.activePlan != null) {
            localReminderService.reScheduleAllReminders(
                client: client,
                activePlan: next.activePlan,
                dailyLogs: next.dailyLogs
            );
          }
        });

        // 🎯 Logic: Only show AppBar if NOT on Home (Index 0)
        final bool showAppBar = _selectedIndex != 0;

        return Scaffold(
          // 🎯 Use extendBody so content flows behind the floating bar
          extendBody: true,

          appBar: showAppBar
              ? CustomGradientAppBar(
            title: Text(_getPageTitle(_selectedIndex)),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientLogHistoryScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              IconButton(onPressed :() { GeetaUploader().uploadGeetaBank();}, icon: const Icon(Icons.history),),
              IconButton(onPressed :() { MantraUploader().uploadMantras();}, icon: const Icon(Icons.history),)
            ],
          )
              : null,

          body: SafeArea(child: widgetOptions[_selectedIndex]),

          // 🎯 THE NEW FLOATING BAR
          bottomNavigationBar: SafeArea(child: ModernBottomBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          )),
        );
      },
    );
  }

  // Helper for Titles
  String _getPageTitle(int index) {
    switch (index) {
      case 1: return "My Meal Plan";
      case 2: return "Activity Hub";
      case 3: return "Wellness Center";
      case 4: return "My Coach";
      default: return "";
    }
  }

  void initialize() async {
    activePlan = await DietRepository().getActivePlan(widget.client.id);
  }

  void onItemTapped(int i) {
    _onItemTapped(2);
  }
}


// =================================================================
// --- TAB 3: CONTENT FEED (Notifications, Recipes, Offers) ---
// =================================================================
// ... (inside client_dashboard_main_screen.dart)

// 🎯 REBUILT: Progress Report Card (with Vitals)
// 🎯 REBUILT: Progress Report Card (with Vitals)
class _ProgressReportCard extends ConsumerStatefulWidget {
  final String clientId;
  const _ProgressReportCard({required this.clientId});

  @override
  ConsumerState<_ProgressReportCard> createState() => _ProgressReportCardState();
}

class _ProgressReportCardState extends ConsumerState<_ProgressReportCard> {
  int _selectedDays = 7;
  final List<int> _dayOptions = [7, 15, 30, 90];

  @override
  Widget build(BuildContext context) {
    // 🎯 Watch BOTH providers
    final dailyLogHistoryAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final vitalsHistoryAsync = ref.watch(vitalsHistoryProvider(widget.clientId)); // 🎯 NEW

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      child: ExpansionTile(
        leading: Icon(Icons.show_chart, color: colorScheme.secondary),
        title: const Text('Your Progress Report', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Showing trends from the last $_selectedDays days.'),
        children: [
          // --- 1. Date Range Filter Buttons ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
              ),
            ),
          ),

          vitalsHistoryAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
              data: (vitalsList) {
                final Map<String, double> weightData = {};
                final Map<String, double> fbsData = {};

                // Filter & Sort
                final startDate = DateTime.now().subtract(Duration(days: _selectedDays));
                final filtered = vitalsList.where((v) => !v.date.isBefore(startDate)).toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                for (final v in filtered) {
                  final dayLabel = DateFormat('d/M').format(v.date);
                  if (v.weightKg > 0) weightData[dayLabel] = v.weightKg;
                  if (v.labResults.containsKey('fbs')) {
                    final val = double.tryParse(v.labResults['fbs']!);
                    if (val != null) fbsData[dayLabel] = val;
                  }
                }

                if (weightData.isEmpty && fbsData.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(children: [
                    const Divider(),
                    if (weightData.isNotEmpty)
                      _buildChartContainer(context, 'Weight (kg)', _buildLineChart(context, weightData, {}, )),
                    if (fbsData.isNotEmpty)
                      _buildChartContainer(context, 'Fasting Sugar (mg/dL)', _buildLineChart(context, fbsData, {},)),
                  ]),
                );
              }
          ),


          // --- 2. Daily Logs Graph (Steps, Cals, etc.) ---
          dailyLogHistoryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading chart: $e', style: const TextStyle(color: Colors.red)),
            ),
            data: (groupedLogs) {
              // --- Data Processing ---
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
              // --- End Data Processing ---

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

          // --- 🎯 3. NEW: Vitals Graph (Blood Sugar & Weight) ---
          vitalsHistoryAsync.when(
              loading: () => const SizedBox.shrink(), // Don't show a second loader
              error: (e, s) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading vitals chart: $e', style: const TextStyle(color: Colors.red)),
              ),
              data: (vitalsList) {
                // Process data for the charts
                final Map<String, double> fbsData = {};
                final Map<String, double> ppbsData = {};
                final Map<String, double> weightData = {};
                final Map<String, double> bpSystolicData = {};
                final Map<String, double> bpDiastolicData = {};

                // Filter vitals to the selected date range
                final startDate = DateTime.now().subtract(Duration(days: _selectedDays));

                // Sort by date ascending to plot correctly
                final filteredVitals = vitalsList
                    .where((v) => !v.date.isBefore(startDate))
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                for (final vitals in filteredVitals) {
                  final dayLabel = DateFormat('d/M').format(vitals.date);

                  // Lab Results
                  if (double.tryParse(vitals.labResults['fbs'] ?? '') != null) {
                    fbsData[dayLabel] = double.parse(vitals.labResults['fbs']!);
                  }
                  if (double.tryParse(vitals.labResults['ppbs'] ?? '') != null) {
                    ppbsData[dayLabel] = double.parse(vitals.labResults['ppbs']!);
                  }

                  // At-Home Vitals
                  if (vitals.weightKg > 0) {
                    weightData[dayLabel] = vitals.weightKg;
                  }
                  if (vitals.bloodPressureSystolic != null) {
                    bpSystolicData[dayLabel] = vitals.bloodPressureSystolic!.toDouble();
                  }
                  if (vitals.bloodPressureDiastolic != null) {
                    bpDiastolicData[dayLabel] = vitals.bloodPressureDiastolic!.toDouble();
                  }
                }

                if (weightData.isEmpty && bpSystolicData.isEmpty && fbsData.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No Vitals data (Weight, BP, Sugar) logged for this period.', style: TextStyle(fontStyle: FontStyle.italic)),
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
    );
  }

  // --- Graph Builder Helpers ---

  Widget _buildChartContainer(BuildContext context, String title, Widget chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: chart),
      ],
    );
  }

  // 🎯 UPDATED: _buildLineChart

// ... inside _ProgressReportCardState class ...

  Widget _buildLineChart(BuildContext context, Map<String, double> data1, Map<String, double> data2, {bool isSleep = false, bool isSugar = false, bool isBloodPressure = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<FlSpot> spots1 = [];
    final List<FlSpot> spots2 = [];

    // Combine all keys and sort them to create a stable X-axis
    final allKeys = (data1.keys.toSet()..addAll(data2.keys)).toList();
    try {
      // Try to sort by date (d/M format)
      allKeys.sort((a, b) {
        final aDate = DateFormat('d/M').parse(a);
        final bDate = DateFormat('d/M').parse(b);
        return aDate.compareTo(bDate);
      });
    } catch (e) {
      // Fallback to simple string sort if parsing fails
      allKeys.sort();
    }

    // Create spots based on the sorted key index
    for (int i = 0; i < allKeys.length; i++) {
      final key = allKeys[i];
      if (data1.containsKey(key)) {
        spots1.add(FlSpot(i.toDouble(), data1[key]!));
      }
      if (data2.containsKey(key)) {
        spots2.add(FlSpot(i.toDouble(), data2[key]!));
      }
    }

    // ... (omitted color logic, it remains the same) ...
    Color color1 = colorScheme.primary; // Default: Steps
    Color color2 = Colors.red; // Default: Calories
    if (isSleep) color2 = colorScheme.secondary; // Hydration
    if (isSugar) {
      color1 = Colors.red.shade700; // FBS
      color2 = Colors.orange.shade700; // PPBS
    }
    if (isBloodPressure) {
      color1 = Colors.blue.shade700; // Systolic
      color2 = Colors.blue.shade300; // Diastolic
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                // Check bounds against the master key list
                if (index < 0 || index >= allKeys.length) return const SizedBox();

                // Logic to skip labels on dense charts
                if (_selectedDays > 10 && index % 3 != 0) return const SizedBox();

                // 🎯 CRITICAL FIX:
                // Removed 'axisSide: meta.axisSide'.
                // The 'meta' object is all that is required.
                return SideTitleWidget(
                  meta: meta, // ⬅️ THIS IS THE FIX
                  space: 8,
                  child: Text(allKeys[index], style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        lineBarsData: [
          // Line 1
          if(spots1.isNotEmpty)
            LineChartBarData(
              spots: spots1, isCurved: true, color: color1, barWidth: 4,
              isStrokeCapRound: true, dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color1.withOpacity(0.2)),
            ),
          // Line 2
          if(spots2.isNotEmpty)
            LineChartBarData(
              spots: spots2, isCurved: true, color: color2, barWidth: 4,
              isStrokeCapRound: true, dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color2.withOpacity(0.2)),
            ),
        ],
      ),
    );
  }

}

