import 'package:flutter/material.dart';

// 🎯 1. Define supported animations (Fully expanded for clinical & strength routines)
enum ExerciseType {
  jumpingJack,
  squat,
  pushup,
  highKnees,
  armCircles,
  rest,
  neckRoll,
  shoulderShrug,
  pacing,
  calfRaise,
  seatedTwist,
  wristStretch,
  // 🎯 NEW: Added missing core and lower body exercises
  plank,
  lunges,
  situp,
  gluteBridge,
}

class WorkoutStep {
  final String title;
  final String instruction;
  final int duration;
  final IconData icon;
  final bool isRest;
  final ExerciseType type;

  // 🎯 NEW FEATURES
  final bool isRepBased; // If true, timer is hidden and waits for user to tap "Done"
  final int reps;        // e.g., 20 Calf Raises
  final bool switchSides; // If true, TTS will announce "Halfway there, switch sides!" at 50% time

  const WorkoutStep({
    required this.title,
    required this.instruction,
    required this.duration,
    this.icon = Icons.fitness_center,
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
      WorkoutStep(title: "Lunges", instruction: "Step forward, drop the knee.", duration: 40, icon: Icons.transfer_within_a_station, type: ExerciseType.lunges, switchSides: true),
      WorkoutStep(title: "Rest", instruction: "Relax.", duration: 20, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
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

  // 🎯 NEW PRESET: Core & Post-Op Recovery Focus
  static const coreAndGlutes = WorkoutConfig(
    title: "Core & Stability",
    description: "Strengthen your core and posterior chain safely.",
    color: Colors.purple,
    steps: [
      WorkoutStep(title: "Glute Bridge", instruction: "Drive hips up, squeeze at the top.", duration: 40, icon: Icons.airline_seat_legroom_extra, type: ExerciseType.gluteBridge),
      WorkoutStep(title: "Rest", instruction: "Breathe.", duration: 15, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "Sit-Ups", instruction: "Keep feet flat, use your abs.", duration: 0, isRepBased: true, reps: 15, icon: Icons.accessibility_new, type: ExerciseType.situp),
      WorkoutStep(title: "Rest", instruction: "Breathe.", duration: 15, icon: Icons.timer, isRest: true, type: ExerciseType.rest),
      WorkoutStep(title: "Forearm Plank", instruction: "Keep your body in a straight line.", duration: 45, icon: Icons.horizontal_rule_rounded, type: ExerciseType.plank),
    ],
  );
}