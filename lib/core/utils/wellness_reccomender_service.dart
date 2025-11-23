import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_registry.dart';

class WellnessRecommender {

  // 🎯 LOGIC: Get Top 5 Recommendations based on Context
  static List<WellnessTool> getRecommendations() {
    final now = DateTime.now().hour;

    // 1. Filter by Time of Day
    List<WellnessTool> timely = WellnessRegistry.allTools.where((t) {
      if (t.activeHours.isEmpty) return true; // Always active
      return t.activeHours.contains(now);
    }).toList();

    // 2. Sort by Priority (Lower number = Higher priority)
    timely.sort((a, b) => a.priority.compareTo(b.priority));

    // 3. Return Top 5
    return timely.take(5).toList();
  }

  // 🎯 Helper: Get tools by category
  static List<WellnessTool> getByCategory(WellnessCategory category) {
    return WellnessRegistry.allTools
        .where((t) => t.category == category)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}