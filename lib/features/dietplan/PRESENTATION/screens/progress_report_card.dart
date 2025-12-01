import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';

class ProgressReportCard extends ConsumerStatefulWidget {
  final String clientId;
  const ProgressReportCard({super.key, required this.clientId});

  @override
  ConsumerState<ProgressReportCard> createState() => _ProgressReportCardState();
}

class _ProgressReportCardState extends ConsumerState<ProgressReportCard> with SingleTickerProviderStateMixin {
  int _selectedDays = 7;
  bool _isExpanded = true; // Expanded by default for engagement
  final List<int> _dayOptions = [7, 15, 30, 90];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Watch Data
    final dailyLogHistoryAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final vitalsHistoryAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), // Add margin for shadow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. PREMIUM HEADER (Custom, no ExpansionTile borders)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_graph_rounded, color: Colors.indigo, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Progress Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        Text("Trends from last $_selectedDays days", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),

          // 2. EXPANDABLE CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),

                // Filter Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: _dayOptions.map((days) => ButtonSegment<int>(
                        value: days,
                        label: Text('$days D', style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      selected: {_selectedDays},
                      onSelectionChanged: (Set<int> newSelection) => setState(() => _selectedDays = newSelection.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return Colors.indigo.shade50;
                          return Colors.white;
                        }),
                        foregroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return Colors.indigo;
                          return Colors.grey;
                        }),
                        side: MaterialStateProperty.all(BorderSide(color: Colors.grey.shade200)),
                      ),
                    ),
                  ),
                ),

                // CHARTS
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Activity Chart
                      dailyLogHistoryAsync.when(
                        loading: () => const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
                        error: (_,__) => const Text("Could not load activity data"),
                        data: (groupedLogs) => _buildActivityCharts(groupedLogs, context),
                      ),

                      const SizedBox(height: 24),

                      // Vitals Chart
                      vitalsHistoryAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_,__) => const SizedBox.shrink(),
                        data: (vitalsList) => _buildVitalsCharts(vitalsList, context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCharts(Map<DateTime, List<dynamic>> groupedLogs, BuildContext context) {
    final Map<String, double> stepData = {};
    final Map<String, double> sleepData = {};

    final sortedDates = groupedLogs.keys.toList()..sort();
    for (var date in sortedDates) {
      final dayLabel = DateFormat('d/M').format(date);
      final log = groupedLogs[date]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
      stepData[dayLabel] = (log?.stepCount ?? 0).toDouble();
      sleepData[dayLabel] = (log?.totalSleepDurationHours ?? 0).toDouble();
    }

    if (stepData.isEmpty) return const Text("No activity logged yet.", style: TextStyle(color: Colors.grey));

    return Column(
      children: [
        _buildChartSection("Steps Walked", stepData, Colors.orange),
        const SizedBox(height: 20),
        _buildChartSection("Sleep (Hours)", sleepData, Colors.purple),
      ],
    );
  }

  Widget _buildVitalsCharts(List<dynamic> vitalsList, BuildContext context) {
    final Map<String, double> weightData = {};
    final startDate = DateTime.now().subtract(Duration(days: _selectedDays));
    final filtered = vitalsList.where((v) => !v.date.isBefore(startDate)).toList()..sort((a, b) => a.date.compareTo(b.date));

    for (final v in filtered) {
      final dayLabel = DateFormat('d/M').format(v.date);
      if (v.weightKg > 0) weightData[dayLabel] = v.weightKg;
    }

    if (weightData.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(height: 30),
        _buildChartSection("Weight Trend (kg)", weightData, Colors.indigo),
      ],
    );
  }

  Widget _buildChartSection(String title, Map<String, double> data, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 16),
        SizedBox(height: 160, child: _buildLineChart(data, color)),
      ],
    );
  }

  Widget _buildLineChart(Map<String, double> data, Color color) {
    final List<FlSpot> spots = [];
    final allKeys = data.keys.toList();

    for (int i = 0; i < allKeys.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[allKeys[i]]!));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (val, meta) {
            final index = val.toInt();
            if (index < 0 || index >= allKeys.length) return const SizedBox();
            if (_selectedDays > 10 && index % 3 != 0) return const SizedBox(); // Skip labels
            return SideTitleWidget(meta: meta, space: 8, child: Text(allKeys[index], style: const TextStyle(fontSize: 10, color: Colors.grey)));
          })),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide Y axis
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false), // No border
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.blueGrey.shade800,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) => LineTooltipItem("${spot.y}", const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList();
              }
          ),
        ),
      ),
    );
  }
}