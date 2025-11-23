import 'package:flutter/material.dart';

// 🎯 1. Define supported animations
enum ExerciseType {
  jumpingJack,
  squat,
  pushup,
  highKnees,
  armCircles,
  rest,
  neckRoll,
  shoulderShrug
}

class WorkoutStep {
  final String title;
  final String instruction;
  final int duration;
  final IconData icon;
  final bool isRest;

  // 🎯 2. Use Enum instead of String path
  final ExerciseType type;

  const WorkoutStep({
    required this.title,
    required this.instruction,
    required this.duration,
    required this.icon,
    this.isRest = false,
    required this.type, // Required now
  });
}

class WorkoutConfig {
  final String title;
  final String description;
  final Color color;
  final List<WorkoutStep> steps;

  const WorkoutConfig({
    required this.title,
    required this.description,
    required this.color,
    required this.steps,
  });

  // --- PRESETS (Updated to use Enum) ---

  static const morningStretch = WorkoutConfig(
    title: "Morning Warmup",
    description: "Wake up your muscles.",
    color: Colors.orange,
    steps: [
      WorkoutStep(title: "High Knees", instruction: "March in place.", duration: 30, icon: Icons.directions_run, type: ExerciseType.highKnees),
      WorkoutStep(title: "Rest", instruction: "Breathe.", duration: 10, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "Arm Circles", instruction: "Big circles.", duration: 30, icon: Icons.refresh, type: ExerciseType.armCircles),
      WorkoutStep(title: "Rest", instruction: "Relax.", duration: 10, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "Shoulder Shrugs", instruction: "Lift & Drop.", duration: 30, icon: Icons.accessibility, type: ExerciseType.shoulderShrug),
    ],
  );

  static const quickHIIT = WorkoutConfig(
    title: "7-Min HIIT",
    description: "Full body burn.",
    color: Colors.red,
    steps: [
      WorkoutStep(title: "Jumping Jacks", instruction: "Jump wide.", duration: 40, icon: Icons.star, type: ExerciseType.jumpingJack),
      WorkoutStep(title: "Rest", instruction: "Breathe.", duration: 20, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "Squats", instruction: "Sit back.", duration: 40, icon: Icons.accessibility_new, type: ExerciseType.squat),
      WorkoutStep(title: "Rest", instruction: "Relax.", duration: 20, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "Push-Ups", instruction: "Chest to floor.", duration: 40, icon: Icons.fitness_center, type: ExerciseType.pushup),
    ],
  );

  static const deskRelief = WorkoutConfig(
    title: "Desk Detox",
    description: "Fix stiff neck.",
    color: Colors.blue,
    steps: [
      WorkoutStep(title: "Neck Rolls", instruction: "Roll gently.", duration: 30, icon: Icons.sentiment_satisfied, type: ExerciseType.neckRoll),
      WorkoutStep(title: "Shoulder Shrugs", instruction: "Release tension.", duration: 30, icon: Icons.accessibility, type: ExerciseType.shoulderShrug),
    ],
  );
}