import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:collection/collection.dart';

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
  int _selectedRange = 7; // Default to 7 days

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final selectedDate = ref.watch(activeDietPlanProvider).selectedDate;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Step History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                      "Last $_selectedDays Days",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)
                  ),
                ],
              ),
              // Toggle 7/15/30 Days
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [7, 15, 30].map((days) {
                    bool isSelected = _selectedRange == days;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRange = days),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)] : [],
                        ),
                        child: Text(
                            "${days}D",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.black : Colors.grey
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

          // The Chart
          SizedBox(
            height: 150,
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
              data: (logs) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (widget.stepGoal * 1.5).toDouble(), // Leave some headroom
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            "${rod.toY.toInt()}\nSteps",
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                          return;
                        }
                        // 🎯 INTERACTIVE: Tap bar to select date
                        if (event is FlTapUpEvent) {
                          final index = barTouchResponse.spot!.touchedBarGroupIndex;
                          final date = DateTime.now().subtract(Duration(days: (_selectedRange - 1) - index));

                          // Update global selected date provider
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

                            // Calculate date from index (0 = oldest, max = today)
                            final date = DateTime.now().subtract(Duration(days: (_selectedRange - 1) - index));

                            // Show label only for specific intervals to avoid clutter
                            if (_selectedRange > 10 && index % 3 != 0) return const SizedBox();

                            final isToday = DateUtils.isSameDay(date, DateTime.now());
                            final isSelected = DateUtils.isSameDay(date, selectedDate);

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                isToday ? "Today" : DateFormat('d/M').format(date),
                                style: TextStyle(
                                    color: isSelected ? Colors.deepPurple : Colors.grey.shade400,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                      // Calculate Date: Index 0 is (range-1) days ago. Index (range-1) is Today.
                      final date = DateTime.now().subtract(Duration(days: (_selectedRange - 1) - index));
                      final dayKey = DateTime(date.year, date.month, date.day);

                      final log = logs[dayKey]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
                      final steps = log?.stepCount?.toDouble() ?? 0.0;

                      // Color Logic
                      Color barColor = Colors.grey.shade300;
                      if (steps >= widget.stepGoal) barColor = Colors.green;
                      else if (steps >= (widget.stepGoal * 0.5)) barColor = Colors.orange;

                      // Highlight Selected Date
                      final isSelected = DateUtils.isSameDay(date, selectedDate);
                      if (isSelected) barColor = Colors.deepPurple;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: steps,
                            color: barColor,
                            width: _selectedRange == 7 ? 16 : 8, // Thinner bars for more days
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: widget.stepGoal.toDouble(), // Goal Line background
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
    );
  }

  // Helper getter for current _selectedRange from state
  int get _selectedDays => _selectedRange;
}