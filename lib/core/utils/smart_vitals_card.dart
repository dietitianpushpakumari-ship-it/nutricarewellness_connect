import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/clinical_interpretor.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';

class SmartVitalsReportCard extends StatelessWidget {
  final VitalsModel current;
  final VitalsModel? previous; // For trend comparison

  const SmartVitalsReportCard({
    super.key,
    required this.current,
    this.previous,
  });

  @override
  Widget build(BuildContext context) {
    // 🎯 THEME INTEGRATION
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Health Intelligence",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "AI-Powered Analysis",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_graph,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
            ],
          ),
          Divider(height: 30, color: colorScheme.outlineVariant),

          // --- 1. Weight Analysis ---
          _buildAnalysisRow(
            context,
            "Weight Management",
            "${current.weightKg} kg",
            ClinicalInterpreter.evaluateBMI(current.bmi),
            previous != null ? (current.weightKg - previous!.weightKg) : 0,
            "BMI: ${current.bmi.toStringAsFixed(1)}",
          ),

          const SizedBox(height: 20),

          // --- 2. BP Analysis (If available) ---
          if (current.bloodPressureSystolic != null && current.bloodPressureDiastolic != null)
            _buildAnalysisRow(
              context,
              "Blood Pressure",
              "${current.bloodPressureSystolic}/${current.bloodPressureDiastolic}",
              ClinicalInterpreter.evaluateBPSys(current.bloodPressureSystolic!),
              previous?.bloodPressureSystolic != null
                  ? (current.bloodPressureSystolic! - previous!.bloodPressureSystolic!).toDouble()
                  : 0,
              "Sys Risk",
            ),

          // --- 3. Sugar Analysis (If available in lab results) ---
          // 🛠️ FIX: labResults values are already doubles, no need to parse.
          if (current.labResults.containsKey('fbs')) ...[
            const SizedBox(height: 20),
            _buildAnalysisRow(
              context,
              "Fasting Sugar",
              "${current.labResults['fbs']!.toInt()} mg/dL",
              ClinicalInterpreter.evaluateSugarFasting(current.labResults['fbs']!),
              0, // Diff calculation omitted for simplicity or requires robust map check
              "Diabetic Range",
            ),
          ],

          const SizedBox(height: 20),

          // --- 4. Smart Insight Text ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.secondaryContainer),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _generateInsight(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(
      BuildContext context,
      String title,
      String value,
      HealthStatus status,
      double change,
      String subtitle,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = ClinicalInterpreter.getStatusColor(status);
    final label = ClinicalInterpreter.getStatusLabel(status);

    // Determine trend icon color (assuming lower is better for Weight/BP/Sugar)
    final trendColor = change > 0 ? colorScheme.error : const Color(0xFF4CAF50); // Red if up, Green if down

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (change != 0) ...[
                    const SizedBox(width: 8),
                    Icon(
                      change > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: trendColor,
                      size: 20,
                    ),
                    Text(
                      change.abs().toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: trendColor,
                      ),
                    )
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
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  String _generateInsight() {
    if (previous == null) {
      return "First record logged. Keep tracking to see trends!";
    }

    double weightDiff = current.weightKg - previous!.weightKg;
    if (weightDiff < -0.5) {
      return "Great job! You've lost ${weightDiff.abs().toStringAsFixed(1)} kg since last check-in. Consistency is key!";
    }
    if (weightDiff > 0.5) {
      return "Weight has increased slightly. Let's review your diet plan adherence.";
    }

    return "Your vitals are stable. Maintain this routine to see long-term benefits.";
  }
}