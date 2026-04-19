import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pure_shift/core/utils/wellness_interpretor.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class AnalyticsDetailSheet extends ConsumerStatefulWidget {
  final String clientId;
  // 🚀 ADDED CACHE PARAMETERS
  final int? initialScore;
  final List<ClientLogModel>? initialLogs;

  const AnalyticsDetailSheet({
    super.key,
    required this.clientId,
    this.initialScore,
    this.initialLogs
  });

  @override
  ConsumerState<AnalyticsDetailSheet> createState() => _AnalyticsDetailSheetState();
}

class _AnalyticsDetailSheetState extends ConsumerState<AnalyticsDetailSheet> {
  int _selectedDays = 14;
  final List<int> _timeOptions = [7, 14, 30, 90];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final solidBgColor = isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC);
    final accentCyan = const Color(0xFF00E5FF);
    final neonGreen = const Color(0xFF00E676);

    // 🚀 THE SMART CACHE LOGIC
    // If we are looking at 14 days AND we have data from the Home Screen, use it immediately!
    final bool useCachedData = _selectedDays == 14 && widget.initialLogs != null && widget.initialLogs!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: solidBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: accentCyan.withOpacity(0.5), width: 2.0)),
          boxShadow: [BoxShadow(color: accentCyan.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -10))],
        ),
        child: Column(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(width: 60, height: 3, decoration: BoxDecoration(color: accentCyan.withOpacity(0.8), boxShadow: [BoxShadow(color: accentCyan, blurRadius: 10)])),
              ),
            ),

            Container(
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text("SYSTEM // ANALYTICS", style: TextStyle(fontFamily: kDisplayFont, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.0, color: isDark ? Colors.white : Colors.black87))),
                        IconButton(icon: Icon(Icons.close_rounded, size: 20, color: theme.iconTheme.color?.withOpacity(0.6)), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(context))
                      ],
                    ),
                  ),

                  Container(
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _timeOptions.length,
                      separatorBuilder: (_,__) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final days = _timeOptions[index];
                        final isSelected = days == _selectedDays;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDays = days),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? accentCyan.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSelected ? accentCyan.withOpacity(0.5) : Colors.transparent),
                            ),
                            child: Center(child: Text("${days}D RANGE", style: TextStyle(fontFamily: kDisplayFont, color: isSelected ? accentCyan : theme.hintColor, fontWeight: FontWeight.w700, letterSpacing: 1.0, fontSize: 9))),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: useCachedData
              // 🚀 If cached, render immediately! ZERO LATENCY.
                  ? _buildMainContent(widget.initialLogs!, widget.initialScore, controller, isDark, accentCyan, neonGreen)
              // 🚀 If they change the timeframe, fallback to Riverpod to fetch & calculate new data
                  : ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays))).when(
                loading: () => Center(child: CircularProgressIndicator(color: accentCyan)),
                error: (e, _) => Center(child: Text("SYSTEM ERROR: $e", style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.error))),
                data: (groupedLogs) {
                  List<ClientLogModel> records = groupedLogs.values.toList();
                  records.sort((a,b) => a.date.compareTo(b.date));
                  return _buildMainContent(records, null, controller, isDark, accentCyan, neonGreen);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 EXTRACTED TO REUSE FOR BOTH CACHED AND FETCHED DATA
  Widget _buildMainContent(List<ClientLogModel> dailyRecords, int? precalcScore, ScrollController controller, bool isDark, Color accentCyan, Color neonGreen) {
    // If we passed the score, use it. Otherwise, calculate it.
    final score = precalcScore ?? WellnessInterpreter.calculateWellnessScore(dailyRecords);
    final insights = WellnessInterpreter.generateInsights(dailyRecords);

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

    bool hasFbs = dailyRecords.any((l) => (l.fbsMgDl ?? 0) > 0);
    bool hasBp = dailyRecords.any((l) => (l.bloodPressureSystolic ?? 0) > 0);
    bool hasHr = dailyRecords.any((l) => (l.heartRateBpm ?? 0) > 0);
    bool hasWeight = dailyRecords.any((l) => (l.weightKg ?? 0) > 0);
    bool hasAnyTelemetry = hasFbs || hasBp || hasHr || hasWeight;

    return ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _buildScoreCard(score, isDark),
        const SizedBox(height: 32),

        if (insights.isNotEmpty) ...[
          _buildSectionHeader("AI INSIGHTS", accentCyan),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: PageView(
              controller: PageController(viewportFraction: 1.0),
              physics: const BouncingScrollPhysics(),
              children: insights.map((i) => _buildInsightCard(i, isDark)).toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],

        _buildComplianceSection(compliance, isDark),
        const SizedBox(height: 32),

        _buildSectionHeader("TELEMETRY", neonGreen),
        const SizedBox(height: 16),

        if (!hasAnyTelemetry)
          _buildEmptyTelemetry(isDark, accentCyan)
        else ...[
          if (hasFbs) _buildChartCard("FBS (mg/dL)", LineChart(_buildZonedChart(dailyRecords, (l) => l.fbsMgDl ?? 0, 70, 100, 140, Colors.purpleAccent, isDark)), isDark),
          if (hasBp) _buildChartCard("SYS BP (mmHg)", LineChart(_buildZonedChart(dailyRecords, (l) => (l.bloodPressureSystolic ?? 0).toDouble(), 90, 120, 140, Colors.redAccent, isDark)), isDark),
          if (hasHr) _buildChartCard("HEART RATE (BPM)", LineChart(_buildZonedChart(dailyRecords, (l) => (l.heartRateBpm ?? 0).toDouble(), 60, 100, 120, accentCyan, isDark)), isDark),
          if (hasWeight) _buildChartCard("MASS (KG)", LineChart(_buildSimpleChart(dailyRecords, (l) => l.weightKg ?? 0, Colors.blueAccent, isDark)), isDark),
        ],

        const SizedBox(height: 50),
      ],
    );
  }


  // --- UI WIDGETS ---

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Row(
      children: [
        Container(width: 4, height: 14, color: accentColor),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 2.0, color: accentColor.withOpacity(0.8))),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: accentColor.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildScoreCard(int score, bool isDark) {
    Color color = score >= 80 ? const Color(0xFF00E676) : (score >= 50 ? Colors.orangeAccent : Colors.redAccent);
    String status = score >= 80 ? "OPTIMAL" : (score >= 50 ? "STABLE" : "CRITICAL");

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121826) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]
      ),
      child: Row(
          children: [
            Text(
                "$score",
                style: TextStyle(fontFamily: kDisplayFont, fontSize: 50, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black, height: 1, shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 15)])
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("WELLNESS INDEX", style: TextStyle(fontFamily: kDisplayFont, color: isDark ? Colors.white54 : Colors.black54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    // 🚀 THE FIX 2: DISTINCT COLOR IDENTIFICATION FOR STATUS
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(4)),
                        child: RichText(
                          text: TextSpan(
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, letterSpacing: 1.0),
                              children: [
                                TextSpan(text: "STATUS: ", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w600)),
                                TextSpan(text: status, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                              ]
                          ),
                        )
                    ),
                  ]
              ),
            )
          ]
      ),
    );
  }

  Widget _buildInsightCard(WellnessInsight i, bool isDark) {
    return Container(
        margin: const EdgeInsets.only(right: 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121826) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: i.color.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: i.color.withOpacity(0.05), blurRadius: 10)]
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  children: [
                    Icon(i.icon, color: i.color, size: 18),
                    const SizedBox(width: 10),
                    Text(i.title.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, color: i.color, fontSize: 11, letterSpacing: 1.0))
                  ]
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                    i.message,
                    style: TextStyle(fontFamily: kBodyFont, fontSize: 10, height: 1.5, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis
                ),
              )
            ]
        )
    );
  }

  // 🚀 THE FIX 4: MISSING TELEMETRY FALLBACK WIDGET
// 🚀 THE FIX: Removed 'dashPattern' and updated to a clean solid border
  Widget _buildEmptyTelemetry(bool isDark, Color accentCyan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        // Changed to a standard tech border
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.monitor_heart_outlined, size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
              "NO TELEMETRY RECORDED",
              style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: isDark ? Colors.white70 : Colors.black87)
          ),
          const SizedBox(height: 8),
          Text(
              "Awaiting clinical data sync for this timeframe.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kBodyFont, fontSize: 9, color: isDark ? Colors.white54 : Colors.black54)
          ),
        ],
      ),
    );
  }
  Widget _buildComplianceSection(Map<String, int> stats, bool isDark) {
    final int followed = stats['followed'] ?? 0;
    final int deviated = stats['deviated'] ?? 0;
    final int skipped = stats['skipped'] ?? 0;
    final int total = followed + deviated + skipped;

    if(total == 0) return const SizedBox();

    final String pFollowed = ((followed / total) * 100).toStringAsFixed(0);
    final String pDeviated = ((deviated / total) * 100).toStringAsFixed(0);
    final String pSkipped = ((skipped / total) * 100).toStringAsFixed(0);

    final neonGreen = const Color(0xFF00E676);
    final neonOrange = Colors.orangeAccent;
    final neonRed = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121826) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("MEAL COMPLIANCE", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                Text("TOTAL: $total", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 1.0, color: isDark ? Colors.white30 : Colors.black38)),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
                height: 10,
                child: Row(
                    children: [
                      if (followed > 0) Expanded(flex: followed, child: Container(margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: neonGreen, borderRadius: BorderRadius.circular(2)))),
                      if (deviated > 0) Expanded(flex: deviated, child: Container(margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: neonOrange, borderRadius: BorderRadius.circular(2)))),
                      if (skipped > 0) Expanded(flex: skipped, child: Container(decoration: BoxDecoration(color: neonRed, borderRadius: BorderRadius.circular(2)))),
                    ]
                )
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))
              ),
              child: Row(
                children: [
                  // 🚀 THE FIX 3: CLEAR UNIVERSAL TERMINOLOGY
                  Expanded(child: _buildReportStatBlock("ON TRACK", followed, pFollowed, neonGreen, isDark)),
                  Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.black12),
                  Expanded(child: _buildReportStatBlock("OFF TRACK", deviated, pDeviated, neonOrange, isDark)),
                  Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.black12),
                  Expanded(child: _buildReportStatBlock("MISSED", skipped, pSkipped, neonRed, isDark)),
                ],
              ),
            )
          ]
      ),
    );
  }

  Widget _buildReportStatBlock(String label, int count, String percent, Color color, bool isDark) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: color)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$count", style: TextStyle(fontFamily: kDisplayFont, fontSize: 20, fontWeight: FontWeight.w700, height: 1.0, color: isDark ? Colors.white : Colors.black, shadows: [Shadow(color: color.withOpacity(0.3), blurRadius: 8)])),
              const SizedBox(width: 2),
              Text("($percent%)", style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black54)),
            ],
          )
        ]
    );
  }

  // --- CHARTS REMAIN UNCHANGED BELOW ---
// --- CHARTS SECTION (FIXED BOUNDARIES & FONTS) ---

// --- CHARTS SECTION (FIXED BOUNDARIES & FONTS) ---

  Widget _buildChartCard(String title, Widget chart, bool isDark) {
    return Container(
      height: 280, // Increased slightly to prevent compression
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121826) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
              Icon(Icons.insights_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 14)
            ],
          ),
          const SizedBox(height: 24),
          // 🚀 THE FIX: Increased padding inside Expanded to prevent trimming
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, top: 10, bottom: 0),
              child: chart,
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildZonedChart(List<ClientLogModel> data, double Function(ClientLogModel) selector, double minN, double maxN, double danger, Color color, bool isDark) {
    // 🚀 Calculate data range to prevent vertical trimming
    double maxY = danger + 20;
    for (var d in data) {
      if (selector(d) > maxY) maxY = selector(d) + 10;
    }

    return LineChartData(
        clipData: const FlClipData.all(), // 🚀 Allow dots to breathe slightly past the grid
        maxY: maxY,
        minY: minN - 10 > 0 ? minN - 10 : 0,
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1, dashArray: [4, 4])
        ),
        titlesData: _buildTitles(data, isDark),
        borderData: FlBorderData(show: false),
        lineTouchData: _getTouchData(data, selector, isDark),
        rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(y1: minN, y2: maxN, color: Colors.greenAccent.withOpacity(isDark ? 0.05 : 0.08))
        ]),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
              y: danger,
              color: Colors.redAccent.withOpacity(0.6),
              strokeWidth: 1,
              dashArray: [6, 3],
              label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w800, color: Colors.redAccent)
              )
          )
        ]),
        lineBarsData: [
          LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), selector(e.value))).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 1.5, strokeColor: isDark ? const Color(0xFF121826) : Colors.white)
              ),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter))
          )
        ]
    );
  }

  LineChartData _buildSimpleChart(List<ClientLogModel> data, double Function(ClientLogModel) selector, Color color, bool isDark) {
    double minV = 2000, maxV = 0;
    for(var d in data) { double v = selector(d); if(v > 0) { if(v < minV) minV = v; if(v > maxV) maxV = v; }}

    return LineChartData(
        clipData: const FlClipData.all(),
        minY: (minV - 2).clamp(0, 2000),
        maxY: maxV + 5, // 🚀 Vertical Headroom
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1, dashArray: [4, 4])),
        titlesData: _buildTitles(data, isDark),
        borderData: FlBorderData(show: false),
        lineTouchData: _getTouchData(data, selector, isDark),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), selector(e.value))).toList(),
            isCurved: true, color: color, barWidth: 2.5,
            dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 2, color: color, strokeWidth: 1, strokeColor: Colors.white)),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          )
        ]
    );
  }

  LineTouchData _getTouchData(List<ClientLogModel> data, double Function(ClientLogModel) val, bool isDark) {
    return LineTouchData(
        touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? Colors.white : const Color(0xFF121826),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                "${DateFormat('MMM dd').format(data[s.x.toInt()].date)}\n",
                TextStyle(fontFamily: kDisplayFont, color: isDark ? Colors.black54 : Colors.white54, fontWeight: FontWeight.w600, fontSize: 10),
                children: [
                  TextSpan(
                      text: "${val(data[s.x.toInt()])}",
                      style: TextStyle(fontFamily: kDisplayFont, color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w800, fontSize: 14)
                  )
                ]
            )).toList()
        )
    );
  }

  FlTitlesData _buildTitles(List<ClientLogModel> data, bool isDark) {
    return FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32, // 🚀 Increased from 22 to prevent date trimming
                getTitlesWidget: (val, _) {
                  // 🚀 Dynamic Interval: Prevents crowded dates on long ranges
                  int interval = (_selectedDays / 5).ceil();
                  if(val % interval == 0 && val < data.length) {
                    return Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                            DateFormat('dd/MM').format(data[val.toInt()].date),
                            style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? Colors.white30 : Colors.black38)
                        )
                    );
                  }
                  return const SizedBox();
                },
                interval: 1
            )
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))
    );
  }







}