import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClientGoalModel {
  // 1. Core Metrics
  final double hydrationGoalLiters;
  final int stepGoal;
  final double sleepGoalHours;
  final int mindfulnessGoalMinutes;

  // 2. Specific Targets
  final TimeOfDay? idealBedTime;
  final TimeOfDay? idealWakeTime;

  // 3. Habits (Checklist)
  final bool trackMorningSun; // "Did you get 10 mins sun?"
  final bool trackFasting;    // "Did you fast for 14 hours?"
  final bool trackJournaling; // "Did you journal today?"

  const ClientGoalModel({
    this.hydrationGoalLiters = 3.0,
    this.stepGoal = 8000,
    this.sleepGoalHours = 7.5,
    this.mindfulnessGoalMinutes = 10,
    this.idealBedTime,
    this.idealWakeTime,
    this.trackMorningSun = false,
    this.trackFasting = false,
    this.trackJournaling = true,
  });

  // --- SERIALIZATION ---
  factory ClientGoalModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ClientGoalModel();

    TimeOfDay? parseTime(String? t) {
      if (t == null) return null;
      final parts = t.split(":");
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return ClientGoalModel(
      hydrationGoalLiters: (data['hydrationGoalLiters'] as num?)?.toDouble() ?? 3.0,
      stepGoal: (data['stepGoal'] as num?)?.toInt() ?? 8000,
      sleepGoalHours: (data['sleepGoalHours'] as num?)?.toDouble() ?? 7.5,
      mindfulnessGoalMinutes: (data['mindfulnessGoalMinutes'] as num?)?.toInt() ?? 10,
      idealBedTime: parseTime(data['idealBedTime']),
      idealWakeTime: parseTime(data['idealWakeTime']),
      trackMorningSun: data['trackMorningSun'] ?? false,
      trackFasting: data['trackFasting'] ?? false,
      trackJournaling: data['trackJournaling'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    String? fmtTime(TimeOfDay? t) => t == null ? null : "${t.hour}:${t.minute}";

    return {
      'hydrationGoalLiters': hydrationGoalLiters,
      'stepGoal': stepGoal,
      'sleepGoalHours': sleepGoalHours,
      'mindfulnessGoalMinutes': mindfulnessGoalMinutes,
      'idealBedTime': fmtTime(idealBedTime),
      'idealWakeTime': fmtTime(idealWakeTime),
      'trackMorningSun': trackMorningSun,
      'trackFasting': trackFasting,
      'trackJournaling': trackJournaling,
    };
  }

  // Factory for Default Goals
  factory ClientGoalModel.defaultGoals() => const ClientGoalModel();
}