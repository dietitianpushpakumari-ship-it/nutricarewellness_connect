import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tiered persistence levels (FR-GOAL-03 to 05)
enum ReminderEscalation {
  soft,     // Tier 1: 1 notification
  standard, // Tier 2: 2 notifications
  aggressive, // Tier 3: 3 notifications
}

/// Settings for time-based, mandatory reminders (FR-TIME)
class TimeReminderSettings {
  final bool isActive;
  final TimeOfDay time;

  TimeReminderSettings({
    this.isActive = true,
    required this.time,
  });

  factory TimeReminderSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return TimeReminderSettings(isActive: false, time: const TimeOfDay(hour: 8, minute: 0));
    }
    final timeParts = (data['time'] as String? ?? '08:00').split(':');
    final hour = int.tryParse(timeParts[0]) ?? 8;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    return TimeReminderSettings(
      isActive: data['isActive'] as bool? ?? false,
      time: TimeOfDay(hour: hour, minute: minute),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    };
  }

  TimeReminderSettings copyWith({
    bool? isActive,
    TimeOfDay? time,
  }) {
    return TimeReminderSettings(
      isActive: isActive ?? this.isActive,
      time: time ?? this.time,
    );
  }
}

/// Settings for goal-based, skippable reminders (FR-GOAL)
class GoalReminderSettings {
  final bool isActive;
  final ReminderEscalation escalationLevel;

  GoalReminderSettings({
    this.isActive = true,
    this.escalationLevel = ReminderEscalation.soft,
  });

  factory GoalReminderSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return GoalReminderSettings();

    final level = ReminderEscalation.values.firstWhere(
          (e) => e.name == (data['escalationLevel'] as String? ?? 'soft'),
      orElse: () => ReminderEscalation.soft,
    );

    return GoalReminderSettings(
      isActive: data['isActive'] as bool? ?? true,
      escalationLevel: level,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'escalationLevel': escalationLevel.name,
    };
  }

  GoalReminderSettings copyWith({
    bool? isActive,
    ReminderEscalation? escalationLevel,
  }) {
    return GoalReminderSettings(
      isActive: isActive ?? this.isActive,
      escalationLevel: escalationLevel ?? this.escalationLevel,
    );
  }
}

/// The main configuration object (FR-DAT-01)
class ClientReminderConfig {
  final bool isActive;         // FR-DAT-02
  final bool isVoiceActive;    // FR-DAT-03
  final String voiceProfile;   // FR-DAT-05
  final String languageCode;   // FR-DAT-06

  final GoalReminderSettings hydrationReminder;
  final GoalReminderSettings stepReminder;
  final TimeReminderSettings medicineReminder;
  final TimeReminderSettings dietRoutineReminder;

  ClientReminderConfig({
    this.isActive = true,
    this.isVoiceActive = false,
    this.voiceProfile = 'male_coach_en',
    this.languageCode = 'en-US',
    required this.hydrationReminder,
    required this.stepReminder,
    required this.medicineReminder,
    required this.dietRoutineReminder,
  });

  /// Creates a default, "factory-new" configuration
  factory ClientReminderConfig.defaultConfig() {
    return ClientReminderConfig(
      hydrationReminder: GoalReminderSettings(escalationLevel: ReminderEscalation.standard),
      stepReminder: GoalReminderSettings(escalationLevel: ReminderEscalation.standard),
      medicineReminder: TimeReminderSettings(isActive: false, time: const TimeOfDay(hour: 9, minute: 0)),
      dietRoutineReminder: TimeReminderSettings(isActive: true, time: const TimeOfDay(hour: 21, minute: 0)), // 9 PM
    );
  }

  factory ClientReminderConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return ClientReminderConfig.defaultConfig();
    }
    return ClientReminderConfig(
      isActive: data['isActive'] as bool? ?? true,
      isVoiceActive: data['isVoiceActive'] as bool? ?? false,
      voiceProfile: data['voiceProfile'] as String? ?? 'male_coach_en',
      languageCode: data['languageCode'] as String? ?? 'en-US',
      hydrationReminder: GoalReminderSettings.fromMap(data['hydrationReminder'] as Map<String, dynamic>?),
      stepReminder: GoalReminderSettings.fromMap(data['stepReminder'] as Map<String, dynamic>?),
      medicineReminder: TimeReminderSettings.fromMap(data['medicineReminder'] as Map<String, dynamic>?),
      dietRoutineReminder: TimeReminderSettings.fromMap(data['dietRoutineReminder'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'isVoiceActive': isVoiceActive,
      'voiceProfile': voiceProfile,
      'languageCode': languageCode,
      'hydrationReminder': hydrationReminder.toMap(),
      'stepReminder': stepReminder.toMap(),
      'medicineReminder': medicineReminder.toMap(),
      'dietRoutineReminder': dietRoutineReminder.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ClientReminderConfig copyWith({
    bool? isActive,
    bool? isVoiceActive,
    String? voiceProfile,
    String? languageCode,
    GoalReminderSettings? hydrationReminder,
    GoalReminderSettings? stepReminder,
    TimeReminderSettings? medicineReminder,
    TimeReminderSettings? dietRoutineReminder,
  }) {
    return ClientReminderConfig(
      isActive: isActive ?? this.isActive,
      isVoiceActive: isVoiceActive ?? this.isVoiceActive,
      voiceProfile: voiceProfile ?? this.voiceProfile,
      languageCode: languageCode ?? this.languageCode,
      hydrationReminder: hydrationReminder ?? this.hydrationReminder,
      stepReminder: stepReminder ?? this.stepReminder,
      medicineReminder: medicineReminder ?? this.medicineReminder,
      dietRoutineReminder: dietRoutineReminder ?? this.dietRoutineReminder,
    );
  }
}