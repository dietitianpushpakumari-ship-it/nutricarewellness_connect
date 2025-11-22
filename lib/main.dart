import 'dart:convert'; // For jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// 🎯 1. Import all the services and plugin instances
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/tts_service.dart';
import 'package:nutricare_connect/firebase_options.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/services/local_reminder_service.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart'; // Import your main screen
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';

import 'core/app_theme.dart';
import 'features/dietplan/PRESENTATION/screens/client_auth_screen.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';


final clientProfileFutureProvider = FutureProvider<ClientModel?>((ref) async {
  // Read the authenticated user's ID from the AuthProvider state
  final clientId = ref.watch(authNotifierProvider.select((state) => state.clientId));
  if (clientId == null) return null;

  // Use the service to fetch the profile
  final clientService = ref.watch(clientServiceProvider);

  // NOTE: Assuming getClientById is now implemented in ClientService
  return clientService.getClientById(clientId);
});


// ... (omitted other imports for your app screens) ...

// 🎯 2. Create global instances for the services
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
final LocalReminderService localReminderService = LocalReminderService();
final TextToSpeechService ttsService = TextToSpeechService();

// 🎯 3. Notification Tapped Handler (when app is background/terminated)
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  if (response.payload != null && response.payload!.isNotEmpty) {
    print("Notification Tapped. Payload: ${response.payload}");
    _handleNotificationPayload(response.payload!);
  }
}

// 🎯 4. Notification Received (Foreground) Handler (for iOS)
@pragma('vm:entry-point')
Future<void> onDidReceiveLocalNotification(
    int id, String? title, String? body, String? payload) async {
  if (payload != null && payload.isNotEmpty) {
    print("Notification Received in Foreground. Payload: $payload");
    _handleNotificationPayload(payload);
  }
}

// 🎯 5. The logic that reads the payload and speaks
void _handleNotificationPayload(String payload) {
  try {
    final Map<String, dynamic> data = jsonDecode(payload);

    if (data['isVoiceActive'] == true) {
      final String textToSpeak = data['textToSpeak'] ?? 'You have a new reminder.';
      final String languageCode = data['languageCode'] ?? 'en-US';
      final String voiceProfile = data['voiceProfile'] ?? 'default';

      ttsService.speak(textToSpeak, languageCode, voiceProfile);
    }
  } catch (e) {
    print("Error handling notification payload: $e. Payload was: $payload");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 6. Initialize Timezone Database
  tz.initializeTimeZones();
  try {
    final String localTimezone = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));
  } catch (e) {
    print("Could not get local timezone: $e");
  }

  // 7. 🎯 CRITICAL FIX: Define the Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'wellness_channel_id', // This ID *must* match your service
    'Wellness Reminders',
    description: 'Notifications for hydration, steps, and meals',
    importance: Importance.max,
    //priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('default_sound'), // ⬅️ The file from res/raw
  );

  // 8. Initialize Local Notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification: onDidReceiveLocalNotification,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  // 9. 🎯 CRITICAL FIX: Create the channel on Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 10. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  runApp(const ProviderScope(child: NutriCareClientApp()));
}

// ... (Rest of your NutriCareClientApp class) ...


// Inside lib/main.dart

class NutriCareClientApp extends ConsumerWidget {
  const NutriCareClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    if (!authState.initialCheckComplete) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    // 1. Check Authentication
    if (authState.clientId != null) {
      final clientId = authState.clientId!;

      // 🎯 NEW: Use the Global Provider to fetch/cache data
      // We use 'listen' to trigger the fetch if data is missing, but we return a FutureBuilder/Async logic
      // Or simpler: we use the FutureProvider you already had, but update the Global State.

      final clientProfileAsync = ref.watch(clientProfileFutureProvider);

      return clientProfileAsync.when(
        loading: () => const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))),
        error: (e, s) => MaterialApp(home: Scaffold(body: Center(child: Text('Error: $e')))),
        data: (client) {
          if (client == null) {
            return const MaterialApp(home: Scaffold(body: Center(child: Text('Profile missing.'))));
          }

          // 🎯 CRITICAL: Save to Global Memory immediately
          // This allows accessing 'ref.read(globalUserProvider)' anywhere later without await
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(globalUserProvider.notifier).setUser(client);
          });

          return MaterialApp(
            title: 'NutriCare Client',
            theme: AppTheme.lightTheme,
            // Pass client to Dashboard (optional now, but good for legacy)
            home: ClientDashboardScreen(client: client),
            debugShowCheckedModeBanner: false,
          );
        },
      );
    }

    // Default to Auth Screen
    return MaterialApp(
      title: 'NutriCare Client',
      theme: AppTheme.lightTheme,
      home: const ClientAuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}