import 'package:flutter/material.dart';

enum WellnessCategory { physical, mental, spiritual, sleep, learning }

class WellnessTool {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WellnessCategory category;

  // 🎯 RECOMMENDATION ENGINE FIELDS
  final int priority; // 1 = High (Show first), 10 = Low
  final List<int> activeHours; // [6, 7, 8] = Morning tool. Empty = All day.

  // 🎯 NAVIGATION KEY (To map to the actual screen)
  final String routeKey;

  const WellnessTool({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.category,
    required this.priority,
    required this.routeKey,
    this.activeHours = const [],
  });
}