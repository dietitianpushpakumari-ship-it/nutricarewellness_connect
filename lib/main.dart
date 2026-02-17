import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nutricare_connect/core/localization/language_config.dart';
import 'package:nutricare_connect/core/language_provider.dart';
import 'package:nutricare_connect/core/utils/splash_screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/core/services/tts_service.dart';
import 'package:nutricare_connect/firebase_options.dart';
import 'package:nutricare_connect/new/core/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/core/services/local_reminder_service.dart';
import 'package:nutricare_connect/new/dashboard/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'core/localization/app_localizations.dart';
 // FIX 1: Fixed the import path (removed 'new/')
import 'features/auth/onboarding_screen.dart';
import 'features/auth/client_auth_screen.dart';
import 'new/core/app_theme.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final LocalReminderService localReminderService = LocalReminderService();
final TextToSpeechService ttsService = TextToSpeechService();

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {}

@pragma('vm:entry-point')
Future<void> onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase Init Warning: $e");
  }

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
    final prefs = await SharedPreferences.getInstance();
    final onboardingStatus = prefs.getBool('has_seen_onboarding') ?? false;
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = onboardingStatus;
        _isInitDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 SINGLE SOURCE OF TRUTH (No more FutureProvider conflicts)
    final authState = ref.watch(authNotifierProvider);
    final locale = ref.watch(languageProvider);
    final currentTheme = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Nutricare Wellness', // Updated to match your brand name
      theme: currentTheme, // FIX 2: Applied the new premium theme!
      // darkTheme: AppTheme.sapphireMidnight, // Optional: Add this if you want dark mode support
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: supportedLanguageCodes.map((code) => Locale(code)).toList(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      // Inside main.dart Builder...
      home: Builder(
        builder: (context) {
          if (!_isInitDone || !authState.initialCheckComplete) {
            return const SplashScreen();
          }

          // If logged in AND we have a profile, Dashboard is the home
          if (authState.currentUser != null && authState.clientProfile != null) {
            // Note: We still keep this here so if the app REBOOTS while logged in,
            // it starts directly at the Dashboard.
            return ClientDashboardScreen(client: authState.clientProfile!);
          }

          // Default to Login (unless onboarding is needed)
          if (!_hasSeenOnboarding) return const OnboardingScreen();
          return const ClientAuthScreen();
        },
      ),
    );
  }
}