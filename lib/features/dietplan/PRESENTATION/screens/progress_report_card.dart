// lib/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart

// 🎯 ADD/VERIFY THIS IMPORT for the charts
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';

// lib/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart

// 🎯 ADD/VERIFY THIS IMPORT for the charts
import 'package:fl_chart/fl_chart.dart';

// ... (omitted other classes and imports) ...

// 🎯 NEW WIDGET (Place inside _HomeScreenState or as a top-level widget)
class ProgressReportCard extends ConsumerStatefulWidget {
  final String clientId;
  const ProgressReportCard({required this.clientId});

  @override
  ConsumerState<ProgressReportCard> createState() => _ProgressReportCardState();
}

class _ProgressReportCardState extends ConsumerState<ProgressReportCard> {
  // 🎯 State for the date range filter
  int _selectedDays = 7;
  final List<int> _dayOptions = [7, 15,30]; // Last 7, 15, 30, 90 days

  @override
  Widget build(BuildContext context) {
    // 🎯 Watch the new provider with the selected day range
    final historyAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
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
                setState(() {
                  _selectedDays = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: colorScheme.primary.withOpacity(0.2),
                selectedForegroundColor: colorScheme.primary,
              ),
            ),
          ),

          // --- 2. Async Graph Builder ---
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading chart: $e', style: const TextStyle(color: Colors.red)),
            ),
            data: (groupedLogs) {
              // --- 3. Data Processing ---
              final Map<String, double> stepData = {};
              final Map<String, double> hydrationData = {};
              final Map<String, double> sleepData = {};
              final Map<String, double> calorieData = {};

              // Create entries for all days in the range, even if empty
              for (int i = _selectedDays - 1; i >= 0; i--) {
                final date = DateTime.now().subtract(Duration(days: i));
                final dayKey = DateTime(date.year, date.month, date.day);
                final dayLabel = DateFormat('d/M').format(date); // "10/11"

                final log = groupedLogs[dayKey]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

                stepData[dayLabel] = log?.stepCount?.toDouble() ?? 0;
                hydrationData[dayLabel] = log?.hydrationLiters ?? 0;
                sleepData[dayLabel] = log?.totalSleepDurationHours ?? 0;
                calorieData[dayLabel] = log?.caloriesBurned?.toDouble() ?? 0;
              }

              if (stepData.isEmpty) {
                return const Center(child: Text('No data for this period.'));
              }

              // --- 4. Graph Display ---
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

  // 🎯 THIS IS THE CORRECTED METHOD
  Widget _buildLineChart(BuildContext context, Map<String, double> data1, Map<String, double> data2, {bool isSleep = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<FlSpot> spots1 = [];
    final List<FlSpot> spots2 = [];

    int index = 0;
    for (var entry in data1.entries) {
      spots1.add(FlSpot(index.toDouble(), entry.value));
      index++;
    }

    index = 0;
    for (var entry in data2.entries) {
      spots2.add(FlSpot(index.toDouble(), entry.value));
      index++;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              // 🎯 CRITICAL FIX: Remove SideTitleWidget wrapper
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data1.keys.length) return const SizedBox();

                // Show labels every few days to avoid clutter
                if (_selectedDays > 10 && index % 3 != 0) return const SizedBox();

                // 🎯 Just return the Text widget directly
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(data1.keys.elementAt(index), style: const TextStyle(fontSize: 10)),
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
          // Line 1 (e.g., Steps or Sleep)
          LineChartBarData(
            spots: spots1,
            isCurved: true,
            color: colorScheme.primary, // Emerald
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: colorScheme.primary.withOpacity(0.2)),
          ),
          // Line 2 (e.g., Calories or Hydration)
          LineChartBarData(
            spots: spots2,
            isCurved: true,
            color: isSleep ? colorScheme.secondary : Colors.red, // Sapphire or Red
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: (isSleep ? colorScheme.secondary : Colors.red).withOpacity(0.2)),
          ),
        ],
      ),
    );
  }
}