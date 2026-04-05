import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🎯 Added for FCM
import 'package:easy_localization/easy_localization.dart';
import 'package:nutricare_connect/core/utils/splash_screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/core/services/tts_service.dart';
// 🎯 Ensure this path matches where you saved NotificationService

import 'package:nutricare_connect/firebase_options.dart';
import 'package:nutricare_connect/new/core/theme_provider.dart';
import 'package:nutricare_connect/new/login/universal_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/new/service/local_reminder_service.dart';
import 'package:nutricare_connect/new/dashboard/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'new/login/onboarding_screen.dart';
import 'new/login/client_auth_screen.dart';
import 'new/service/notification_service.dart';

// --- 🎯 GLOBAL INSTANCES ---
final LocalReminderService localReminderService = LocalReminderService();
final TextToSpeechService ttsService = TextToSpeechService();

// 🚀 THE GLOBAL NAVIGATOR KEY (Allows routing from background notifications without context)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🚨 FCM BACKGROUND HANDLER (Must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized before handling background tasks
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Background message received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Localization Engine
  await EasyLocalization.ensureInitialized();

  tz.initializeTimeZones();

  // 🎯 FIXED FIREBASE INIT: Wait for this to finish before setting up FCM
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase Init Warning: $e");
  }

  // 🚀 INITIALIZE NOTIFICATION ROUTING
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  NotificationService().setupNotificationRouting();

  await SyncManager().init();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('or')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        child: const NutriCareClientApp(),
      ),
    ),
  );
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
    final prefs = await SharedPreferences.getInstance();
    final onboardingStatus = prefs.getBool('has_seen_onboarding') ?? false;

    // Splach Screen Timer
    await Future.delayed(const Duration(seconds: 5));

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
    final currentTheme = ref.watch(themeProvider);

    return MaterialApp(
      // 🚀 INJECT THE GLOBAL KEY HERE
      navigatorKey: navigatorKey,

      title: 'NutriCare Wellness',
      theme: currentTheme,
      debugShowCheckedModeBanner: false,

      // Localization Wiring
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      home: Builder(
        builder: (context) {
          // 1. Still loading / initializing? Show Splash Screen.
          if (!_isInitDone || !authState.initialCheckComplete) {
            return const SplashScreen();
          }

          // 2. Logged in securely? Go to Dashboard.
          if (authState.currentUser != null && authState.clientProfile != null) {
            return ClientDashboardScreen(client: authState.clientProfile!);
          }

          // 3. 🎯 FIXED LOGIC: Have NOT seen onboarding? Show Onboarding.
          if (!_hasSeenOnboarding) {
            return const OnboardingScreen();
          }

          // 4. Fallback: Show Login/Auth Screen.
          return const ClientAuthScreen();
        },
      ),
    );
  }
}