import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:pure_shift/new/models/vitals_model.dart';
// 🔥 Ensure this points to where your labTestConfigsProvider is defined
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

class VitalsTrendChart extends ConsumerStatefulWidget {
  final List<VitalsModel> history;
  const VitalsTrendChart({super.key, required this.history});

  @override
  ConsumerState<VitalsTrendChart> createState() => _VitalsTrendChartState();
}

class _VitalsTrendChartState extends ConsumerState<VitalsTrendChart> {
  String _selectedMetric = 'weightKg';

  @override
  void initState() {
    super.initState();
    _setInitialMetric();
  }

  void _setInitialMetric() {
    if (widget.history.isEmpty) return;
    // Default to weight if it exists, otherwise pick the first lab test available
    final firstLog = widget.history.first;
    if (firstLog.weightKg == 0 && firstLog.labResults.isNotEmpty) {
      _selectedMetric = firstLog.labResults.keys.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1. FETCH MASTER CONFIGS (For ID -> Name mapping)
    final configsAsync = ref.watch(labTestConfigsProvider);

    // 2. SORT DATA (Oldest to Newest for the X-axis)
    final data = List<VitalsModel>.from(widget.history);
    data.sort((a, b) => a.date.compareTo(b.date));

    if (data.isEmpty) return const SizedBox.shrink();

    // 3. DISCOVER ALL AVAILABLE METRICS IN THIS PATIENT'S HISTORY
    Set<String> availableMetrics = {};
    if (data.any((l) => l.weightKg > 0)) availableMetrics.add('weightKg');
    if (data.any((l) => l.bloodPressureSystolic != null)) availableMetrics.add('bloodPressureSystolic');

    for (var log in data) {
      availableMetrics.addAll(log.labResults.keys);
    }

    return configsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const Text("Error loading clinical labels"),
      data: (configs) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 🏷️ DYNAMIC HORIZONTAL CHIP SELECTOR ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: availableMetrics.map((metricId) {
                    final isSelected = _selectedMetric == metricId;
                    // 🔥 Using the ID to Name mapping fix
                    final label = _getPrettyNameFromConfigs(metricId, configs);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedMetric = metricId);
                        },
                        selectedColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.hintColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // --- 📈 THE CHART ENGINE ---
              _buildGraph(data, theme, colorScheme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGraph(List<VitalsModel> data, ThemeData theme, ColorScheme colorScheme) {
    List<FlSpot> spots = [];
    List<VitalsModel> validLogs = [];

    // Filter logs that actually have the selected data point
    for (var i = 0; i < data.length; i++) {
      double? val = _getValue(data[i], _selectedMetric);
      if (val != null && val > 0) {
        spots.add(FlSpot(validLogs.length.toDouble(), val));
        validLogs.add(data[i]);
      }
    }

    if (spots.length < 2) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            "Add more records to see a trend line.",
            style: TextStyle(color: theme.hintColor, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.dividerColor.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: max(1, (validLogs.length / 3).floorToDouble()),
                getTitlesWidget: (val, meta) {
                  final index = val.toInt();
                  if (index < 0 || index >= validLogs.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      DateFormat('d MMM').format(validLogs[index].date),
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: colorScheme.primary,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: colorScheme.primary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [colorScheme.primary.withOpacity(0.3), colorScheme.primary.withOpacity(0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🔥 CLINICAL NAME LOOKUP ---
  String _getPrettyNameFromConfigs(String id, List<dynamic> configs) {
    if (id == 'weightKg') return "Weight";
    if (id == 'bloodPressureSystolic') return "BP (Systolic)";

    try {
      final match = configs.firstWhere(
              (c) => c.id.trim().toLowerCase() == id.trim().toLowerCase()
      );
      return match.name;
    } catch (_) {
      return id.toUpperCase();
    }
  }

  // --- 🧬 DYNAMIC VALUE EXTRACTION ---
  double? _getValue(VitalsModel model, String id) {
    if (id == 'weightKg') return model.weightKg > 0 ? model.weightKg : null;
    if (id == 'bloodPressureSystolic') return model.bloodPressureSystolic?.toDouble();

    if (model.labResults.containsKey(id)) {
      final val = model.labResults[id];
      return (val is num) ? val?.toDouble() : null;
    }
    return null;
  }
}