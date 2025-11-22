import 'package:flutter/material.dart';

class BreathingConfig {
  final String title;
  final String description;
  final int inhale;
  final int hold1;
  final int exhale;
  final int hold2;
  final Color color; // 🎯 Ensure this says 'Color', not 'Vector4'

  const BreathingConfig({
    required this.title,
    required this.description,
    required this.inhale,
    required this.hold1,
    required this.exhale,
    required this.hold2,
    required this.color,
  });

  // --- PRESETS ---

  static const box = BreathingConfig(
    title: "Box Breathing",
    description: "For Focus & Clarity",
    inhale: 4, hold1: 4, exhale: 4, hold2: 4,
    color: Colors.teal, // 🎯 This must be a Color
  );

  static const relax = BreathingConfig(
    title: "4-7-8 Relax",
    description: "For Anxiety & Sleep",
    inhale: 4, hold1: 7, exhale: 8, hold2: 0,
    color: Colors.indigo,
  );

  static const energy = BreathingConfig(
    title: "Energy Boost",
    description: "Wake up your mind",
    inhale: 4, hold1: 0, exhale: 2, hold2: 0,
    color: Colors.orange,
  );
}