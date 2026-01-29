import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/wellness_interpretor.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
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
    final historyAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Smart Health Report", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
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
                        color: isSelected ? Colors.indigo : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? Colors.indigo : Colors.grey.shade300),
                      ),
                      child: Text("$days Days", style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Error: $e")),
                data: (groupedLogs) {
                  List<ClientLogModel> allLogs = [];
                  List<ClientLogModel> wellnessLogs = [];
                  groupedLogs.forEach((date, logs) {
                    allLogs.addAll(logs);
                    final w = logs.firstWhere((l) => l.mealName == 'DAILY_WELLNESS_CHECK', orElse: () => ClientLogModel(clientId: '', dietPlanId: '', date: date, mealName: 'EMPTY'));
                    if(w.mealName != 'EMPTY') wellnessLogs.add(w);
                  });
                  wellnessLogs.sort((a,b) => a.date.compareTo(b.date));

                  final score = WellnessInterpreter.calculateWellnessScore(wellnessLogs);
                  final insights = WellnessInterpreter.generateInsights(wellnessLogs);
                  final compliance = WellnessInterpreter.getMealCompliance(allLogs);
                  final data = wellnessLogs; // Alias for charts

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // 1. SCORE
                      _buildScoreCard(score),
                      const SizedBox(height: 24),

                      // 2. INSIGHTS
                      if (insights.isNotEmpty) ...[
                        const Text("Smart Suggestions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 130,
                          child: PageView(
                            controller: PageController(viewportFraction: 0.92),
                            padEnds: false,
                            children: insights.map((i) => _buildInsightCard(i)).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 3. COMPLIANCE
                      _buildComplianceSection(compliance),
                      const SizedBox(height: 24),

                      const Text("Trend Analysis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),

                      // --- CHARTS WITH ZONES ---

                      // SUGAR
                      if (data.any((l) => (l.fbsMgDl ?? 0) > 0))
                        _buildChartCard("Fasting Sugar", LineChart(_buildZonedChart(data, (l) => l.fbsMgDl ?? 0, 70, 100, 140, "mg/dL", Colors.purple))),

                      // BLOOD PRESSURE (Systolic)
                      if (data.any((l) => (l.bloodPressureSystolic ?? 0) > 0))
                        _buildChartCard("BP (Systolic)", LineChart(_buildZonedChart(data, (l) => (l.bloodPressureSystolic ?? 0).toDouble(), 90, 120, 140, "mmHg", Colors.redAccent))),

                      // HEART RATE
                      if (data.any((l) => (l.heartRateBpm ?? 0) > 0))
                        _buildChartCard("Resting Heart Rate", LineChart(_buildZonedChart(data, (l) => (l.heartRateBpm ?? 0).toDouble(), 60, 100, 120, "BPM", Colors.pinkAccent))),

                      // MOOD / STRESS
                      if (data.any((l) => (l.moodLevelRating ?? 0) > 0))
                        _buildChartCard("Mood & Stress", LineChart(_buildZonedChart(data, (l) => (l.moodLevelRating ?? 0).toDouble(), 3, 5, 6, "Rating", Colors.teal))),

                      // WEIGHT
                      if (data.any((l) => (l.weightKg ?? 0) > 0))
                        _buildChartCard("Weight", LineChart(_buildSimpleChart(data, (l) => l.weightKg ?? 0, Colors.blue))),

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

  // --- CHART LOGIC: THE "ZONED" CHART ---
  LineChartData _buildZonedChart(
      List<ClientLogModel> data,
      double Function(ClientLogModel) valueSelector,
      double minNormal, double maxNormal, double dangerLine,
      String unit, Color lineColor
      ) {
    return LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: _buildTitles(data),
        borderData: FlBorderData(show: false),
        lineTouchData: _getTouchData(data, valueSelector, unit),

        // 🎯 GREEN ZONE (Healthy Range)
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(y1: minNormal, y2: maxNormal, color: Colors.green.withOpacity(0.15)),
          ],
        ),

        // 🎯 DANGER LINE
        extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: dangerLine, color: Colors.red.withOpacity(0.4), strokeWidth: 1, dashArray: [5, 5], label: HorizontalLineLabel(show: true, labelResolver: (l) => "Limit")),
            ]
        ),

        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), valueSelector(e.value))).toList(),
            isCurved: true, color: lineColor, barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          )
        ]
    );
  }

  LineChartData _buildSimpleChart(List<ClientLogModel> data, double Function(ClientLogModel) selector, Color color) {
    // Dynamic Y
    double minV = 1000, maxV = 0;
    for(var d in data) { double v = selector(d); if(v>0) { if(v<minV) minV=v; if(v>maxV) maxV=v; }}

    return LineChartData(
        minY: (minV - 2).clamp(0, 1000), maxY: maxV + 2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _buildTitles(data),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), selector(e.value))).toList(),
            isCurved: true, color: color, barWidth: 4, isStrokeCapRound: true,
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
          )
        ]
    );
  }

  // --- UI WIDGETS ---

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      height: 240, margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Row(children: [
            Container(width: 8, height: 8, color: Colors.green.withOpacity(0.3)), const SizedBox(width: 4),
            const Text("Healthy Zone", style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(width: 12),
            const Icon(Icons.horizontal_rule, size: 12, color: Colors.red), const SizedBox(width: 4),
            const Text("Limit", style: TextStyle(fontSize: 10, color: Colors.grey))
          ]),
          const SizedBox(height: 10),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int score) {
    Color color = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
        Text("$score", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Wellness Score", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(score >= 80 ? "Excellent" : "Needs Focus", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ])
      ]),
    );
  }

  Widget _buildInsightCard(WellnessInsight i) {
    return Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: i.color.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(i.icon, color: i.color, size: 20), const SizedBox(width: 8), Text(i.title, style: TextStyle(fontWeight: FontWeight.bold, color: i.color))]), const SizedBox(height: 8), Text(i.message, style: const TextStyle(fontSize: 12), maxLines: 3)]));
  }

  Widget _buildComplianceSection(Map<String, int> stats) {
    final total = stats.values.reduce((a,b)=>a+b);
    if(total == 0) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Text("Diet Adherence", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(height: 12, child: Row(children: [
          Expanded(flex: stats['followed']!, child: Container(color: Colors.green)),
          Expanded(flex: stats['deviated']!, child: Container(color: Colors.orange)),
          Expanded(flex: stats['skipped']!, child: Container(color: Colors.red)),
        ])),
      ]),
    );
  }

  LineTouchData _getTouchData(List<ClientLogModel> data, double Function(ClientLogModel) val, String unit) {
    return LineTouchData(touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_)=>Colors.blueGrey,
        getTooltipItems: (spots) => spots.map((s) => LineTooltipItem("${DateFormat('MM/dd').format(data[s.x.toInt()].date)}\n${val(data[s.x.toInt()])} $unit", const TextStyle(color: Colors.white))).toList()
    ));
  }

  FlTitlesData _buildTitles(List<ClientLogModel> data) {
    return FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
          if(val % (_selectedDays/5).ceil() == 0 && val < data.length) return Text(DateFormat('d/M').format(data[val.toInt()].date), style: const TextStyle(fontSize: 10, color: Colors.grey));
          return const SizedBox();
        }, interval: 1)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))
    );
  }
}