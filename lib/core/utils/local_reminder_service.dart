import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/main.dart';
// 🎯 IMPORT THE GENERATOR
import 'package:nutricare_connect/core/utils/wellness_message_generator.dart';
import 'package:collection/collection.dart';

class LocalReminderService {

  Future<void> reScheduleAllReminders({
    required ClientModel client,
    required ClientDietPlanModel? activePlan,
    required List<ClientLogModel> dailyLogs,
  }) async {
    await flutterLocalNotificationsPlugin.cancelAll();

    final ClientReminderConfig? config = client.reminderConfig;
    final ClientLogModel? dailyLog = dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

    if (config == null || !config.isActive) return;

    // Schedule Time-Based
    _scheduleTimeBasedReminder("Medicine", config.medicineReminder, config, 'medicine');
    _scheduleTimeBasedReminder("End of Day Log", config.dietRoutineReminder, config, 'log');

    // Schedule Goal-Based
    _scheduleGoalReminder(
        "Hydration",
        config.hydrationReminder,
        dailyLog?.hydrationLiters ?? 0.0,
        3.0,
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

  void _scheduleTimeBasedReminder(String title, TimeReminderSettings settings, ClientReminderConfig config, String type) {
    if (!settings.isActive) return;

    // 🎯 Generate Empathetic Message
    final message = WellnessMessageGenerator.getMessage(type: type, languageCode: config.languageCode);

    final scheduledTime = _getNextValidTime(settings.time);

    _scheduleNotification(
      id: title.hashCode,
      title: title,
      body: message, // Show friendly text in notification too
      scheduledDate: scheduledTime,
      config: config,
      voiceMessage: message, // Text to speak
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

    // 🎯 Generate Empathetic Message
    final message = WellnessMessageGenerator.getMessage(type: type, languageCode: config.languageCode);

    // Schedule (Example: 1 Tier for brevity, real app uses 3 tiers logic)
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
    required ClientReminderConfig config,
    required String voiceMessage,
  }) async {

    // 🎯 Construct Smart Payload
    final Map<String, dynamic> payloadMap = {
      'isVoiceActive': config.isVoiceActive,
      'textToSpeak': voiceMessage, // The empathetic message
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
  }

  // Helper for time calculation
  tz.TZDateTime _getNextValidTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}