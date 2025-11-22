import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:collection/collection.dart';

class AnalyticsDetailSheet extends ConsumerStatefulWidget {
  final String clientId;
  const AnalyticsDetailSheet({super.key, required this.clientId});

  @override
  ConsumerState<AnalyticsDetailSheet> createState() => _AnalyticsDetailSheetState();
}

class _AnalyticsDetailSheetState extends ConsumerState<AnalyticsDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // 1. Handle & Header
          const SizedBox(height: 16),

          const SizedBox(height: 16),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🎯 FIX 1: Wrap Title in Expanded to prevent overflow
                const Expanded(
                  child: Text(
                    "Health Analytics",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, // Adds "..." if space is tight
                  ),
                ),

                const SizedBox(width: 12), // Space between title and buttons

                // Range Toggle
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // 🎯 FIX 2: Keep buttons compact
                    children: [
                      _buildRangeBtn(7, "Week"),
                      _buildRangeBtn(30, "Month"),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            tabs: const [
              Tab(text: "Activity"),
              Tab(text: "Body"),
              Tab(text: "Sleep"),
            ],
          ),

          // 3. Charts Content
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (logs) => TabBarView(
                controller: _tabController,
                children: [
                  _buildActivityTab(logs),
                  vitalsAsync.when(
                    data: (vitals) => _buildBodyTab(vitals),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_,__) => const SizedBox(),
                  ),
                  _buildSleepTab(logs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeBtn(int days, String label) {
    final isSelected = _selectedDays == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey)),
      ),
    );
  }

  // --- TABS ---

  Widget _buildActivityTab(Map<DateTime, List<ClientLogModel>> groupedLogs) {
    final spots = _generateSpots(groupedLogs, (log) => (log?.stepCount ?? 0).toDouble());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatHeader("Steps Trend", "Keep it moving!"),
          const SizedBox(height: 20),
          Expanded(child: _buildLineChart(spots, Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildBodyTab(List<dynamic> vitalsList) {
    // Assuming vitalsList is sorted or handled in provider
    List<FlSpot> spots = [];
    int index = 0;
    for (var v in vitalsList.take(_selectedDays)) { // Simplification
      spots.add(FlSpot(index.toDouble(), v.weightKg));
      index++;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatHeader("Weight History", "Track your progress."),
          const SizedBox(height: 20),
          Expanded(child: _buildLineChart(spots, Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildSleepTab(Map<DateTime, List<ClientLogModel>> groupedLogs) {
    final spots = _generateSpots(groupedLogs, (log) => (log?.totalSleepDurationHours ?? 0).toDouble());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatHeader("Sleep Duration", "Rest is recovery."),
          const SizedBox(height: 20),
          Expanded(child: _buildBarChart(spots, Colors.indigo)),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildStatHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ],
    );
  }

  List<FlSpot> _generateSpots(Map<DateTime, List<ClientLogModel>> logs, double Function(ClientLogModel?) valueExtractor) {
    List<FlSpot> spots = [];
    int index = 0;

    // Iterate backwards from today to show chronological left-to-right
    for (int i = _selectedDays - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dayKey = DateTime(date.year, date.month, date.day);
      final log = logs[dayKey]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
      spots.add(FlSpot(index.toDouble(), valueExtractor(log)));
      index++;
    }
    return spots;
  }

  Widget _buildLineChart(List<FlSpot> spots, Color color) {
    if (spots.every((s) => s.y == 0)) return const Center(child: Text("No data logged yet."));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<FlSpot> spots, Color color) {
    if (spots.every((s) => s.y == 0)) return const Center(child: Text("No data logged yet."));

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: spots.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(toY: e.value.y, color: color, width: 12, borderRadius: BorderRadius.circular(4))],
          );
        }).toList(),
      ),
    );
  }
}