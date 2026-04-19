import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_shift/new/models/vitals_model.dart';
// 🔥 Adjust this import to wherever your labTestConfigsProvider lives:
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

class SmartVitalsReportCard extends ConsumerWidget {
  final VitalsModel current;
  final VitalsModel? previous;

  const SmartVitalsReportCard({
    super.key,
    required this.current,
    this.previous,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 1. If there is no clinical data at all, just hide the card.
    if (current.labResults.isEmpty && current.bloodPressureSystolic == null) {
      return const SizedBox.shrink();
    }

    // 2. Fetch the global lab configurations for safe ranges
    final configsAsync = ref.watch(labTestConfigsProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // --- HEADER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Clinical Intelligence", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                  Text("Biomarker Trend Analysis", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.biotech_rounded, color: colorScheme.onPrimaryContainer, size: 20),
              ),
            ],
          ),
          Divider(height: 30, color: colorScheme.outlineVariant),

          // --- SECTION 1: BLOOD PRESSURE ---
          if (current.bloodPressureSystolic != null && current.bloodPressureDiastolic != null) ...[
            _buildBPRow(context),
            const SizedBox(height: 16),
          ],

          // --- SECTION 2: LAB RESULTS ---
          configsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
            error: (e, s) => Text("Error loading clinical data.", style: TextStyle(color: colorScheme.error)),
            data: (configs) {

              List<Widget> labRows = [];
              int count = 0;

              // Only analyze up to 4 labs so the card doesn't become a massive scrollable list
              for (var entry in current.labResults.entries) {
                if (count >= 4) break;

                var config;
                try { config = configs.firstWhere((c) => c.id.trim().toLowerCase() == entry.key.trim().toLowerCase()); } catch (_) { config = null; }

                double currentVal = (entry.value as num).toDouble();
                double? previousVal = previous?.labResults[entry.key]?.toDouble();

                labRows.add(_buildDynamicLabRow(context, entry.key, currentVal, previousVal, config));
                labRows.add(const SizedBox(height: 16));
                count++;
              }

              return Column(
                children: [
                  ...labRows,

                  // --- SECTION 3: THE SMART INSIGHT AI TEXT ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.secondaryContainer),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_circle, color: colorScheme.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _generateSmartLabInsight(configs),
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🩺 DYNAMIC LAB ROW BUILDER (Failsafe)
  // =========================================================================
  Widget _buildDynamicLabRow(BuildContext context, String rawKey, double currentVal, double? previousVal, dynamic config) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String name = config != null ? config.name : rawKey.toUpperCase();
    String unit = config?.unit ?? "";
    double? minLimit = config?.minRange;
    double? maxLimit = config?.maxRange;
    bool isReverse = config?.isReverseLogic ?? false;

    bool isLow = minLimit != null && currentVal < minLimit;
    bool isHigh = maxLimit != null && currentVal > maxLimit;
    bool isAbnormal = isLow || isHigh;

    String statusLabel = "NORMAL";
    Color statusColor = Colors.green;

    if (isLow) { statusLabel = "LOW"; statusColor = Colors.orange; }
    else if (isHigh) { statusLabel = "HIGH"; statusColor = Colors.redAccent; }

    double change = previousVal != null ? (currentVal - previousVal) : 0;

    bool isImprovement = false;
    if (change != 0) {
      if (isReverse) isImprovement = change > 0;
      else isImprovement = change < 0;
    }

    Color trendColor = isImprovement ? Colors.green : Colors.redAccent;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(currentVal % 1 == 0 ? currentVal.toInt().toString() : currentVal.toStringAsFixed(1), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                  if (unit.isNotEmpty) ...[const SizedBox(width: 4), Text(unit, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant))],

                  if (change != 0) ...[
                    const SizedBox(width: 8),
                    Icon(change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: trendColor, size: 14),
                    const SizedBox(width: 2),
                    Text(change.abs() % 1 == 0 ? change.abs().toInt().toString() : change.abs().toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: trendColor))
                  ]
                ],
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withOpacity(0.3))),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 4),
              Text(
                (minLimit != null && maxLimit != null) ? "$minLimit - $maxLimit $unit" : (maxLimit != null ? "< $maxLimit $unit" : "Clinical Range"),
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        )
      ],
    );
  }

  // =========================================================================
  // ❤️ HARDCODED BP ROW
  // =========================================================================
  Widget _buildBPRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    double sys = current.bloodPressureSystolic!.toDouble();
    bool isHigh = sys > 120;
    Color statusColor = isHigh ? Colors.orange : Colors.green;
    String statusLabel = isHigh ? "ELEVATED" : "NORMAL";

    double change = 0;
    if (previous?.bloodPressureSystolic != null) {
      change = sys - previous!.bloodPressureSystolic!.toDouble();
    }

    Color trendColor = change <= 0 ? Colors.green : Colors.redAccent;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Blood Pressure", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  Text("${current.bloodPressureSystolic}/${current.bloodPressureDiastolic}", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                  const SizedBox(width: 4), Text("mmHg", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                  if (change != 0) ...[
                    const SizedBox(width: 8),
                    Icon(change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: trendColor, size: 14),
                    const SizedBox(width: 2),
                    Text(change.abs().toStringAsFixed(0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: trendColor))
                  ]
                ],
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withOpacity(0.3))), child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5))),
              const SizedBox(height: 4),
              Text("< 120/80 mmHg", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  // =========================================================================
  // 🧠 THE AI INSIGHT GENERATOR (Math Failsafes Added)
  // =========================================================================
  String _generateSmartLabInsight(List<dynamic> configs) {
    if (previous == null || previous!.labResults.isEmpty) {
      return "Baseline biomarkers established. Future logs will display clinical trend analysis.";
    }

    String? biggestImprovementName;
    String? biggestWarningName;
    double maxImprovementPct = 0;
    double maxWarningPct = 0;

    for (var entry in current.labResults.entries) {
      if (!previous!.labResults.containsKey(entry.key)) continue;

      double curVal = (entry.value as num).toDouble();
      double prevVal = (previous!.labResults[entry.key] as num).toDouble();

      // Safety Check: Avoid dividing by zero!
      if (prevVal == 0) continue;

      var config;
      try { config = configs.firstWhere((c) => c.id.trim().toLowerCase() == entry.key.trim().toLowerCase()); } catch (_) { config = null; }

      String name = config != null ? config.name : entry.key.toUpperCase();
      bool isReverse = config?.isReverseLogic ?? false;

      double diff = curVal - prevVal;
      double pctChange = (diff / prevVal).abs() * 100;

      if (pctChange < 2.0) continue; // Ignore tiny fluctuations

      bool isGood = isReverse ? diff > 0 : diff < 0;

      if (isGood && pctChange > maxImprovementPct) {
        maxImprovementPct = pctChange;
        biggestImprovementName = name;
      } else if (!isGood && pctChange > maxWarningPct) {
        maxWarningPct = pctChange;
        biggestWarningName = name;
      }
    }

    if (biggestWarningName != null && maxWarningPct > 5.0) {
      return "Attention: Your $biggestWarningName has worsened by ${maxWarningPct.toStringAsFixed(1)}%. We recommend discussing this trend during your next review.";
    }

    if (biggestImprovementName != null) {
      return "Excellent! Your $biggestImprovementName has improved by ${maxImprovementPct.toStringAsFixed(1)}%. Your current protocol is showing clear clinical results.";
    }

    return "Your biomarkers remain stable compared to your previous tests. Consistency is key to maintaining health!";
  }
}