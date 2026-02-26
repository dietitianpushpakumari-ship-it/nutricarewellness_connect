import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart'; // 🎯 Added for tr() support
import 'package:nutricare_connect/core/utils/splash_screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/core/services/tts_service.dart';
import 'package:nutricare_connect/firebase_options.dart';
import 'package:nutricare_connect/new/core/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/new/service/local_reminder_service.dart';
import 'package:nutricare_connect/new/dashboard/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'new/login/onboarding_screen.dart';
import 'new/login/client_auth_screen.dart';

// Global instances
final LocalReminderService localReminderService = LocalReminderService();
final TextToSpeechService ttsService = TextToSpeechService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🎯 Initialize Localization Engine
  await EasyLocalization.ensureInitialized();

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

  runApp(
    // 1. Riverpod at top
    ProviderScope(
      // 2. Localization wraps the App for global tr() availability
      child: EasyLocalization(
        // 🎯 STEP 2: Configure paths and locales
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('or')],
        path: 'assets/translations', // Ensure folder is exactly this name
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

    // 🎯 FIX 1: Increased to 3 seconds so the beautiful Splash Screen text & animation is visible!
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
      title: 'NutriCare Wellness',
      theme: currentTheme,
      debugShowCheckedModeBanner: false,

      // 🎯 THE LOCALIZATION WIRING (Essential for context.tr() to work)
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

          // 3. 🎯 FIX 2: Have NOT seen onboarding? Show Onboarding.
          if (_hasSeenOnboarding) {
            return const OnboardingScreen();
          }

          // 4. Fallback: Show Login/Auth Screen.
          return const ClientAuthScreen();
        },
      ),
    );
  }
}