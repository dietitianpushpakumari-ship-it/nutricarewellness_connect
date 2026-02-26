import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class ActivityTrendChart extends ConsumerStatefulWidget {
  final String clientId;
  final int stepGoal;

  const ActivityTrendChart({
    super.key,
    required this.clientId,
    required this.stepGoal
  });

  @override
  ConsumerState<ActivityTrendChart> createState() => _ActivityTrendChartState();
}

class _ActivityTrendChartState extends ConsumerState<ActivityTrendChart> {
  int _selectedRange = 7;

  int get _selectedDays => _selectedRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final historyAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final selectedDate = ref.watch(activeDietPlanProvider).selectedDate;

    // 🎨 Use Solid Opaque Background for premium consistency
    final solidBgColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: solidBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(isDark ? 0.1 : 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Step History",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                      maxLines: 1,
                    ),
                    Text(
                      "Last $_selectedDays Days",
                      style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [7, 15, 30].map((days) {
                    bool isSelected = _selectedRange == days;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRange = days),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? (isDark ? theme.scaffoldBackgroundColor : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)] : [],
                        ),
                        child: Text(
                            "${days}D",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? colorScheme.primary : theme.hintColor
                            )
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 150,
            child: historyAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
              error: (err, __) => Center(child: Icon(Icons.error_outline, color: colorScheme.error)),
              data: (logsMap) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (widget.stepGoal * 1.5).toDouble(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => isDark ? colorScheme.onSurface : Colors.blueGrey.shade900,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            "${rod.toY.toInt()}\nSteps",
                            TextStyle(color: isDark ? theme.scaffoldBackgroundColor : Colors.white, fontWeight: FontWeight.w900),
                          );
                        },
                      ),
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                          return;
                        }
                        if (event is FlTapUpEvent) {
                          final index = barTouchResponse.spot!.touchedBarGroupIndex;
                          final date = DateTime.now().subtract(Duration(days: (_selectedRange - 1) - index));
                          ref.read(dietPlanNotifierProvider(widget.clientId).notifier).selectDate(date);
                        }
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= _selectedRange) return const SizedBox();

                            final date = DateTime.now().subtract(Duration(days: (_selectedRange - 1) - index));

                            if (_selectedRange > 10 && index % 3 != 0) return const SizedBox();

                            final isToday = DateUtils.isSameDay(date, DateTime.now());
                            final isSelectedDate = DateUtils.isSameDay(date, selectedDate);

                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              child: Text(
                                isToday ? "Today" : DateFormat('d/M').format(date),
                                style: TextStyle(
                                    color: isSelectedDate ? colorScheme.primary : theme.hintColor,
                                    fontWeight: isSelectedDate ? FontWeight.w900 : FontWeight.bold,
                                    fontSize: 10
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: List.generate(_selectedRange, (index) {
                      final date = DateTime.now().subtract(Duration(days: (_selectedRange - 1) - index));
                      final dayKey = DateTime(date.year, date.month, date.day);

                      // 🎯 ATOMIC FIX: Simply grab the master record from the Map
                      final ClientLogModel? dailyRecord = logsMap[dayKey];
                      final steps = (dailyRecord?.stepCount ?? 0).toDouble();

                      Color barColor = theme.disabledColor.withOpacity(isDark ? 0.2 : 0.1);
                      if (steps >= widget.stepGoal) barColor = Colors.green.shade600;
                      else if (steps >= (widget.stepGoal * 0.5)) barColor = Colors.orange.shade600;

                      final isSelectedDate = DateUtils.isSameDay(date, selectedDate);
                      if (isSelectedDate) barColor = colorScheme.primary;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: steps == 0 ? 50 : steps, // Small placeholder for visibility
                            color: barColor,
                            width: _selectedRange == 7 ? 14 : 8,
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: widget.stepGoal.toDouble(),
                              color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
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
    );
  }
}