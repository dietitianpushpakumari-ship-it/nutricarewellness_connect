import 'package:flutter/material.dart';

class BreathingConfig {
  final String title;
  final String description;
  final Color color;
  final int inhale;
  final int hold1;
  final int exhale;
  final int hold2;

  const BreathingConfig({
    required this.title,
    required this.description,
    required this.color,
    required this.inhale,
    required this.hold1,
    required this.exhale,
    required this.hold2,
  });

  static const box = BreathingConfig(title: "Box Breathing", description: "Focus & Clarity", color: Colors.teal, inhale: 4, hold1: 4, exhale: 4, hold2: 4);
  static const relax = BreathingConfig(title: "4-7-8 Relax", description: "Sleep Aid", color: Colors.indigo, inhale: 4, hold1: 7, exhale: 8, hold2: 0);
  static const energy = BreathingConfig(title: "Energy Boost", description: "Wake Up", color: Colors.orange, inhale: 2, hold1: 0, exhale: 2, hold2: 0);

  // 🎯 NEW
  static const coherence = BreathingConfig(title: "Coherence", description: "Balance Heart Rate", color: Colors.pink, inhale: 5, hold1: 0, exhale: 5, hold2: 0);
}