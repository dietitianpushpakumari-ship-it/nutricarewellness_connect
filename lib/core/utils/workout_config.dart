import 'package:flutter/material.dart';

// 🎯 1. Define supported animations (Expanded for clinical routines)
enum ExerciseType {
  jumpingJack,
  squat,
  pushup,
  highKnees,
  armCircles,
  rest,
  neckRoll,
  shoulderShrug,
  // 🎯 NEW: Added to support clinical & desk relief routines
  pacing,
  calfRaise,
  seatedTwist,
  wristStretch,
}

class WorkoutStep {
  final String title;
  final String instruction;
  final int duration;
  final IconData icon;
  final bool isRest;
  final ExerciseType type;

  // 🎯 NEW FEATURES ADDED HERE
  final bool isRepBased; // If true, timer is hidden and waits for user to tap "Done"
  final int reps;        // e.g., 20 Calf Raises
  final bool switchSides; // If true, TTS will announce "Halfway there, switch sides!" at 50% time

  const WorkoutStep({
    required this.title,
    required this.instruction,
    required this.duration,
    required this.icon,
    this.isRest = false,
    required this.type,
    // 🎯 Defaults set so your old configs don't break
    this.isRepBased = false,
    this.reps = 0,
    this.switchSides = false,
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

  // ==========================================================
  // --- PRESETS ---
  // ==========================================================

  static const morningStretch = WorkoutConfig(
    title: "Morning Warmup",
    description: "Wake up your muscles.",
    color: Colors.orange,
    steps: [
      WorkoutStep(title: "High Knees", instruction: "March in place.", duration: 30, icon: Icons.directions_run, type: ExerciseType.highKnees),
      WorkoutStep(title: "Rest", instruction: "Breathe.", duration: 10, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      // 🎯 Example: Added switchSides to Arm Circles so it prompts to reverse direction
      WorkoutStep(title: "Arm Circles", instruction: "Big circles.", duration: 30, icon: Icons.refresh, type: ExerciseType.armCircles, switchSides: true),
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
      // 🎯 Example: Converted Push-Ups to Rep-Based!
      WorkoutStep(title: "Push-Ups", instruction: "Chest to floor.", duration: 0, isRepBased: true, reps: 15, icon: Icons.fitness_center, type: ExerciseType.pushup),
    ],
  );

  // 🎯 CLINICAL UPGRADE: Expanded for Software Engineers
  static const deskRelief = WorkoutConfig(
    title: "The Coder's Reset",
    description: "5 mins to fix posture and relieve wrist strain.",
    color: Colors.blue,
    steps: [
      WorkoutStep(title: "Neck Rolls", instruction: "Roll gently in circles.", duration: 30, icon: Icons.sentiment_satisfied, type: ExerciseType.neckRoll, switchSides: true),
      WorkoutStep(title: "Wrist Stretch", instruction: "Extend arm, pull fingers back.", duration: 40, icon: Icons.back_hand_rounded, type: ExerciseType.wristStretch, switchSides: true),
      WorkoutStep(title: "Seated Twist", instruction: "Twist torso to the right.", duration: 40, icon: Icons.airline_seat_recline_normal, type: ExerciseType.seatedTwist, switchSides: true),
      WorkoutStep(title: "Shoulder Shrugs", instruction: "Release tension.", duration: 30, icon: Icons.accessibility, type: ExerciseType.shoulderShrug),
    ],
  );

  // 🎯 NEW CLINICAL ROUTINE: Metabolic Health
  static const glucoseBurner = WorkoutConfig(
    title: "Post-Meal Burner",
    description: "Light movement 15 mins after eating to manage blood sugar.",
    color: Colors.teal,
    steps: [
      WorkoutStep(title: "Brisk Pacing", instruction: "Walk around the room briskly.", duration: 60, icon: Icons.directions_walk, type: ExerciseType.pacing),
      WorkoutStep(title: "Rest", instruction: "Breathe.", duration: 15, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "Calf Raises", instruction: "Stand on toes, hold, and lower.", duration: 0, isRepBased: true, reps: 20, icon: Icons.height, type: ExerciseType.calfRaise),
      WorkoutStep(title: "Rest", instruction: "Breathe.", duration: 15, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "High Knees", instruction: "March in place gently.", duration: 60, icon: Icons.directions_run, type: ExerciseType.highKnees),
    ],
  );
}