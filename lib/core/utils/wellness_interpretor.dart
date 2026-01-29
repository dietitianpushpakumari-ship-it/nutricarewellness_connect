import 'package:flutter/material.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart'; // Ensure Vitals are accessible if needed, else use Log fields

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
  // 🧠 THE BRAIN: Analyzes list of logs and returns insights
  static List<WellnessInsight> generateInsights(List<ClientLogModel?> recentLogs) {
    List<WellnessInsight> insights = [];
    if (recentLogs.isEmpty) return [];

    // 1. Get Averages (Filter out nulls/zeros)
    final validSteps = recentLogs.where((l) => (l?.stepCount ?? 0) > 0).toList();
    final validSleep = recentLogs.where((l) => (l?.totalSleepDurationHours ?? 0) > 0).toList();
    final validWater = recentLogs.where((l) => (l?.hydrationLiters ?? 0) > 0).toList();
    final validSugar = recentLogs.where((l) => (l?.fbsMgDl ?? 0) > 0).toList();
    final validBP = recentLogs.where((l) => (l?.bloodPressureSystolic ?? 0) > 0).toList();

    // --- A. ACTIVITY ANALYSIS ---
    if (validSteps.isNotEmpty) {
      double avgSteps = validSteps.fold(0, (sum, l) => sum + l!.stepCount!) / validSteps.length;
      if (avgSteps < 3000) {
        insights.add(WellnessInsight(
          title: "Movement Alert",
          message: "Sedentary week detected. Try a 10-min walk after lunch to boost metabolism.",
          color: Colors.orange,
          icon: Icons.directions_walk,
          isUrgent: true,
        ));
      } else if (avgSteps > 8000) {
        insights.add(WellnessInsight(
          title: "Active Lifestyle",
          message: "You're crushing your activity goals! This helps regulate blood sugar naturally.",
          color: Colors.green,
          icon: Icons.verified,
        ));
      }
    }

    // --- B. SLEEP ANALYSIS ---
    if (validSleep.isNotEmpty) {
      double avgSleep = validSleep.fold(0.0, (sum, l) => sum + l!.totalSleepDurationHours!) / validSleep.length;
      if (avgSleep < 6.0) {
        insights.add(WellnessInsight(
          title: "Sleep Debt",
          message: "Low sleep increases cortisol (stress). Aim for 7h tonight to aid recovery.",
          color: Colors.deepPurple,
          icon: Icons.bedtime_off,
        ));
      }
    }

    // --- C. METABOLIC CORRELATION (The "Smart" Part) ---
    // Check if High Sugar correlates with Low Sleep or Bad Food
    if (validSugar.isNotEmpty) {
      final lastLog = validSugar.last!; // Sort chronologically before calling
      if (lastLog.fbsMgDl! > 130) {
        insights.add(WellnessInsight(
          title: "Sugar Spike",
          message: "Fasting levels are elevated. Avoid late-night snacking and check hydration.",
          color: Colors.red,
          icon: Icons.bloodtype,
          isUrgent: true,
        ));
      }
    }

    // --- D. DIET ADHERENCE ---
    int deviations = recentLogs.where((l) => l?.logStatus == LogStatus.deviated).length;
    if (deviations > 3) {
      insights.add(WellnessInsight(
        title: "Diet Deviations",
        message: "We noticed $deviations deviations recently. Prep meals in advance to stay on track.",
        color: Colors.amber,
        icon: Icons.restaurant_menu,
      ));
    }

    return insights;
  }

  // 📊 CALCULATE SCORE (0-100)
  static int calculateWellnessScore(List<ClientLogModel?> logs) {
    if (logs.isEmpty) return 0;

    // Simple weighted algorithm
    // Base: 50
    // +10 for hitting step goal
    // +10 for good sleep
    // +10 for hydration
    // -5 per deviation

    // (Simplified for this example - you can make it complex)
    double totalScore = 0;
    int days = 0;

    for (var log in logs) {
      if (log == null) continue;
      days++;
      int daily = 50; // Start
      if ((log.stepCount ?? 0) > 6000) daily += 10;
      if ((log.totalSleepDurationHours ?? 0) > 6.5) daily += 10;
      if ((log.hydrationLiters ?? 0) > 2.0) daily += 10;
      if ((log.breathingMinutes ?? 0) > 5) daily += 10;
      if (log.logStatus == LogStatus.deviated) daily -= 10;
      if (log.logStatus == LogStatus.followed) daily += 10;

      totalScore += daily.clamp(0, 100);
    }

    return days > 0 ? (totalScore / days).round() : 0;
  }

  static Map<String, int> getMealCompliance(List<ClientLogModel?> logs) {
    int followed = 0;
    int skipped = 0;
    int deviated = 0;

    for(var l in logs) {
      if(l == null) continue;
      // Note: ClientLogModel usually stores ONE meal per doc.
      // If you are analyzing daily aggregates, you need to count across all meal docs for those days.
      // Assuming 'logs' passed here includes Meal Logs (not just Wellness Checks).
      if(l.mealName == 'DAILY_WELLNESS_CHECK') continue;

      if(l.logStatus == LogStatus.followed) followed++;
      if(l.logStatus == LogStatus.skipped) skipped++;
      if(l.logStatus == LogStatus.deviated) deviated++;
    }
    return {"followed": followed, "skipped": skipped, "deviated": deviated};
  }
}