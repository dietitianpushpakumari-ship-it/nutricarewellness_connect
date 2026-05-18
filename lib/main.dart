import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🎯 Added for FCM
import 'package:easy_localization/easy_localization.dart';
import 'package:health/health.dart';
import 'package:pure_shift/core/utils/performance_utils.dart';
import 'package:pure_shift/core/utils/sync_manager.dart';
import 'package:pure_shift/core/services/tts_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:pure_shift/firebase_options.dart';
import 'package:pure_shift/new/core/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:pure_shift/new/dashboard/client_dashboard_main_screen.dart';
import 'package:pure_shift/features/auth/auth_provider.dart';
import 'package:workmanager/workmanager.dart';


import 'animated_luxury_splash.dart';
import 'global_keys.dart';
import 'new/chat/client_chat_screen.dart';
import 'new/login/client_auth_screen.dart';
import 'new/service/notification_service.dart';


final TextToSpeechService ttsService = TextToSpeechService();

// ============================================================================
// 1. BACKGROUND & FOREGROUND NOTIFICATION HANDLERS
// ============================================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == "clinicalDataSync") {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }

        final String patientId = inputData?['patientId'] ?? '';
        if (patientId.isEmpty) return true;

        // 🚀 READ YOUR CUSTOM CALCULATION
        final prefs = await SharedPreferences.getInstance();
        int? stepsToday = prefs.getInt('steps_today');

        // Only push if there is data to sync
        if (stepsToday != null && stepsToday > 0) {
          final now = DateTime.now();
          String docId = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

          await FirebaseFirestore.instance
              .collection('clients')
              .doc(patientId)
              .collection('daily_logs')
              .doc(docId)
              .set({
            'stepCount': stepsToday, // Matches what the user sees on HomeScreen
            'lastSyncTime': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          debugPrint("✅ Background Sync: Pushed $stepsToday calculated steps.");
        }
      }
      return true;
    } catch (e) {
      debugPrint("❌ Background Sync Failed: $e");
      return false;
    }
  });
}
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 🚀 THE FIX: You MUST call this before touching Firebase in the background!
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    // 🚨 DO NOT call NotificationService().displayNativeNotification() here!
    // If you try to show a local notification in the background without initializing
    // the plugin first, the isolate crashes and the OS deletes the notification.

    debugPrint("📩 Client Background message processed: ${message.messageId}");
  } catch (e) {
    debugPrint("🚨 Background Crash Prevented: $e");
  }
}
void _showClientInAppNotification(RemoteMessage message) {
  debugPrint("🚨 FCM TRIGGERED: Attempting to show foreground notification...");

  final title = message.notification?.title ?? message.data['title'] ?? "New Message";
  final body = message.notification?.body ?? message.data['body'] ?? "Tap to view";

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (GlobalKeys.snackbarKey.currentState != null) {
      debugPrint("✅ SnackbarKey is valid. Painting SnackBar...");

      GlobalKeys.snackbarKey.currentState!.hideCurrentSnackBar();
      GlobalKeys.snackbarKey.currentState!.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
          backgroundColor: Colors.grey.shade900,
          elevation: 10,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(body, maxLines: 1, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          action: SnackBarAction(
            label: "Reply",
            textColor: Colors.blueAccent,
            onPressed: () {
              final context = GlobalKeys.navigatorKey.currentContext;
              if (context != null) {
                // 🚀 FIXED: Routes directly to the chat screen
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientChatScreen()));
              }
            },
          ),
        ),
      );
    } else {
      debugPrint("❌ SnackbarKey was NULL. Cannot show notification.");
    }
  });
}

// ============================================================================
// 2. MAIN INITIALIZATION
// ============================================================================

void main() async {
  // 1. Keep native splash active while engine starts
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await PerformanceManager.checkDevicePower();
  await EasyLocalization.ensureInitialized();
  tz.initializeTimeZones();

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint("Firebase Init Warning: $e");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🚀 HOOK UP FOREGROUND NOTIFICATIONS
  FirebaseMessaging.onMessage.listen(_showClientInAppNotification);

  await NotificationService().setupNotificationRouting();
  Future.delayed(Duration.zero, () => SyncManager().init());
  PaintingBinding.instance.imageCache.maximumSize = 100;
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

// ============================================================================
// 3. APP ROOT WIDGET
// ============================================================================

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
    // Perform any critical async logic here
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isInitDone = true;
      });
      // 🚀 REMOVE NATIVE SPLASH to show your Luxury Flutter Splash
      FlutterNativeSplash.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final currentTheme = ref.watch(themeProvider);

    return MaterialApp(
      // 🚀 INJECT THE GLOBAL KEYS HERE
      navigatorKey: GlobalKeys.navigatorKey,
      scaffoldMessengerKey: GlobalKeys.snackbarKey,

      title: 'Pure Shift',
      theme: currentTheme,
      debugShowCheckedModeBanner: false,

      // Localization Wiring
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      home: Builder(
        builder: (context) {
          // 1. Still loading / initializing? Show Splash Screen.
          if (!_isInitDone) {
            return const LuxurySplashScreen();
          }

          // 2. Fallback: If for some reason splash is removed but auth isn't checked
          if (!authState.initialCheckComplete) {
            return const LuxurySplashScreen();
          }
          if (authState.currentUser != null && authState.clientProfile != null) {
            return ClientDashboardScreen(client: authState.clientProfile!);
          }

          // 4. Fallback: Show Login/Auth Screen.
          return const ClientAuthScreen();
        },
      ),
    );
  }
}