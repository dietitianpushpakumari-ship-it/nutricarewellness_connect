// lib/services/local_notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_vitals_model.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
 // Import the model
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart'; // Import the log model
import 'client_service.dart'; // For fetching data (or use a Repository pattern)


// 🎯 Provider for the Service (Riverpod Pattern)
final localNotificationServiceProvider = Provider((ref) => LocalNotificationService(ref));

// Assume a dummy TTS Service for demonstration
class TtsService {
  Future<String> generateAudioUrl({required String text, required String voiceProfile, required String languageCode}) async {
    // In a real app, this calls a cloud function (e.g., Google Cloud TTS)
    // to generate the MP3/AAC file and returns its public URL.
    print('TTS: Generating $text with voice $voiceProfile ($languageCode)');
    return 'https://tts-audio.com/${voiceProfile}_$languageCode.mp3';
  }
}
final ttsServiceProvider = Provider((ref) => TtsService());

// Assume a dummy Data Fetching Service
class DataRepository {
  // Replace this with actual calls to fetch client data and logs
  Future<ClientVitalsModel?> getClientVitals(String clientId) async {
    // Dummy Data for testing logic
    return ClientVitalsModel(
      clientId: clientId,
      // Hydration Reminder is active, voice is active, standard escalation
      hydrationTrackerReminder: const ReminderConfig(
        id: 'hydration', title: 'Water Intake', time: '10:00',
        isActive: true, isVoiceActive: true, escalationLevel: 2,
      ),
      // Medicine Reminder is active, soft escalation
      medicineReminders: [
        const ReminderConfig(
          id: 'med_morning', title: 'Morning Pills', time: '08:00',
          isActive: true, isVoiceActive: false, escalationLevel: 1, // Voice OFF
        ),
      ],
    );
  }

  Future<ClientLogModel?> getTodaysClientLog(String clientId) async {
    // Dummy Log Data: Hydration GOAL NOT MET (1.0L out of 2.0L goal)
    return ClientLogModel(
      clientId: clientId, dietPlanId: 'dp1', date: DateTime.now(), mealName: 'dummy', actualFoodEaten: ['none'],
      hydrationLiters: 1.0, // < 2.0L goal (assumed client goal is 2.0L)
      stepCount: 15000,     // > 10000 goal (assumed client goal is 10000)
    );
  }

  // Get the client's goal settings (assumed to be stored elsewhere)
  Future<Map<String, int>> getClientGoals(String clientId) async {
    return {'hydrationGoalLiters': 2, 'stepsGoal': 10000};
  }
}
final dataRepositoryProvider = Provider((ref) => DataRepository());


class LocalNotificationService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  LocalNotificationService(this._ref);

  /// 1. Initializes the notification settings and timezone.
  Future<void> initialize() async {
    tz.initializeTimeZones();
    // Use the appropriate timezone for your region or fetch from client settings
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Add iOS settings if needed
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }


  /// 2. MASTER METHOD: Schedules all active and unfulfilled reminders for the day.
  Future<void> scheduleAllReminders(String clientId) async {
    // 1. Fetch all necessary data
    final vitals = await _ref.read(dataRepositoryProvider).getClientVitals(clientId);
    final todayLog = await _ref.read(dataRepositoryProvider).getTodaysClientLog(clientId);
    final goals = await _ref.read(dataRepositoryProvider).getClientGoals(clientId);

    if (vitals == null) return;

    // Clear any previously scheduled reminders to prevent duplicates
    await flutterLocalNotificationsPlugin.cancelAll();

    // --- Schedule Time-Based Reminders (Medicine/Diet) ---
    vitals.medicineReminders.forEach((config) => _scheduleTimeBasedReminder(config));
    vitals.dietRoutineReminders.forEach((config) => _scheduleTimeBasedReminder(config));

    // --- Schedule Goal-Based Reminders (Steps/Hydration) ---
    _scheduleGoalBasedReminder(
      vitals.hydrationTrackerReminder,
      todayLog?.hydrationLiters ?? 0,
      goals['hydrationGoalLiters']?.toDouble() ?? 2,
      'Drink water', // Default message
      'hydration',
    );

    _scheduleGoalBasedReminder(
      vitals.stepTrackerReminder,
      (todayLog?.stepCount ?? 0).toDouble(), // Convert int steps to double for comparison
      (goals['stepsGoal'] ?? 10000).toDouble(),
      'Take a walk', // Default message
      'steps',
    );
  }

  /// Helper to convert "HH:MM" string to a TZDateTime for today.
  tz.TZDateTime _getNextValidTime(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If the scheduled time is in the past today, schedule it for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// 3. Logic for Time-Based Reminders (Medicine/Diet)
  Future<void> _scheduleTimeBasedReminder(ReminderConfig config) async {
    // 1. Check Master ON/OFF Switch
    if (!config.isActive) return;

    final time = _getNextValidTime(config.time);
    final notificationDetails = await _buildNotificationDetails(config);

    // The notification ID must be unique
    final notificationId = config.id.hashCode + time.millisecondsSinceEpoch;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      config.title,
      'Time for your ${config.title} at ${config.time}.',
      time,
      notificationDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
    );
    print('Scheduled Time-Based Reminder: ${config.title} at ${config.time}');
  }


  /// 4. Logic for Goal-Based Reminders (Hydration/Steps)
  Future<void> _scheduleGoalBasedReminder(
      ReminderConfig? config,
      double currentProgress,
      double goal,
      String defaultMessage,
      String type,
      ) async {
    if (config == null || !config.isActive) return;

    // 1. Check Goal Completion (Empathetic Logic)
    if (currentProgress >= goal) {
      print('$type Goal already met ($currentProgress / $goal). Reminder skipped.');
      return; // 🎯 CRITICAL: Reminder is SKIPPED if goal is met
    }

    // 2. Schedule the First Tier (Soft Prompt)
    final notificationDetails = await _buildNotificationDetails(config);
    final firstTierTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5)); // Schedule 5 mins from now

    await flutterLocalNotificationsPlugin.zonedSchedule(
      config.id.hashCode,
      'Remember to ${config.title}',
      'You are at $currentProgress of your $goal goal. A gentle nudge: $defaultMessage.',
      firstTierTime,
      notificationDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
    print('Scheduled Tier 1 $type Reminder (Soft) at $firstTierTime');


    // 3. Schedule Tiers 2 and 3 based on Escalation Level
    if (config.escalationLevel >= 2) {
      final secondTierTime = firstTierTime.add(const Duration(minutes: 60)); // 1 hour later

      // Tier 2: Includes the standard system notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        config.id.hashCode + 1,
        'Still need to ${config.title}!',
        'Let\'s hit that goal. You only need ${goal - currentProgress} more.',
        secondTierTime,
        notificationDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
      );
      print('Scheduled Tier 2 $type Reminder (Standard) at $secondTierTime');
    }

    if (config.escalationLevel >= 3) {
      final thirdTierTime = firstTierTime.add(const Duration(minutes: 180)); // 3 hours later

      // Tier 3: Urgent, with repeated voice if active
      await flutterLocalNotificationsPlugin.zonedSchedule(
        config.id.hashCode + 2,
        '🚨 Action Required: ${config.title}',
        'Your coach suggests getting this done now. It\'s important for your health!',
        thirdTierTime,
        notificationDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
      );
      print('Scheduled Tier 3 $type Reminder (Max) at $thirdTierTime');
    }
  }


  /// 5. Helper to construct notification details, respecting the Voice ON/OFF switch.
  Future<NotificationDetails> _buildNotificationDetails(ReminderConfig config) async {
    String? customSoundPath;

    // 1. Check Voice ON/OFF Switch
    if (config.isVoiceActive) {
      // 2. Generate custom voice audio based on profile and language
      final ttsService = _ref.read(ttsServiceProvider);
      final message = 'Time for your ${config.title}. ${config.voiceProfile} encourages you!';
      final audioUrl = await ttsService.generateAudioUrl(
        text: message,
        voiceProfile: config.voiceProfile,
        languageCode: config.languageCode,
      );

      // NOTE: For flutter_local_notifications, you usually need a *local* audio file
      // or a custom channel to play a remote URL. For this conceptual code, we assume
      // the audio is downloaded and available as a local path/resource, or a dedicated
      // notification channel handles remote playback.
      // For simplicity, we use the URL placeholder:
      customSoundPath = audioUrl;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'nutricare_reminders', // Channel ID
      'Health Reminders', // Channel Name
      channelDescription: 'Time-based and goal-based health prompts.',
      importance: Importance.max,
      priority: Priority.high,
      // For playing custom sound, you would set: sound: customSoundPath
      // (and ensure the sound file is a local resource accessible by Android)
    );

    return const NotificationDetails(android: androidPlatformChannelSpecifics);
  }
}