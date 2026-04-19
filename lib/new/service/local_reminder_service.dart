import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/models/clinical_model.dart';
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/core/utils/wellness_message_generator.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:timezone/timezone.dart' as tz;

class LocalReminderService {
  // 🎯 FIX: Define the plugin instance directly inside the service
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();



  Future<void> scheduleMedicationReminders(List<PrescribedMedication> meds) async {
    for (var med in meds) {
      final int notificationId = med.medicineName.hashCode;

      if (med.isReminderEnabled && med.reminderTime != null) {
        final timeOfDay = _parseTime(med.reminderTime!);
        if (timeOfDay == null) continue;

        await _scheduleNotification(
          id: notificationId,
          title: "Medication Time",
          body: "Time to take ${med.medicineName} (${med.frequency})",
          scheduledDate: _getTodayDateAt(timeOfDay),
          config: null,
          voiceMessage: "It's time for your ${med.medicineName}",
        );
      } else {
        // 🎯 Use the internal instance
        await _notificationsPlugin.cancel(notificationId);
      }
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final cleanStr = timeStr.trim().toUpperCase();
      final bool isPM = cleanStr.contains("PM");
      final bool isAM = cleanStr.contains("AM");

      final timePart = cleanStr.replaceAll("AM", "").replaceAll("PM", "").trim();
      final parts = timePart.split(":");

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      debugPrint("Reminder parse error for $timeStr: $e");
      return null;
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



  Future<void> reScheduleAllReminders({
    required ClientModel client,
    required FlatClientDietPlanModel? activePlan,
    required ClientLogModel? dailyRecord,
  }) async {
    await _notificationsPlugin.cancelAll();

    final ClientReminderConfig? config = client.reminderConfig;
    if (config == null || !config.isActive) return;

    if (activePlan != null) {
      await _scheduleMealReminders(activePlan, dailyRecord, config);
    }

    if (config.medicineReminder.isActive) {
      _scheduleTimeBasedReminder("Medicine", config.medicineReminder, config, 'medicine');
    }

    if (config.dietRoutineReminder.isActive) {
      _scheduleTimeBasedReminder("End of Day Log", config.dietRoutineReminder, config, 'log');
    }

    if (config.hydrationReminder.isActive) {
      _scheduleGoalReminder(
          "Hydration",
          config.hydrationReminder,
          dailyRecord?.hydrationLiters ?? 0.0,
          activePlan?.dailyWaterGoal ?? 3.0,
          config,
          'hydration');
    }

    if (config.stepReminder.isActive) {
      _scheduleGoalReminder(
          "Movement",
          config.stepReminder,
          (dailyRecord?.stepCount ?? 0).toDouble(),
          (activePlan?.dailyStepGoal ?? 8000).toDouble(),
          config,
          'steps');
    }
  }

  // 🎯 ATOMIC FIX: Checks the nested mealLogs map for completion
// 🎯 ATOMIC FIX: Updated for the Flat model to prevent duplicate notifications
  Future<void> _scheduleMealReminders(FlatClientDietPlanModel plan, ClientLogModel? record, ClientReminderConfig config) async {
    if (plan.allItems.isEmpty) return;

    // 1. Extract unique meals to avoid scheduling multiple notifications for the same meal time
    final Map<String, dynamic> uniqueMeals = {};
    for (var item in plan.allItems) {
      // If we haven't seen this meal yet, and it has a time, save it
      if (!uniqueMeals.containsKey(item.mealName) && item.mealTime != null && item.mealTime!.isNotEmpty) {
        uniqueMeals[item.mealName] = item;
      }
    }

    // 2. Schedule a reminder for each unique meal
    for (var meal in uniqueMeals.values) {
      // 🎯 Direct lookup in the atomic map
      final mealLog = record?.mealLogs[meal.mealName];
      final isLogged = mealLog != null && mealLog.status != LogStatus.skipped;

      if (isLogged) continue;

      final timeOfDay = _parseTime(meal.mealTime!);
      if (timeOfDay == null) continue;

      await _scheduleNotification(
        id: meal.mealName.hashCode,
        title: "Log ${meal.mealName}",
        body: "It's time for your ${meal.mealName}. Don't forget to track it!",
        scheduledDate: _getTodayDateAt(timeOfDay),
        config: config,
        voiceMessage: "Hi, have you had your ${meal.mealName}? Please log your meal.",
      );
    }
  }
  // ... (scheduleMedicationReminders, _parseTime, _scheduleTimeBasedReminder remain unchanged) ...

  void _scheduleGoalReminder(String title, GoalReminderSettings settings, double current, double goal, ClientReminderConfig config, String type) {
    // If goal is already met, don't schedule annoying reminders
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
    ClientReminderConfig? config,
    required String voiceMessage,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var finalDate = scheduledDate;
    if (finalDate.isBefore(now)) {
      finalDate = finalDate.add(const Duration(days: 1));
    }

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
      showWhen: true,
      // 🎯 Custom sound for clinical trust
      sound: RawResourceAndroidNotificationSound('default_sound'),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      finalDate,
      const NotificationDetails(android: androidDetails),
      payload: jsonEncode(payloadMap),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  // 🎯 Helper: Converts TimeOfDay to a TZDateTime for Today
  tz.TZDateTime _getTodayDateAt(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
  }

  // 🎯 Helper: Ensures the scheduled time is in the future (rolls to tomorrow if needed)
  tz.TZDateTime _getNextValidTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}