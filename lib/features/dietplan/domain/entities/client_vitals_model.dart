// lib/features/vitals/domain/entities/client_vitals_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// Represents a single, trackable metric entry (e.g., Blood Sugar reading)
class MetricEntry extends Equatable {
  final double value;
  final String condition; // e.g., 'Fasting', 'Post-meal', 'Before Medication', 'Systolic', 'Diastolic'
  final Timestamp timestamp;

  const MetricEntry({
    required this.value,
    required this.condition,
    required this.timestamp,
  });

  factory MetricEntry.fromMap(Map<String, dynamic> data) {
    return MetricEntry(
      value: (data['value'] as num).toDouble(),
      condition: data['condition'] ?? '',
      timestamp: data['timestamp'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'condition': condition,
      'timestamp': timestamp,
    };
  }

  @override
  List<Object> get props => [value, condition, timestamp];
}

// 🎯 CORE CONFIG: Fully Admin-Controllable Reminder, Voice, and Escalation Settings
// This is used for all four reminder types (Medicine, Diet, Steps, Hydration).
class ReminderConfig extends Equatable {
  final String id;
  final String title;
  final String time;           // e.g., "07:00" (Used only for Time-Based reminders)

  // 1. MASTER REMINDER ON/OFF CONTROL
  final bool isActive;         // If false, the reminder is skipped entirely.

  // 2. VOICE ON/OFF CONTROL
  final bool isVoiceActive;    // If false, only text notification is sent.

  // 3. TIERED ESCALATION CONTROL
  final int escalationLevel;   // 1 (Soft), 2 (Standard), 3 (Max Aggression)

  // 4. VOICE PROFILE AND LANGUAGE
  final String voiceProfile;   // e.g., 'female_child', 'male_coach'
  final String languageCode;   // e.g., 'en-US', 'hi-IN', 'or-IN'

  const ReminderConfig({
    required this.id,
    required this.title,
    required this.time,
    this.isActive = true,
    this.isVoiceActive = true,
    this.escalationLevel = 1,
    this.voiceProfile = 'male_coach',
    this.languageCode = 'en-US',
  });

  factory ReminderConfig.fromMap(Map<String, dynamic> data, String id) {
    return ReminderConfig(
      id: id,
      title: data['title'] ?? '',
      time: data['time'] ?? '08:00',
      isActive: data['isActive'] ?? true,
      isVoiceActive: data['isVoiceActive'] ?? true, // New field mapping
      escalationLevel: data['escalationLevel'] ?? 1, // New field mapping
      voiceProfile: data['voiceProfile'] ?? 'male_coach',
      languageCode: data['languageCode'] ?? 'en-US',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'time': time,
      'isActive': isActive,
      'isVoiceActive': isVoiceActive, // Stored in DB
      'escalationLevel': escalationLevel, // Stored in DB
      'voiceProfile': voiceProfile,
      'languageCode': languageCode,
    };
  }

  @override
  List<Object> get props => [id, title, time, isActive, isVoiceActive, escalationLevel, voiceProfile, languageCode];
}


// 🎯 MAIN MODEL: Stores all Vitals and the Reminder Configurations
class ClientVitalsModel extends Equatable {
  final String clientId;

  // 1. Vitals Tracking
  final List<MetricEntry> bloodSugarHistory;
  final String? hba1cValue;
  final List<MetricEntry> bloodPressureHistory;

  // 2. Time-Based Reminders (Critical/Scheduled)
  final List<ReminderConfig> medicineReminders;
  final List<ReminderConfig> dietRoutineReminders;

  // 3. Goal-Based Reminders (Goal-Aware and Non-Scheduled)
  final ReminderConfig? stepTrackerReminder;
  final ReminderConfig? hydrationTrackerReminder;

  // 4. Stress Management / Sleep Support (Replaces fixed alarms)
  final List<Map<String, String>> bedtimeExplorationContent; // List of {title: "Guided Meditation", url: "https://..."}


  final Timestamp? lastUpdated;

  const ClientVitalsModel({
    required this.clientId,
    this.bloodSugarHistory = const [],
    this.hba1cValue,
    this.bloodPressureHistory = const [],
    this.medicineReminders = const [],
    this.dietRoutineReminders = const [],
    this.stepTrackerReminder,
    this.hydrationTrackerReminder,
    this.bedtimeExplorationContent = const [],
    this.lastUpdated,
  });

  factory ClientVitalsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Helper to safely map a single reminder config
    ReminderConfig? _mapSingleReminder(Map<String, dynamic>? item, String id) {
      return item != null ? ReminderConfig.fromMap(item, id) : null;
    }

    // Helper to safely map list of dynamic maps to List<Map<String, String>>
    List<Map<String, String>> _mapContentList(dynamic list) {
      return (list as List<dynamic>? ?? [])
          .map((item) => Map<String, String>.from(item as Map))
          .toList();
    }

    return ClientVitalsModel(
      clientId: doc.id,

      // Map vitals history...
      bloodSugarHistory: (data['bloodSugarHistory'] as List<dynamic>? ?? [])
          .map((item) => MetricEntry.fromMap(item as Map<String, dynamic>))
          .toList(),
      bloodPressureHistory: (data['bloodPressureHistory'] as List<dynamic>? ?? [])
          .map((item) => MetricEntry.fromMap(item as Map<String, dynamic>))
          .toList(),
      hba1cValue: data['hba1cValue'],

      // Map lists of ReminderConfig
      medicineReminders: (data['medicineReminders'] as List<dynamic>? ?? [])
          .map((item) => ReminderConfig.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
          .toList(),
      dietRoutineReminders: (data['dietRoutineReminders'] as List<dynamic>? ?? [])
          .map((item) => ReminderConfig.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
          .toList(),

      // Map single ReminderConfig objects (Goal-Based)
      stepTrackerReminder: _mapSingleReminder(data['stepTrackerReminder'] as Map<String, dynamic>?, 'steps'),
      hydrationTrackerReminder: _mapSingleReminder(data['hydrationTrackerReminder'] as Map<String, dynamic>?, 'hydration'),

      bedtimeExplorationContent: _mapContentList(data['bedtimeExplorationContent']),

      lastUpdated: data['lastUpdated'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'bloodSugarHistory': bloodSugarHistory.map((e) => e.toMap()).toList(),
      'hba1cValue': hba1cValue,
      'bloodPressureHistory': bloodPressureHistory.map((e) => e.toMap()).toList(),

      'medicineReminders': medicineReminders.map((e) => e.toMap()).toList(),
      'dietRoutineReminders': dietRoutineReminders.map((e) => e.toMap()).toList(),

      'stepTrackerReminder': stepTrackerReminder?.toMap(),
      'hydrationTrackerReminder': hydrationTrackerReminder?.toMap(),

      'bedtimeExplorationContent': bedtimeExplorationContent,

      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
    clientId,
    bloodSugarHistory,
    hba1cValue,
    bloodPressureHistory,
    medicineReminders,
    dietRoutineReminders,
    stepTrackerReminder,
    hydrationTrackerReminder,
    bedtimeExplorationContent,
    lastUpdated,
  ];
}