import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/localization/localization_extension.dart';
import 'package:nutricare_connect/core/utils/analytics_detail_screen.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:collection/collection.dart';

class CompactTrendCard extends ConsumerWidget {
  final String clientId;
  const CompactTrendCard({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historicalLogProvider((clientId: clientId, days: 7)));

    // 🎯 Extract Theme for Glassmorphism
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Extract base glass color and border from the global CardTheme
    final Color baseColor = theme.cardTheme.color ?? colorScheme.surface;
    Color borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.4);
    if (theme.cardTheme.shape is RoundedRectangleBorder) {
      borderColor = (theme.cardTheme.shape as RoundedRectangleBorder).side.color;
    }

    return GestureDetector(
      onTap: () {
        // 🎯 Opens the Advanced Graph Screen
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent, // Important for glass sheets
          builder: (_) => AnalyticsDetailSheet(clientId: clientId),
        );
      },
      child: Container(
        height: 100, // 🎯 Very Compact
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: baseColor, // Translucent Glass Fill
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5), // Delicate glass rim
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      "${context.tr("dashboard_weekly_pulse")}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: colorScheme.onSurface, // Adapts to light/dark
                      )
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.15), // Glassy badge
                        borderRadius: BorderRadius.circular(4)
                    ),
                    child: Text(
                        "${context.tr("dashboard_view_report")}",
                        style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.primary, // Theme primary color
                            fontWeight: FontWeight.bold
                        )
                    ),
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

                        // 🎯 Dynamic Colors based on the active theme
                        Color barColor = colorScheme.onSurface.withOpacity(0.2); // Low score
                        if (score > 6) {
                          barColor = colorScheme.primary; // High score
                        } else if (score > 0) {
                          barColor = colorScheme.secondary; // Medium score
                        }

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: score == 0 ? 0.5 : score,
                              color: barColor,
                              width: 6,
                              borderRadius: BorderRadius.circular(2),
                              backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: 8,
                                  color: colorScheme.onSurface.withOpacity(0.05) // Subtle glass track
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