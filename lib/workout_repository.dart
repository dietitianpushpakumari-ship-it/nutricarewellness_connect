import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/animation.dart';
import 'package:pure_shift/core/utils/workout_config.dart'; // Make sure this points to your models

class WorkoutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the assigned workout for a client.
  /// If none exists, or if the array is empty, it returns a premium default fallback.
  Future<WorkoutConfig> fetchClientWorkout(String clientId) async {
    try {
      final doc = await _firestore.collection('clients').doc(clientId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List assignedWorkouts = data['assignedWorkouts'] ?? [];

        // If the dietitian has assigned a routine, grab the most recent/relevant one.
        // For now, we'll grab the first one in the array.
        if (assignedWorkouts.isNotEmpty) {
          final targetRoutine = assignedWorkouts.first;
          return _parseRoutineToConfig(targetRoutine);
        }
      }

      // Fallback: No routine assigned, return the default standard protocol
      return _getFallbackWorkout();

    } catch (e) {
      // Log error and safely return fallback so the app doesn't crash
      print("SYS_ERR: Failed to fetch custom protocol: $e");
      return _getFallbackWorkout();
    }
  }

  /// Converts the raw JSON map from Firebase into your structured WorkoutConfig
  WorkoutConfig _parseRoutineToConfig(Map<String, dynamic> json) {
    final List stepsData = json['steps'] ?? [];

    final List<WorkoutStep> parsedSteps = stepsData.map((s) {
      // Safely parse the enum from string
      ExerciseType parsedType = ExerciseType.rest;
      try {
        parsedType = ExerciseType.values.byName(s['type']);
      } catch (_) {
        print("SYS_WARN: Unknown exercise type ${s['type']}, defaulting to rest.");
      }

      return WorkoutStep(
        type: parsedType,
        duration: s['duration'] ?? 30,
        reps: s['reps'] ?? 0,
        // Optional: you can dynamically set instructions or titles here based on the type
        title: _formatName(parsedType.name),
        instruction: "Execute with proper form.",
      );
    }).toList();

    return WorkoutConfig(
      title: json['title'] ?? "CLINICAL PROTOCOL",
      description: "Custom routine assigned by your dietitian. Scheduled for ${json['scheduledTime'] ?? 'today'}.",
      color: const Color(0xFF1E1E1E), // Industrial Dark
      steps: parsedSteps,
    );
  }

  /// The Default "Fallback" Routine if the dietitian hasn't set one yet
  WorkoutConfig _getFallbackWorkout() {
    return WorkoutConfig(
      title: "STANDARD WARMUP",
      description: "A baseline physiological calibration routine.",
      color: const Color(0xFF1E1E1E),
      steps: [
        WorkoutStep(type: ExerciseType.armCircles, duration: 30, reps: 0, title: "Arm Circles", instruction: "Wide, controlled rotations."),
        WorkoutStep(type: ExerciseType.squat, duration: 0, reps: 15, title: "Bodyweight Squats", instruction: "Keep your chest up and core tight."),
        WorkoutStep(type: ExerciseType.rest, duration: 15, reps: 0, title: "Rest", instruction: "Breathe and reset."),
        WorkoutStep(type: ExerciseType.plank, duration: 45, reps: 0, title: "Plank", instruction: "Maintain a rigid, straight line."),
      ],
    );
  }

  // Utility to format enum names (e.g., 'jumpingJack' -> 'Jumping Jack')
  String _formatName(String rawName) {
    String name = rawName.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ');
    return name[0].toUpperCase() + name.substring(1);
  }
}