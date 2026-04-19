import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/new/dashboard/analytics_detail_screen.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

class WellnessTrendsCard extends ConsumerWidget {
  final String clientId;
  const WellnessTrendsCard({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always fetch last 7 days for the summary card
    final historyAsync = ref.watch(historicalLogProvider((clientId: clientId, days: 7)));

    // 🎨 Theme Access
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)
            )
          ],
          border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Weekly Consistency",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: colorScheme.onSurface)
                    ),
                    Text(
                        "Your daily wellness score",
                        style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
                Icon(Icons.bar_chart_rounded, color: colorScheme.primary, size: 22),
              ],
            ),

            const SizedBox(height: 12),

            // The Mini Chart
            SizedBox(
              height: 100,
              child: historyAsync.when(
                loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => const SizedBox(),
                data: (logsMap) {
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
                              return SideTitleWidget(
                                meta: meta,
                                space: 8,
                                child: Text(
                                    DateFormat('E').format(date)[0],
                                    style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.bold)
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (index) {
                        final date = DateTime.now().subtract(Duration(days: 6 - index));
                        final dayKey = DateTime(date.year, date.month, date.day);

                        // 🎯 ATOMIC FIX: Grab the Master Record directly from the map
                        final ClientLogModel? dailyRecord = logsMap[dayKey];

                        double score = 0;
                        if (dailyRecord != null) {
                          // Quick Score Calc (Steps + Hydration + Sleep)
                          // Values are now root properties of ClientLogModel
                          double stepScore = (dailyRecord.stepCount / 8000).clamp(0.0, 1.0);
                          double waterScore = (dailyRecord.hydrationLiters / 3.0).clamp(0.0, 1.0);
                          double sleepScore = (dailyRecord.totalSleepDurationHours / 7.0).clamp(0.0, 1.0);

                          // Final scaled score 0-10
                          score = (stepScore + waterScore + sleepScore) / 3 * 10;
                        }

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: score == 0 ? 0.5 : score,
                              color: score > 7
                                  ? Colors.green.shade600
                                  : (score > 4 ? Colors.orange.shade600 : theme.disabledColor.withOpacity(0.3)),
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 10,
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
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