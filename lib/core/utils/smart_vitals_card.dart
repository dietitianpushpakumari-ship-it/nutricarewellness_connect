import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/clinical_interpretor.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';


class SmartVitalsReportCard extends StatelessWidget {
  final VitalsModel current;
  final VitalsModel? previous; // For trend comparison

  const SmartVitalsReportCard({super.key, required this.current, this.previous});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))
        ],
        border: Border.all(color: Colors.indigo.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Health Intelligence", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  Text("AI-Powered Analysis", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.auto_graph, color: Colors.purple, size: 20),
              ),
            ],
          ),
          const Divider(height: 30),

          // 1. Weight Analysis
          _buildAnalysisRow(
            "Weight Management",
            "${current.weightKg} kg",
            ClinicalInterpreter.evaluateBMI(current.bmi),
            previous != null ? (current.weightKg - previous!.weightKg) : 0,
            "BMI: ${current.bmi.toStringAsFixed(1)}",
          ),

          const SizedBox(height: 20),

          // 2. BP Analysis (If available)
          if (current.bloodPressureSystolic != null)
            _buildAnalysisRow(
              "Blood Pressure",
              "${current.bloodPressureSystolic}/${current.bloodPressureDiastolic}",
              ClinicalInterpreter.evaluateBPSys(current.bloodPressureSystolic!),
              previous?.bloodPressureSystolic != null ? (current.bloodPressureSystolic! - previous!.bloodPressureSystolic!).toDouble() : 0,
              "Sys Risk",
            ),

          // 3. Sugar Analysis (If available in lab results)
          if (current.labResults.containsKey('fbs'))
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _buildAnalysisRow(
                "Fasting Sugar",
                "${current.labResults['fbs']} mg/dL",
                ClinicalInterpreter.evaluateSugarFasting(double.tryParse(current.labResults['fbs']!) ?? 0),
                0, // Diff calculation requires parsing previous lab map
                "Diabetic Range",
              ),
            ),

          const SizedBox(height: 20),

          // 4. Smart Insight Text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.indigo, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _generateInsight(),
                    style: TextStyle(fontSize: 13, color: Colors.indigo.shade900, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String title, String value, HealthStatus status, double change, String subtitle) {
    final color = ClinicalInterpreter.getStatusColor(status);
    final label = ClinicalInterpreter.getStatusLabel(status);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2D3142))),
                  if (change != 0) ...[
                    const SizedBox(width: 8),
                    Icon(
                      change > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: change > 0 ? Colors.red : Colors.green, // Assuming lower is better for Wt/BP
                      size: 20,
                    ),
                    Text(
                      "${change.abs().toStringAsFixed(1)}",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: change > 0 ? Colors.red : Colors.green),
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
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        )
      ],
    );
  }

  String _generateInsight() {
    // Simple logic generator
    if (previous == null) return "First record logged. Keep tracking to see trends!";

    double weightDiff = current.weightKg - previous!.weightKg;
    if (weightDiff < -0.5) return "Great job! You've lost ${weightDiff.abs().toStringAsFixed(1)} kg since last check-in. Consistency is key!";
    if (weightDiff > 0.5) return "Weight has increased slightly. Let's review your diet plan adherence.";

    return "Your vitals are stable. Maintain this routine to see long-term benefits.";
  }
}