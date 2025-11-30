import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/clinical_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/main.dart';
import 'package:nutricare_connect/core/utils/wellness_message_generator.dart';
import 'package:collection/collection.dart';
import 'package:nutricare_connect/core/utils/meal_master_name.dart';

// 🎯 IMPORT Clinical Models for PrescribedMedication

class LocalReminderService {

  // Singleton-like accessor if needed, or just use as instance
  static final LocalReminderService _instance = LocalReminderService._internal();
  factory LocalReminderService() => _instance;
  LocalReminderService._internal();

  // ===========================================================================
  // 1. MAIN SCHEDULE LOGIC (Daily Routine & Goals)
  // ===========================================================================
  Future<void> reScheduleAllReminders({
    required ClientModel client,
    required ClientDietPlanModel? activePlan,
    required List<ClientLogModel> dailyLogs,
  }) async {
    // Wipe existing (except meds, ideally we should manage IDs better, but this is a full refresh)
    // NOTE: If you want to keep meds separate, don't cancel all here.
    // For now, we assume this refreshes everything.
    await flutterLocalNotificationsPlugin.cancelAll();

    final ClientReminderConfig? config = client.reminderConfig;
    final ClientLogModel? dailyLog = dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    // If global switch is off, stop here
    if (config == null || !config.isActive) {
      print("Reminders are globally disabled.");
      return;
    }

    // A. MEAL REMINDERS
    if (activePlan != null) {
      await _scheduleMealReminders(activePlan, dailyLogs, config);
    }

    // B. FIXED TIME REMINDERS (Routine)
    if (config.medicineReminder.isActive) {
      _scheduleTimeBasedReminder("Medicine Check", config.medicineReminder, config, 'medicine');
    }
    if (config.dietRoutineReminder.isActive) {
      _scheduleTimeBasedReminder("End of Day Log", config.dietRoutineReminder, config, 'log');
    }

    // C. GOAL-BASED REMINDERS (Nudges)
    if (config.hydrationReminder.isActive) {
      _scheduleGoalReminder(
          "Hydration",
          config.hydrationReminder,
          dailyLog?.hydrationLiters ?? 0.0,
          activePlan?.dailyWaterGoal ?? 3.0,
          config,
          'hydration'
      );
    }

    if (config.stepReminder.isActive) {
      _scheduleGoalReminder(
          "Movement",
          config.stepReminder,
          dailyLog?.stepCount?.toDouble() ?? 0,
          activePlan?.dailyStepGoal.toDouble() ?? 8000.0,
          config,
          'steps'
      );
    }
  }

  // ===========================================================================
  // 2. MEDICATION SPECIFIC SCHEDULER
  // ===========================================================================
  Future<void> scheduleMedicationReminders(List<PrescribedMedication> meds) async {
    for (var med in meds) {
      // Use hashcode of medicine name as notification ID to avoid collisions
      final int notificationId = med.medicineName.hashCode;

      if (med.isReminderEnabled && med.reminderTime != null) {
        final parts = med.reminderTime!.split(':');
        final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

        await _scheduleNotification(
          id: notificationId,
          title: "Medication Time",
          body: "Time to take ${med.medicineName} (${med.frequency})",
          scheduledDate: _getTodayDateAt(time),
          config: null, // Medication reminders don't rely on general config for now
          voiceMessage: "It is time to take your medication, ${med.medicineName}",
        );
      } else {
        // Cancel if disabled
        await flutterLocalNotificationsPlugin.cancel(notificationId);
      }
    }
  }

  // ===========================================================================
  // 3. INTERNAL HELPERS
  // ===========================================================================

  Future<void> _scheduleMealReminders(ClientDietPlanModel plan, List<ClientLogModel> logs, ClientReminderConfig config) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('masterMealNames').get();
      final masterMeals = snapshot.docs.map((d) => MasterMealName.fromFirestore(d)).toList();

      if (plan.days.isEmpty) return;
      final todayMeals = plan.days.first.meals;

      for (var meal in todayMeals) {
        final isLogged = logs.any((l) => l.mealName == meal.mealName && l.logStatus != LogStatus.skipped);
        if (isLogged) continue;

        final timeConfig = masterMeals.firstWhereOrNull((m) => m.id == meal.mealNameId || m.enName == meal.mealName);

        if (timeConfig != null && timeConfig.endTime != null) {
          final parts = timeConfig.endTime!.split(':');
          final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

          await _scheduleNotification(
            id: meal.mealName.hashCode,
            title: "Log ${meal.mealName}",
            body: "Reminder: Track your meal.",
            scheduledDate: _getTodayDateAt(time),
            config: config,
            voiceMessage: "Hi, have you had your ${meal.mealName}? Don't forget to log it.",
          );
        }
      }
    } catch (e) {
      print("Error scheduling meal reminders: $e");
    }
  }

  void _scheduleTimeBasedReminder(String title, TimeReminderSettings settings, ClientReminderConfig config, String type) {
    if (!settings.isActive) return;
    final message = WellnessMessageGenerator.getMessage(type: type, languageCode: config.languageCode);
    final scheduledTime = _getNextValidTime(settings.time);

    _scheduleNotification(
      id: title.hashCode,
      title: title,
      body: message,
      scheduledDate: scheduledTime,
      config: config,
      voiceMessage: message,
    );
  }

  void _scheduleGoalReminder(String title, GoalReminderSettings settings, double current, double goal, ClientReminderConfig config, String type) {
    if (!settings.isActive || current >= goal) return;
    final message = WellnessMessageGenerator.getMessage(type: type, languageCode: config.languageCode);
    final nextTime = tz.TZDateTime.now(tz.local).add(const Duration(hours: 2));

    _scheduleNotification(
      id: title.hashCode,
      title: "$title Check-in",
      body: message,
      scheduledDate: nextTime,
      config: config,
      voiceMessage: message,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    ClientReminderConfig? config, // Nullable to allow direct calls
    required String voiceMessage,
  }) async {

    final now = tz.TZDateTime.now(tz.local);
    if (scheduledDate.isBefore(now)) return;

    final Map<String, dynamic> payloadMap = {
      'isVoiceActive': config?.isVoiceActive ?? false,
      'textToSpeak': voiceMessage,
      'languageCode': config?.languageCode ?? 'en-US',
      'voiceProfile': config?.voiceProfile ?? 'calm',
    };

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wellness_channel_id',
      'Wellness Reminders',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('default_sound'),
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformDetails,
      payload: jsonEncode(payloadMap),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    print("✅ Scheduled '$title' for $scheduledDate");
  }

  tz.TZDateTime _getTodayDateAt(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
  }

  tz.TZDateTime _getNextValidTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}