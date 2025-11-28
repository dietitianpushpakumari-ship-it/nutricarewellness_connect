import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_vitals_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';

class AnalyticsDetailSheet extends ConsumerWidget {
  final String clientId;
  const AnalyticsDetailSheet({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historicalLogProvider((clientId: clientId, days: 14)));
    // 🎯 Also fetch Vitals History if you have a provider for it, otherwise we rely on logs
    // final vitalsAsync = ref.watch(clientVitalsHistoryProvider(clientId));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(color: Color(0xFFF8F9FE), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Wellness Report", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Error: $e")),
                data: (logs) {
                  final sortedDates = logs.keys.toList()..sort();
                  // Convert Map to List for charts
                  final dataPoints = sortedDates.map((d) => logs[d]?.firstWhere((l) => l.mealName == 'DAILY_WELLNESS_CHECK', orElse: () => ClientLogModel(clientId: clientId, dietPlanId: '', date: d, mealName: ''))).toList();

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildSectionTitle("Consistency Score"),
                      _buildChartCard(
                        height: 200,
                        child: BarChart(_buildScoreChart(dataPoints)),
                      ),

                      _buildSectionTitle("Weight Trend"),
                      _buildChartCard(
                        height: 180,
                        child: LineChart(_buildWeightChart(dataPoints)),
                      ),

                      _buildSectionTitle("Activity & Sleep"),
                      _buildStatRow(dataPoints),

                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({required double height, required Widget child}) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));

  // ... (Chart Building Logic for BarChartData and LineChartData) ...
  // Simplified for brevity - maps dataPoints to FlSpot(index, value)
  BarChartData _buildScoreChart(List<ClientLogModel?> data) {
    // Map activityScore to Bars
    return BarChartData(
      // ... config
        barGroups: List.generate(data.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (data[i]?.activityScore ?? 0).toDouble())]))
    );
  }

  LineChartData _buildWeightChart(List<ClientLogModel?> data) {
    // Map weightKg to Line
    return LineChartData(
      // ... config
        lineBarsData: [LineChartBarData(spots: List.generate(data.length, (i) {
          final w = data[i]?.weightKg ?? 0.0;
          return FlSpot(i.toDouble(), w > 0 ? w : 0); // Handle missing data
        }))]
    );
  }

  Widget _buildStatRow(List<ClientLogModel?> data) {
    // Calculate averages
    int totalSteps = 0;
    double totalSleep = 0;
    int count = 0;
    for(var l in data) {
      if(l != null) {
        totalSteps += l.stepCount ?? 0;
        totalSleep += l.totalSleepDurationHours ?? 0;
        count++;
      }
    }
    int avgSteps = count > 0 ? totalSteps ~/ count : 0;
    double avgSleep = count > 0 ? totalSleep / count : 0;

    return Row(
      children: [
        Expanded(child: _buildStatTile("Avg Steps", "$avgSteps", Icons.directions_run, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatTile("Avg Sleep", "${avgSleep.toStringAsFixed(1)}h", Icons.bedtime, Colors.indigo)),
      ],
    );
  }

  Widget _buildStatTile(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [Icon(icon, color: color), const SizedBox(height: 8), Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
    );
  }
}