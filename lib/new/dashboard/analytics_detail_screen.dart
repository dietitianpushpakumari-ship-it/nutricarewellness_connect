import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/wellness_interpretor.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class AnalyticsDetailSheet extends ConsumerStatefulWidget {
  final String clientId;
  const AnalyticsDetailSheet({super.key, required this.clientId});

  @override
  ConsumerState<AnalyticsDetailSheet> createState() => _AnalyticsDetailSheetState();
}

class _AnalyticsDetailSheetState extends ConsumerState<AnalyticsDetailSheet> {
  int _selectedDays = 14;
  final List<int> _timeOptions = [7, 14, 30, 90];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(historicalLogProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final historyAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));

    // 🎯 Enforce Solid Background
    final solidBgColor = isDark ? const Color(0xFF121212) : theme.scaffoldBackgroundColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: solidBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(
                child: Container(
                    width: 48, height: 5,
                    decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(3))
                )
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Smart Health Report", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.iconTheme.color?.withOpacity(0.6)),
                      onPressed: () => Navigator.pop(context)
                  )
                ],
              ),
            ),

            // Time Filter
            Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _timeOptions.length,
                separatorBuilder: (_,__) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final days = _timeOptions[index];
                  final isSelected = days == _selectedDays;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDays = days),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary : theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1)),
                        boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
                      ),
                      child: Center(
                        child: Text(
                            "$days Days",
                            style: TextStyle(
                                color: isSelected ? colorScheme.onPrimary : theme.hintColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13
                            )
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: historyAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                error: (e, _) => Center(child: Text("Error: $e", style: TextStyle(color: colorScheme.error))),
                data: (groupedLogs) {

                  // 🎯 ATOMIC DATA PARSING
                  // We just grab all the values from the map since each value IS the Master Record
                  List<ClientLogModel> dailyRecords = groupedLogs.values.toList();
                  dailyRecords.sort((a,b) => a.date.compareTo(b.date));

                  // Calculate scores and insights using the daily records
                  final score = WellnessInterpreter.calculateWellnessScore(dailyRecords);
                  final insights = WellnessInterpreter.generateInsights(dailyRecords);

                  // 🎯 MANUAL COMPLIANCE CALCULATION
                  // Since meal objects are now nested maps, we calculate compliance safely here
                  int followedCount = 0;
                  int deviatedCount = 0;
                  int skippedCount = 0;

                  for (var record in dailyRecords) {
                    for (var meal in record.mealLogs.values) {
                      if (meal.status == LogStatus.followed) followedCount++;
                      if (meal.status == LogStatus.deviated) deviatedCount++;
                      if (meal.status == LogStatus.skipped) skippedCount++;
                    }
                  }

                  final compliance = {
                    'followed': followedCount,
                    'deviated': deviatedCount,
                    'skipped': skippedCount,
                  };

                  final data = dailyRecords;

                  return ListView(
                    controller: controller,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildScoreCard(score, colorScheme),
                      const SizedBox(height: 24),

                      if (insights.isNotEmpty) ...[
                        Text("Smart Suggestions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.onSurface)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 130,
                          child: PageView(
                            controller: PageController(viewportFraction: 0.92),
                            padEnds: false,
                            children: insights.map((i) => _buildInsightCard(i, theme, colorScheme, isDark)).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _buildComplianceSection(compliance, theme, colorScheme, isDark),
                      const SizedBox(height: 24),

                      Text("Trend Analysis", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.onSurface)),
                      const SizedBox(height: 16),

                      // 🎯 Charts directly read from the Daily Master Record
                      if (data.any((l) => (l.fbsMgDl ?? 0) > 0))
                        _buildChartCard("Fasting Sugar", LineChart(_buildZonedChart(data, (l) => l.fbsMgDl ?? 0, 70, 100, 140, "mg/dL", Colors.purple, theme)), theme, colorScheme, isDark),

                      if (data.any((l) => (l.bloodPressureSystolic ?? 0) > 0))
                        _buildChartCard("BP (Systolic)", LineChart(_buildZonedChart(data, (l) => (l.bloodPressureSystolic ?? 0).toDouble(), 90, 120, 140, "mmHg", Colors.redAccent, theme)), theme, colorScheme, isDark),

                      if (data.any((l) => (l.heartRateBpm ?? 0) > 0))
                        _buildChartCard("Resting Heart Rate", LineChart(_buildZonedChart(data, (l) => (l.heartRateBpm ?? 0).toDouble(), 60, 100, 120, "BPM", Colors.pinkAccent, theme)), theme, colorScheme, isDark),

                      if (data.any((l) => (l.moodLevelRating ?? 0) > 0))
                        _buildChartCard("Mood & Stress", LineChart(_buildZonedChart(data, (l) => (l.moodLevelRating ?? 0).toDouble(), 3, 5, 6, "Rating", Colors.teal, theme)), theme, colorScheme, isDark),

                      if (data.any((l) => (l.weightKg ?? 0) > 0))
                        _buildChartCard("Weight", LineChart(_buildSimpleChart(data, (l) => l.weightKg ?? 0, Colors.blue, theme)), theme, colorScheme, isDark),

                      const SizedBox(height: 50),
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

  // --- CHART LOGIC ---
  LineChartData _buildZonedChart(List<ClientLogModel> data, double Function(ClientLogModel) selector, double minN, double maxN, double danger, String unit, Color color, ThemeData theme) {
    return LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: _buildTitles(data, theme),
        borderData: FlBorderData(show: false),
        lineTouchData: _getTouchData(data, selector, unit, theme),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(y1: minN, y2: maxN, color: Colors.green.withOpacity(0.1)),
          ],
        ),
        extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: danger, color: Colors.red.withOpacity(0.5), strokeWidth: 1.5, dashArray: [5, 5]),
            ]
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), selector(e.value))).toList(),
            isCurved: true, color: color, barWidth: 3.5, dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: theme.scaffoldBackgroundColor)),
          )
        ]
    );
  }

  LineChartData _buildSimpleChart(List<ClientLogModel> data, double Function(ClientLogModel) selector, Color color, ThemeData theme) {
    double minV = 1000, maxV = 0;
    for(var d in data) { double v = selector(d); if(v>0) { if(v<minV) minV=v; if(v>maxV) maxV=v; }}

    return LineChartData(
        minY: (minV - 2).clamp(0, 1000), maxY: maxV + 2,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: theme.dividerColor.withOpacity(0.08), strokeWidth: 1)),
        titlesData: _buildTitles(data, theme),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), selector(e.value))).toList(),
            isCurved: true, color: color, barWidth: 4, belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
          )
        ]
    );
  }

  // --- UI WIDGETS ---

  Widget _buildChartCard(String title, Widget chart, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      height: 250, margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorScheme.onSurface)),
          const SizedBox(height: 6),
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green.withOpacity(0.6), shape: BoxShape.circle)), const SizedBox(width: 6),
            Text("Healthy Range", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
            const SizedBox(width: 16),
            Container(width: 12, height: 2, color: Colors.red.withOpacity(0.6)), const SizedBox(width: 6),
            Text("Threshold", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor))
          ]),
          const SizedBox(height: 16),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int score, ColorScheme colorScheme) {
    Color color = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
      ),
      child: Row(children: [
        Text("$score", style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Overall Wellness Score", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(score >= 80 ? "Excellent Progress" : (score >= 50 ? "Stable Routine" : "Action Needed"), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ]
          ),
        )
      ]),
    );
  }

  Widget _buildInsightCard(WellnessInsight i, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isDark ? i.color.withOpacity(0.1) : i.color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: i.color.withOpacity(0.3), width: 1.5)
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(i.icon, color: i.color, size: 22),
                const SizedBox(width: 10),
                Text(i.title, style: TextStyle(fontWeight: FontWeight.w900, color: i.color, fontSize: 15))
              ]),
              const SizedBox(height: 10),
              Text(i.message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface), maxLines: 3, overflow: TextOverflow.ellipsis)
            ]
        )
    );
  }

  Widget _buildComplianceSection(Map<String, int> stats, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final total = stats.values.reduce((a,b)=>a+b);
    if(total == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Diet Adherence", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(height: 12, child: Row(children: [
                if (stats['followed']! > 0) Expanded(flex: stats['followed']!, child: Container(color: Colors.green.shade500)),
                if (stats['deviated']! > 0) Expanded(flex: stats['deviated']!, child: Container(color: Colors.orange.shade500)),
                if (stats['skipped']! > 0) Expanded(flex: stats['skipped']!, child: Container(color: Colors.red.shade500)),
              ])),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegItem("On Track (${stats['followed']})", Colors.green.shade500, theme),
                _buildLegItem("Deviated (${stats['deviated']})", Colors.orange.shade500, theme),
                _buildLegItem("Missed (${stats['skipped']})", Colors.red.shade500, theme),
              ],
            )
          ]
      ),
    );
  }

  Widget _buildLegItem(String label, Color color, ThemeData theme) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor))
    ]);
  }

  LineTouchData _getTouchData(List<ClientLogModel> data, double Function(ClientLogModel) val, String unit, ThemeData theme) {
    return LineTouchData(touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_)=> theme.colorScheme.onSurface,
        getTooltipItems: (spots) => spots.map((s) => LineTooltipItem("${DateFormat('MMM dd').format(data[s.x.toInt()].date)}\n${val(data[s.x.toInt()])} $unit", TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold, fontSize: 12))).toList()
    ));
  }

  FlTitlesData _buildTitles(List<ClientLogModel> data, ThemeData theme) {
    return FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
          if(val % (_selectedDays/5).ceil() == 0 && val < data.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Text(DateFormat('d/M').format(data[val.toInt()].date), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
            );
          }
          return const SizedBox();
        }, interval: 1)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))
    );
  }
}