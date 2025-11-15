import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/main.dart'; // Import the global plugin

import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class LocalReminderService {

  /// The main "engine" method.
  Future<void> reScheduleAllReminders({
    required ClientModel client,
    required ClientDietPlanModel? activePlan,
    required List<ClientLogModel> dailyLogs,
  }) async {

    // 1. WIPE THE SLATE: Cancel all pending notifications
    await flutterLocalNotificationsPlugin.cancelAll();

    final ClientReminderConfig? config = client.reminderConfig;
    final ClientLogModel? dailyLog = dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    // 3. MASTER SWITCH (FR-DAT-02)
    if (!config!.isActive) {
      print("Reminders are globally disabled.");
      return;
    }

    // 4. SCHEDULE TIME-BASED (Meals & Medicine)
    _scheduleTimeBasedReminder("Medicine", config.medicineReminder, config);
    // TODO: Add logic to loop through `activePlan.days[...].meals` for meal times
    _scheduleTimeBasedReminder("End of Day Log", config.dietRoutineReminder, config);

    // 5. SCHEDULE GOAL-BASED (Hydration & Steps)
    _scheduleGoalReminder(
      "Hydration",
      config.hydrationReminder,
      dailyLog?.hydrationLiters ?? 0.0,
      3.0, // 🎯 TODO: Get this goal from the plan
      config,
    );
    _scheduleGoalReminder(
      "Movement",
      config.stepReminder,
      dailyLog?.stepCount?.toDouble() ?? 0,
      activePlan?.dailyStepGoal.toDouble() ?? 8000.0, // 🎯 Get goal from plan
      config,
    );
  }

  /// Schedules mandatory, time-based reminders (FR-TIME)
  void _scheduleTimeBasedReminder(String title, TimeReminderSettings settings, ClientReminderConfig config) {
    if (!settings.isActive) return;


    final testTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 1)));

    _scheduleNotification(
      id: title.hashCode, // Unique ID
      title: 'TEST: Time for your $title!',
      body: 'This is your scheduled reminder.',
      time: testTime, // 🎯 Use test time
      // time: settings.time, // Production code
      config: config,
    );

  }

  /// Schedules goal-based, "smart" reminders (FR-GOAL)
  void _scheduleGoalReminder(String title, GoalReminderSettings settings, double current, double goal, ClientReminderConfig config) {
    if (!settings.isActive) return;

    // 🎯 FR-GOAL-02: GOAL AWARENESS
    if (current >= goal) {
      print("$title goal is already met. No reminders scheduled.");
      return; // Goal is met, do not schedule
    }

    final String body = "$title: You've logged $current / $goal. Keep it up!";

    // --- Schedule Tiers (FR-GOAL-03, 04, 05) ---
    // Tier 1: Soft
    _scheduleNotification(
      id: title.hashCode + 1, // Unique ID for Tier 1
      title: '$title Nudge',
      body: body,
      time: const TimeOfDay(hour: 12, minute: 0), // 12:00 PM
      config: config,
    );

    // Tier 2: Standard
    if (settings.escalationLevel == ReminderEscalation.standard || settings.escalationLevel == ReminderEscalation.aggressive) {
      _scheduleNotification(
        id: title.hashCode + 2,
        title: '$title Reminder',
        body: body,
        time: const TimeOfDay(hour: 16, minute: 0), // 4:00 PM
        config: config,
      );
    }

    // Tier 3: Aggressive
    if (settings.escalationLevel == ReminderEscalation.aggressive) {
      _scheduleNotification(
        id: title.hashCode + 3,
        title: 'Final $title Alert!',
        body: body,
        time: const TimeOfDay(hour: 19, minute: 0), // 7:00 PM
        config: config,
      );
    }
  }

  /// The core function that schedules a single local notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    required ClientReminderConfig config,
  }) async {

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // 3. If that time has already passed today, schedule it for tomorrow
    if (scheduledDate.isBefore(now)) {
      // Don't schedule for tomorrow, just skip
      print("Skipping '$title' reminder for today, time has passed.");
      return;
    }
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wellness_channel_id', // ⬅️ This ID *must* match the one in main.dart
      'Wellness Reminders',
      channelDescription: 'Notifications for hydration, steps, and meals',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('default_sound'), // ⬅️ The file from res/raw
      playSound: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(presentSound: true, presentAlert: true, presentBadge: true);
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );


    // 🎯 Build a proper JSON payload
    final Map<String, dynamic> payloadMap = {
      'isVoiceActive': config.isVoiceActive,
      'voiceProfile': config.voiceProfile,
      'languageCode': config.languageCode,
      'textToSpeak': '$title. $body', // The full text to be spoken
    };
    final String payload = jsonEncode(payloadMap);

    // 6. Schedule the notification
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        platformDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("Scheduled '$title' for $scheduledDate");
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }
}