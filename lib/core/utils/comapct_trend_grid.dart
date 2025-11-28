import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/analytics_detail_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:collection/collection.dart';

class CompactTrendCard extends ConsumerWidget {
  final String clientId;
  const CompactTrendCard({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historicalLogProvider((clientId: clientId, days: 7)));

    return GestureDetector(
      onTap: () {
        // 🎯 Opens the Advanced Graph Screen
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AnalyticsDetailSheet(clientId: clientId),
        );
      },
      child: Container(
        height: 100, // 🎯 Very Compact
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Weekly\nPulse", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: const Text("View Report", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: historyAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (logs) {
                  return BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (index) {
                        final date = DateTime.now().subtract(Duration(days: 6 - index));
                        final dayKey = DateTime(date.year, date.month, date.day);
                        final log = logs[dayKey]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

                        double score = 0;
                        if (log != null) {
                          double s = ((log.stepCount ?? 0) / 6000.0).clamp(0.0, 1.0);
                          double w = ((log.hydrationLiters ?? 0) / 2.5).clamp(0.0, 1.0);
                          score = (s + w) / 2 * 8;
                        }

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: score == 0 ? 0.5 : score,
                              color: score > 6 ? Colors.green : (score > 0 ? Colors.orange.shade300 : Colors.grey.shade200),
                              width: 6,
                              borderRadius: BorderRadius.circular(2),
                              backDrawRodData: BackgroundBarChartRodData(show: true, toY: 8, color: Colors.grey.shade100),
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