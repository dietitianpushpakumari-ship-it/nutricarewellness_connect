import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/analytics_detail_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';

import 'package:collection/collection.dart';

class WellnessTrendsCard extends ConsumerWidget {
  final String clientId;
  const WellnessTrendsCard({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always fetch last 7 days for the summary card
    final historyAsync = ref.watch(historicalLogProvider((clientId: clientId, days: 7)));

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AnalyticsDetailSheet(clientId: clientId),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Weekly Consistency", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Your daily wellness score", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Icon(Icons.bar_chart, color: Colors.teal.shade300),
              ],
            ),
            const SizedBox(height: 20),

            // The Mini Chart
            SizedBox(
              height: 120,
              child: historyAsync.when(
                loading: () => const SizedBox(), // Fade in later
                error: (_, __) => const SizedBox(),
                data: (logs) {
                  return BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final date = DateTime.now().subtract(Duration(days: 6 - val.toInt()));
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('E').format(date)[0], style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (index) {
                        // Calculate Score for each day (0-6, where 6 is Today)
                        // We need to map index 0 -> 6 days ago, index 6 -> Today
                        final date = DateTime.now().subtract(Duration(days: 6 - index));
                        final dayKey = DateTime(date.year, date.month, date.day);
                        final log = logs[dayKey]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

                        // Quick Score Calc (Steps + Hydration + Sleep)
                        double score = 0;
                        if (log != null) {
                          double stepScore = ((log.stepCount ?? 0) / 8000).clamp(0.0, 1.0);
                          double waterScore = ((log.hydrationLiters ?? 0) / 3.0).clamp(0.0, 1.0);
                          double sleepScore = ((log.totalSleepDurationHours ?? 0) / 7.0).clamp(0.0, 1.0);
                          score = (stepScore + waterScore + sleepScore) / 3 * 10; // Scale to 0-10
                        }

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: score == 0 ? 0.5 : score, // Show tiny bar if 0
                              color: score > 7 ? Colors.green : (score > 4 ? Colors.orange : Colors.grey.shade300),
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 10, // Max Score
                                color: Colors.grey.shade50,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}