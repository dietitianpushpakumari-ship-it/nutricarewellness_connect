import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🎯 Needed for fetching Master Times
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/main.dart';
import 'package:nutricare_connect/core/utils/wellness_message_generator.dart';
import 'package:collection/collection.dart';

// 🎯 Import your Master Model
import 'package:nutricare_connect/core/utils/meal_master_name.dart';

class LocalReminderService {

  Future<void> reScheduleAllReminders({
    required ClientModel client,
    required ClientDietPlanModel? activePlan,
    required List<ClientLogModel> dailyLogs,
  }) async {
    // 1. WIPE THE SLATE
    await flutterLocalNotificationsPlugin.cancelAll();

    final ClientReminderConfig? config = client.reminderConfig;
    final ClientLogModel? dailyLog = dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    if (config == null || !config.isActive) {
      print("Reminders are globally disabled.");
      return;
    }

    // 2. SCHEDULE MEAL REMINDERS (Dynamic based on Plan)
    if (activePlan != null) {
      await _scheduleMealReminders(activePlan, dailyLogs, config);
    }

    // 3. SCHEDULE FIXED REMINDERS
    _scheduleTimeBasedReminder("Medicine", config.medicineReminder, config, 'medicine');
    _scheduleTimeBasedReminder("End of Day Log", config.dietRoutineReminder, config, 'log');

    // 4. SCHEDULE GOAL-BASED REMINDERS
    _scheduleGoalReminder(
        "Hydration",
        config.hydrationReminder,
        dailyLog?.hydrationLiters ?? 0.0,
        activePlan?.dailyWaterGoal ?? 3.0,
        config,
        'hydration'
    );
    _scheduleGoalReminder(
        "Movement",
        config.stepReminder,
        dailyLog?.stepCount?.toDouble() ?? 0,
        activePlan?.dailyStepGoal.toDouble() ?? 8000.0,
        config,
        'steps'
    );
  }

  // 🎯 NEW: Smart Meal Scheduler
  Future<void> _scheduleMealReminders(ClientDietPlanModel plan, List<ClientLogModel> logs, ClientReminderConfig config) async {
    try {
      // A. Fetch Master Time Configs (1 DB Hit - Cached by Firestore usually)
      final snapshot = await FirebaseFirestore.instance.collection('masterMealNames').get();
      final masterMeals = snapshot.docs.map((d) => MasterMealName.fromFirestore(d)).toList();

      // B. Determine Today's Meals (Assuming simple daily rotation or Day 1)
      if (plan.days.isEmpty) return;
      // Logic: Use Day 1 for now, or map weekday index if your plan supports it
      final todayMeals = plan.days.first.meals;

      // C. Loop & Schedule
      for (var meal in todayMeals) {
        // 1. Check if already logged
        final isLogged = logs.any((l) => l.mealName == meal.mealName && l.logStatus != LogStatus.skipped);
        if (isLogged) continue; // Skip if done

        // 2. Find Time Config
        final timeConfig = masterMeals.firstWhereOrNull((m) => m.id == meal.mealNameId || m.enName == meal.mealName);

        // 3. Schedule at END TIME (Reminder to log)
        if (timeConfig != null && timeConfig.endTime != null) {
          final parts = timeConfig.endTime!.split(':');
          final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

          // Generate friendly message
          final voiceMsg = "Hi, have you had your ${meal.mealName}? Don't forget to log it.";

          await _scheduleNotification(
            id: meal.mealName.hashCode,
            title: "Log ${meal.mealName}",
            body: "Reminder: Track your meal.",
            scheduledDate: _getTodayDateAt(time), // Schedule for TODAY
            config: config,
            voiceMessage: voiceMsg,
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

  void _scheduleGoalReminder(
      String title,
      GoalReminderSettings settings,
      double current,
      double goal,
      ClientReminderConfig config,
      String type
      ) {
    if (!settings.isActive || current >= goal) return;

    final message = WellnessMessageGenerator.getMessage(type: type, languageCode: config.languageCode);

    // Schedule for 2 hours from now (Nudge)
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

  // --- CORE SCHEDULER ---
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required ClientReminderConfig config,
    required String voiceMessage,
  }) async {

    final now = tz.TZDateTime.now(tz.local);

    // 🎯 CRITICAL: Don't schedule in the past for today
    if (scheduledDate.isBefore(now)) {
      // print("Skipping $title - Time Passed");
      return;
    }

    final Map<String, dynamic> payloadMap = {
      'isVoiceActive': config.isVoiceActive,
      'textToSpeak': voiceMessage,
      'languageCode': config.languageCode,
      'voiceProfile': config.voiceProfile,
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
    print("🔔 Scheduled '$title' for $scheduledDate");
  }

  // Helper: Get Date for Today at specific time
  tz.TZDateTime _getTodayDateAt(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
  }

  // Helper: Get Next Valid Time (Today or Tomorrow)
  tz.TZDateTime _getNextValidTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}