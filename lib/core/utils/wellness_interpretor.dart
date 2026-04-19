import 'package:flutter/material.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

class WellnessInsight {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final bool isUrgent;

  WellnessInsight({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    this.isUrgent = false,
  });
}

class WellnessInterpreter {
  // 🧠 THE BRAIN: Analyzes the Master Daily Records
  static List<WellnessInsight> generateInsights(List<ClientLogModel> dailyRecords) {
    List<WellnessInsight> insights = [];
    if (dailyRecords.isEmpty) return [];

    // 1. Filter valid data points from the master records
    final validSteps = dailyRecords.where((l) => l.stepCount > 0).toList();
    final validSleep = dailyRecords.where((l) => l.totalSleepDurationHours > 0).toList();
    final validSugar = dailyRecords.where((l) => (l.fbsMgDl ?? 0) > 0).toList();

    // --- A. ACTIVITY ANALYSIS ---
    if (validSteps.isNotEmpty) {
      double avgSteps = validSteps.fold(0, (sum, l) => sum + l.stepCount) / validSteps.length;
      if (avgSteps < 3000) {
        insights.add(WellnessInsight(
          title: "Movement Alert",
          message: "Sedentary trend detected. A short 10-min walk today can improve insulin sensitivity.",
          color: Colors.orange,
          icon: Icons.directions_walk_rounded,
          isUrgent: true,
        ));
      } else if (avgSteps > 8000) {
        insights.add(WellnessInsight(
          title: "Active Lifestyle",
          message: "You're crushing your activity goals! High step counts help regulate blood sugar naturally.",
          color: Colors.green,
          icon: Icons.verified_rounded,
        ));
      }
    }

    // --- B. SLEEP ANALYSIS ---
    if (validSleep.isNotEmpty) {
      double avgSleep = validSleep.fold(0.0, (sum, l) => sum + l.totalSleepDurationHours) / validSleep.length;
      if (avgSleep < 6.0) {
        insights.add(WellnessInsight(
          title: "Sleep Debt",
          message: "Low sleep increases stress hormones. Aim for 7h tonight to aid metabolic recovery.",
          color: Colors.deepPurple,
          icon: Icons.bedtime_off_rounded,
        ));
      }
    }

    // --- C. METABOLIC CORRELATION ---
    if (validSugar.isNotEmpty) {
      final lastLog = validSugar.last;
      if ((lastLog.fbsMgDl ?? 0) > 130) {
        insights.add(WellnessInsight(
          title: "Sugar Spike",
          message: "Your last Fasting Sugar was high. Review your late-night snacks and stay hydrated.",
          color: Colors.red,
          icon: Icons.bloodtype_rounded,
          isUrgent: true,
        ));
      }
    }

    // --- D. DIET ADHERENCE (Atomic Map Logic) ---
    int totalDeviations = 0;
    for (var record in dailyRecords) {
      // 🎯 Search through the nested meal logs for deviations
      totalDeviations += record.mealLogs.values
          .where((m) => m.status == LogStatus.deviated)
          .length;
    }

    if (totalDeviations > 3) {
      insights.add(WellnessInsight(
        title: "Diet Deviations",
        message: "We noticed $totalDeviations deviations recently. Consistent meal timing helps stabilize mood.",
        color: Colors.amber.shade700,
        icon: Icons.restaurant_menu_rounded,
      ));
    }

    return insights;
  }

  // 📊 CALCULATE SCORE (0-100)
  static int calculateWellnessScore(List<ClientLogModel> records) {
    if (records.isEmpty) return 0;

    double totalScore = 0;
    int days = 0;

    for (var record in records) {
      days++;
      int daily = 50; // Base baseline

      // Metric Bonuses
      if (record.stepCount > 6000) daily += 15;
      if (record.totalSleepDurationHours > 6.5) daily += 10;
      if (record.hydrationLiters > 2.0) daily += 10;
      if (record.breathingMinutes > 5) daily += 10;

      // 🎯 Meal Adherence Penalties/Bonuses from the Map
      int deviations = record.mealLogs.values.where((m) => m.status == LogStatus.deviated).length;
      daily -= (deviations * 5);

      totalScore += daily.clamp(0, 100);
    }

    return days > 0 ? (totalScore / days).round() : 0;
  }

  // 🎯 ATOMIC COMPLIANCE LOGIC
  static Map<String, int> getMealCompliance(List<ClientLogModel> records) {
    int followed = 0;
    int skipped = 0;
    int deviated = 0;

    for (var record in records) {
      for (var meal in record.mealLogs.values) {
        if (meal.status == LogStatus.followed) followed++;
        else if (meal.status == LogStatus.skipped) skipped++;
        else if (meal.status == LogStatus.deviated) deviated++;
      }
    }

    return {
      "followed": followed,
      "skipped": skipped,
      "deviated": deviated
    };
  }
}