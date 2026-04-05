import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// Import your client log model

// 🔥 1. THE DATA PROVIDER
final myVitalsTrendProvider = FutureProvider.family<List<ClientLogModel>, _TrendRequest>((ref, request) async {
  final startDate = DateTime.now().subtract(Duration(days: request.daysBack));

  final snapshot = await FirebaseFirestore.instance
      .collection('clients')
      .doc(request.clientId)
      .collection('daily_logs')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
      .orderBy('date', descending: false)
      .get();

  return snapshot.docs.map((doc) => ClientLogModel.fromMap(doc.data(), doc.id)).toList();
});

class _TrendRequest {
  final String clientId;
  final int daysBack;
  _TrendRequest(this.clientId, this.daysBack);
  @override
  bool operator ==(Object other) => identical(this, other) || other is _TrendRequest && clientId == other.clientId && daysBack == other.daysBack;
  @override
  int get hashCode => clientId.hashCode ^ daysBack.hashCode;
}

// ============================================================================
// 🎯 CLIENT-FACING HEALTH TRENDS SCREEN
// ============================================================================
class MyHealthTrendsScreen extends ConsumerStatefulWidget {
  final String clientId; // Pass the logged-in client's ID here

  const MyHealthTrendsScreen({super.key, required this.clientId});

  @override
  ConsumerState<MyHealthTrendsScreen> createState() => _MyHealthTrendsScreenState();
}

class _MyHealthTrendsScreenState extends ConsumerState<MyHealthTrendsScreen> {
  int _selectedDays = 30; // Default to 1 Month view

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final trendAsync = ref.watch(myVitalsTrendProvider(_TrendRequest(widget.clientId, _selectedDays)));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("My Health Trends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🎛️ TIME FILTER (1W, 1M, 3M, 6M)
          _buildTimeFilterBar(theme, colorScheme),

          Expanded(
            child: trendAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
              error: (e, s) => Center(child: Text("Error loading trends: $e")),
              data: (logs) {
                if (logs.isEmpty) return _buildEmptyState(theme);

                final validLogs = logs.where((l) => l.weightKg != null || l.bloodPressureSystolic != null || l.fbsMgDl != null || l.heartRateBpm != null).toList();
                if (validLogs.isEmpty) return _buildEmptyState(theme, message: "No vitals logged in this timeframe.\nStart logging to see your progress!");

                return ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // ⚖️ WEIGHT TREND
                    _ClientTrendChartCard(
                      title: "Body Weight", unit: "kg", icon: Icons.monitor_weight_outlined, lineColor: Colors.teal, theme: theme, logs: validLogs,
                      extractValue: (log) => log.weightKg,
                    ),

                    // ❤️ BLOOD PRESSURE (Dual Line)
                    _ClientDualTrendChartCard(
                      title: "Blood Pressure", unit: "mmHg", icon: Icons.favorite_border_rounded, theme: theme, logs: validLogs,
                      lineColor1: Colors.redAccent, lineName1: "Systolic", extractValue1: (log) => log.bloodPressureSystolic?.toDouble(),
                      lineColor2: Colors.orangeAccent, lineName2: "Diastolic", extractValue2: (log) => log.bloodPressureDiastolic?.toDouble(),
                    ),

                    // 🩸 BLOOD GLUCOSE (Dual Line)
                    _ClientDualTrendChartCard(
                      title: "Blood Glucose", unit: "mg/dL", icon: Icons.bloodtype_outlined, theme: theme, logs: validLogs,
                      lineColor1: Colors.purpleAccent, lineName1: "Fasting (FBS)", extractValue1: (log) => log.fbsMgDl,
                      lineColor2: Colors.deepPurple, lineName2: "Post-Meal (PPBS)", extractValue2: (log) => log.ppbsMgDl,
                    ),

                    // 💓 HEART RATE
                    _ClientTrendChartCard(
                      title: "Resting Heart Rate", unit: "bpm", icon: Icons.monitor_heart_outlined, lineColor: Colors.pinkAccent, theme: theme, logs: validLogs,
                      extractValue: (log) => log.heartRateBpm?.toDouble(),
                    ),

                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterBar(ThemeData theme, ColorScheme colorScheme) {
    final filters = {7: "1W", 30: "1M", 90: "3M", 180: "6M"};
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
      child: Row(
        children: filters.entries.map((entry) {
          final isSelected = _selectedDays == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDays = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: isSelected ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : []),
                alignment: Alignment.center,
                child: Text(entry.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? colorScheme.onPrimary : theme.hintColor)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, {String message = "No data logged in this timeframe."}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph_rounded, size: 60, color: theme.disabledColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w500, height: 1.5)),
        ],
      ),
    );
  }
}

// ============================================================================
// 📈 SINGLE LINE CHART CARD
// ============================================================================
class _ClientTrendChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final IconData icon;
  final Color lineColor;
  final ThemeData theme;
  final List<ClientLogModel> logs;
  final double? Function(ClientLogModel) extractValue;

  const _ClientTrendChartCard({required this.title, required this.unit, required this.icon, required this.lineColor, required this.theme, required this.logs, required this.extractValue});

  @override
  Widget build(BuildContext context) {
    final dataPoints = logs.where((l) => extractValue(l) != null).toList();
    if (dataPoints.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < dataPoints.length; i++) {
      double val = extractValue(dataPoints[i])!;
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    double yPadding = (maxY - minY) * 0.2;
    if (yPadding == 0) yPadding = 5;
    double latestValue = extractValue(dataPoints.last)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.02), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: lineColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: lineColor, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(latestValue % 1 == 0 ? latestValue.toInt().toString() : latestValue.toStringAsFixed(1), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: lineColor)),
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: theme.dividerColor.withOpacity(0.1), strokeWidth: 1, dashArray: [5, 5])),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 22, interval: max(1, (dataPoints.length / 5).floorToDouble()),
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= dataPoints.length || value.toInt() < 0) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('d MMM').format(dataPoints[value.toInt()].date), style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w600)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.bold)))),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: (dataPoints.length - 1).toDouble(), minY: minY - yPadding, maxY: maxY + yPadding,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, isCurved: true, curveSmoothness: 0.35, color: lineColor, barWidth: 3, isStrokeCapRound: true,
                    dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: theme.cardColor, strokeWidth: 2, strokeColor: lineColor)),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 📈 DUAL LINE CHART CARD
// ============================================================================
class _ClientDualTrendChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final IconData icon;
  final ThemeData theme;
  final List<ClientLogModel> logs;
  final Color lineColor1; final String lineName1; final double? Function(ClientLogModel) extractValue1;
  final Color lineColor2; final String lineName2; final double? Function(ClientLogModel) extractValue2;

  const _ClientDualTrendChartCard({required this.title, required this.unit, required this.icon, required this.theme, required this.logs, required this.lineColor1, required this.lineName1, required this.extractValue1, required this.lineColor2, required this.lineName2, required this.extractValue2});

  @override
  Widget build(BuildContext context) {
    final dataPoints = logs.where((l) => extractValue1(l) != null || extractValue2(l) != null).toList();
    if (dataPoints.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots1 = []; List<FlSpot> spots2 = [];
    double minY = double.infinity; double maxY = double.negativeInfinity;

    for (int i = 0; i < dataPoints.length; i++) {
      double? val1 = extractValue1(dataPoints[i]); double? val2 = extractValue2(dataPoints[i]);
      if (val1 != null) { spots1.add(FlSpot(i.toDouble(), val1)); if (val1 < minY) minY = val1; if (val1 > maxY) maxY = val1; }
      if (val2 != null) { spots2.add(FlSpot(i.toDouble(), val2)); if (val2 < minY) minY = val2; if (val2 > maxY) maxY = val2; }
    }

    double yPadding = (maxY - minY) * 0.2; if (yPadding == 0) yPadding = 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.02), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: theme.colorScheme.primary, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegend(lineColor1, lineName1, theme), const SizedBox(width: 16), _buildLegend(lineColor2, lineName2, theme),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: theme.dividerColor.withOpacity(0.1), strokeWidth: 1, dashArray: [5, 5])),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: max(1, (dataPoints.length / 5).floorToDouble()), getTitlesWidget: (value, meta) { if (value.toInt() >= dataPoints.length || value.toInt() < 0) return const SizedBox.shrink(); return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('d MMM').format(dataPoints[value.toInt()].date), style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w600))); })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.bold)))),
                ),
                borderData: FlBorderData(show: false), minX: 0, maxX: (dataPoints.length - 1).toDouble(), minY: minY - yPadding, maxY: maxY + yPadding,
                lineBarsData: [
                  LineChartBarData(spots: spots1, isCurved: true, curveSmoothness: 0.35, color: lineColor1, barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: theme.cardColor, strokeWidth: 2, strokeColor: lineColor1))),
                  LineChartBarData(spots: spots2, isCurved: true, curveSmoothness: 0.35, color: lineColor2, barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: theme.cardColor, strokeWidth: 2, strokeColor: lineColor2))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text, ThemeData theme) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor))]);
  }
}