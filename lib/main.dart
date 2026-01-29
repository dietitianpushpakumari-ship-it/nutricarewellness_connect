import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nutricare_connect/core/localization/language_config.dart';
import 'package:nutricare_connect/core/language_provider.dart';
import 'package:nutricare_connect/core/utils/client_model.dart'; // Import ClientModel

import 'package:nutricare_connect/core/utils/splash_screen.dart';
import 'package:nutricare_connect/core/utils/sync_manager.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/core/services/tts_service.dart';
import 'package:nutricare_connect/firebase_options.dart';
import 'package:nutricare_connect/features/auth/client_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nutricare_connect/core/services/local_reminder_service.dart';
import 'package:nutricare_connect/features/dashboard/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/app_theme.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/client_auth_screen.dart';


// ... (Keep Providers & Global Instances) ...
final clientProfileFutureProvider = FutureProvider<ClientModel?>((ref) async {
  final clientId = ref.watch(authNotifierProvider.select((state) => state.clientId));
  if (clientId == null) return null;
  final clientService = ref.watch(clientServiceProvider);
  return clientService.getClientById(clientId);
});

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final LocalReminderService localReminderService = LocalReminderService();
final TextToSpeechService ttsService = TextToSpeechService();

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  // Handle notification tap
}

@pragma('vm:entry-point')
Future<void> onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) async {
  // Handle iOS foreground notification
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Timezone Init
  tz.initializeTimeZones();

  // 🎯 CRITICAL FIX: Robust Initialization with Try-Catch
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      debugPrint("Firebase already initialized. Skipping.");
    }
  } catch (e) {
    debugPrint("⚠️ Firebase Init Warning (Safe to ignore on Hot Restart): $e");
  }

  // 2. App Check
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    debugPrint("App Check Init Warning: $e");
  }

  // 3. Sync Manager
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
    final locale = ref.watch(languageProvider);

    return MaterialApp(
      title: 'NutriCare Client',
      theme: AppTheme.lightTheme,
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

      home: Builder(
        builder: (context) {
          if (!_isInitDone || !authState.initialCheckComplete) {
            return const SplashScreen();
          }

          if (authState.clientId != null) {
            final clientProfileAsync = ref.watch(clientProfileFutureProvider);
            return clientProfileAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal))),
              error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
              data: (client) {
                if (client == null) return const ClientAuthScreen();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(globalUserProvider.notifier).setUser(client);
                });
                return ClientDashboardScreen(client: client);
              },
            );
          }

          if (!_hasSeenOnboarding) return const OnboardingScreen();
          return const ClientAuthScreen();
        },
      ),
    );
  }
}