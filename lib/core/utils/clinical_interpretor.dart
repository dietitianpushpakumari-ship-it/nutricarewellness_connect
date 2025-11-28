import 'package:flutter/material.dart';

enum HealthStatus { optimal, normal, borderline, high, critical }

class ClinicalInterpreter {

  // --- 1. Color Coding ---
  static Color getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.optimal: return Colors.green.shade700;
      case HealthStatus.normal: return Colors.teal;
      case HealthStatus.borderline: return Colors.orange;
      case HealthStatus.high: return Colors.deepOrange;
      case HealthStatus.critical: return Colors.red;
    }
  }

  static String getStatusLabel(HealthStatus status) {
    return status.name.toUpperCase();
  }

  // --- 2. Logic: BMI ---
  static HealthStatus evaluateBMI(double bmi) {
    if (bmi < 18.5) return HealthStatus.borderline; // Underweight
    if (bmi < 23) return HealthStatus.optimal;      // Normal (Asian Standard)
    if (bmi < 25) return HealthStatus.normal;       // Normal (Global)
    if (bmi < 30) return HealthStatus.high;         // Overweight
    return HealthStatus.critical;                   // Obese
  }

  // --- 3. Logic: Blood Pressure (Systolic) ---
  static HealthStatus evaluateBPSys(int sys) {
    if (sys < 120) return HealthStatus.optimal;
    if (sys < 130) return HealthStatus.normal;
    if (sys < 140) return HealthStatus.borderline;
    if (sys < 180) return HealthStatus.high;
    return HealthStatus.critical;
  }

  // --- 4. Logic: Blood Sugar (Fasting) ---
  static HealthStatus evaluateSugarFasting(double val) {
    if (val < 100) return HealthStatus.optimal;
    if (val < 126) return HealthStatus.borderline; // Pre-diabetic
    return HealthStatus.high; // Diabetic
  }

  // --- 5. Trend Analysis ---
  static String analyzeTrend(double current, double previous, String metric, {bool lowerIsBetter = true}) {
    double diff = current - previous;
    if (diff.abs() < 0.5) return "Stable";

    bool isImprovement = lowerIsBetter ? (diff < 0) : (diff > 0);
    String arrow = diff > 0 ? "⬆" : "⬇";

    return "$arrow ${diff.abs().toStringAsFixed(1)} ($isImprovement)";
  }
}