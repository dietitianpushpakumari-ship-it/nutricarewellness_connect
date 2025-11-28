import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nutricare_connect/core/utils/splash_screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/core/utils/tts_service.dart';
import 'package:nutricare_connect/firebase_options.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/services/local_reminder_service.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';
import 'core/app_theme.dart';
import 'core/utils/onboarding_screen.dart';
import 'features/dietplan/PRESENTATION/screens/client_auth_screen.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

// --- Providers ---
final clientProfileFutureProvider = FutureProvider<ClientModel?>((ref) async {
  final clientId = ref.watch(authNotifierProvider.select((state) => state.clientId));
  if (clientId == null) return null;
  final clientService = ref.watch(clientServiceProvider);
  return clientService.getClientById(clientId);
});

// --- Global Instances ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final LocalReminderService localReminderService = LocalReminderService();
final TextToSpeechService ttsService = TextToSpeechService();

// --- Notification Handlers ---
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  if (response.payload != null && response.payload!.isNotEmpty) {
    _handleNotificationPayload(response.payload!);
  }
}

@pragma('vm:entry-point')
Future<void> onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) async {
  if (payload != null && payload.isNotEmpty) {
    _handleNotificationPayload(payload);
  }
}

void _handleNotificationPayload(String payload) {
  try {
    final Map<String, dynamic> data = jsonDecode(payload);
    if (data['isVoiceActive'] == true) {
      ttsService.speak(
          text: data['textToSpeak'] ?? 'You have a new reminder.',
          languageCode: data['languageCode'] ?? 'en-US'
      );
    }
  } catch (e) {
    print("Error handling payload: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Timezone
  tz.initializeTimeZones();
  try {
    final String localTimezone = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));
  } catch (e) {
    print("Timezone Error: $e");
  }

  // Init Notifications
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'wellness_channel_id',
    'Wellness Reminders',
    description: 'Notifications for hydration, steps, and meals',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('default_sound'),
  );

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification: onDidReceiveLocalNotification,
  );

  await flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS),
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Init Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug);

  // Init Sync
  await SyncManager().init();

  runApp(const ProviderScope(child: NutriCareClientApp()));
}

class NutriCareClientApp extends ConsumerStatefulWidget {
  const NutriCareClientApp({super.key});

  @override
  ConsumerState<NutriCareClientApp> createState() => _NutriCareClientAppState();
}

class _NutriCareClientAppState extends ConsumerState<NutriCareClientApp> {
  bool _isInitDone = false;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load Local Preferences
    final prefs = await SharedPreferences.getInstance();
    final onboardingStatus = prefs.getBool('has_seen_onboarding') ?? false;

    // Minimum Splash Time
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _hasSeenOnboarding = onboardingStatus;
        _isInitDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // 1. Global Splash (Only on fresh app launch)
    if (!_isInitDone || !authState.initialCheckComplete) {
      return MaterialApp(
        title: 'NutriCare Client',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    // 2. Authenticated User Logic
    if (authState.clientId != null) {
      final clientProfileAsync = ref.watch(clientProfileFutureProvider);

      return clientProfileAsync.when(
        loading: () => MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal))),
            debugShowCheckedModeBanner: false
        ),
        error: (e, s) => MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
                body: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Failed to load profile.'),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: () => ref.refresh(clientProfileFutureProvider), child: const Text("Retry"))
                  ],
                ))),
            debugShowCheckedModeBanner: false
        ),
        data: (client) {
          if (client == null) {
            return MaterialApp(
              title: 'NutriCare Client',
              theme: AppTheme.lightTheme,
              home: const ClientAuthScreen(),
              debugShowCheckedModeBanner: false,
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(globalUserProvider.notifier).setUser(client);
          });

          return MaterialApp(
            title: 'NutriCare Client',
            theme: AppTheme.lightTheme,
            home: ClientDashboardScreen(client: client),
            debugShowCheckedModeBanner: false,
          );
        },
      );
    }

    // 3. New User -> Onboarding
    if (!_hasSeenOnboarding) {
      return MaterialApp(
        title: 'NutriCare Client',
        theme: AppTheme.lightTheme,
        home: const OnboardingScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    // 4. Returning User -> Login
    return MaterialApp(
      title: 'NutriCare Client',
      theme: AppTheme.lightTheme,
      home: const ClientAuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}