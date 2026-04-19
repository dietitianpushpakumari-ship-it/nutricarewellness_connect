import 'dart:io';
import 'package:flutter/material.dart'; // 🎯 Required for MaterialPageRoute
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pure_shift/global_keys.dart';
import 'package:pure_shift/new/chat/client_chat_screen.dart';

// 🚨 IMPORTANT: Import your main.dart so this file can access the navigatorKey!
// import 'package:nutricare_client_management/main.dart';
// import 'package:nutricare_client_management/new/dashboard/home_screen.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🎯 1. DEFINE THE HIGH IMPORTANCE CHANNEL (For Android Popups)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'nutricare_high_alerts', // 🎯 MUST MATCH YOUR CLOUD FUNCTION AND MANIFEST
    'High Importance Notifications',
    description: 'This channel is used for important dietitian alerts.',
    importance: Importance.max, // 🚀 THIS FORCES THE HEADS-UP BANNER
    playSound: true,
  );

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // 🎯 SINGLETON PATTERN
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// 🛰️ SYNC TOKEN WITH DATABASE
  /// Works for both 'clients' and 'admins' collections
  Future<void> syncTokenToFirestore({
    required String userId,
    required String collectionName, // Use 'clients' or 'admins'
    bool forceUpdate = false,
  }) async {
    try {
      // 1. Request Permission (Crucial for iOS & Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Get the current device token
        String? currentToken = await _fcm.getToken();
        if (currentToken == null) return;

        // 3. Fetch stored token to avoid redundant writes
        DocumentSnapshot doc = await _db.collection(collectionName).doc(userId).get();

        if (doc.exists) {
          String? storedToken = (doc.data() as Map<String, dynamic>?)?['fcmToken'];

          // 4. Update ONLY if it's missing, different, or forced
          if (forceUpdate || storedToken != currentToken) {
            await _db.collection(collectionName).doc(userId).update({
              'fcmToken': currentToken,
              'lastTokenSync': FieldValue.serverTimestamp(),
              'devicePlatform': Platform.isAndroid ? 'android' : 'ios',
            });
            debugPrint("🚀 FCM Token synced for $collectionName: $userId");
          }
        }
      } else {
        debugPrint("🚫 User declined notification permissions.");
      }
    } catch (e) {
      debugPrint("🚨 NotificationService Error: $e");
    }
  }

  /// 🚿 CLEAR TOKEN ON LOGOUT
  /// Prevents the user from getting notifications after logging out
  Future<void> clearTokenOnLogout({
    required String userId,
    required String collectionName,
  }) async {
    try {
      await _db.collection(collectionName).doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      debugPrint("🔐 FCM Token removed for $userId");
    } catch (e) {
      debugPrint("🚨 Error clearing token: $e");
    }
  }

  // =========================================================================
  // 🚦 NOTIFICATION ROUTING & CLICK HANDLERS (FIXED)
  // =========================================================================

  /// Call this ONCE in your main.dart or after successful login
  Future<void> setupNotificationRouting() async {
    // 🎯 2. INITIALIZE THE ANDROID CHANNEL (Fixes the silent background issue)
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // 1. Handle Notification tap when app is in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

    // 2. Handle Notification tap when app is TERMINATED
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationClick(message);
        });
      }
    });

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 Foreground Message Received: ${message.notification?.title}");

      // Optional: Since you have the channel set up, you could also manually
      // trigger a local notification here if you want it to pop up while the app is open.
    });
  }


  /// 🎯 THE ROUTER: Where to go when the user taps the push notification from the OS Tray
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint("🎯 System Notification Clicked! Payload: ${message.data}");

    // Look for the route or type we defined in the Cloud Function
    final String? route = message.data['route'] ?? message.data['type'];
    final String? clientId = message.data['clientId']; // Useful for Admin app

    if (route == "chat" || route == "chat_message") {

      // We grab the global navigator context
      final context = GlobalKeys.navigatorKey.currentContext;

      if (context != null) {
        debugPrint("✅ Navigator is ready. Jumping to Chat Screen...");

        // 🚀 FOR THE CLIENT APP:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientChatScreen()));

        // 🚀 IF THIS IS THE ADMIN APP, USE THIS INSTEAD:
        // if (clientId != null) {
        //   Navigator.push(context, MaterialPageRoute(builder: (_) => AdminChatScreen(clientId: clientId, clientName: "Client")));
        // }

      } else {
        debugPrint("❌ Navigator context was null. The app hasn't fully painted yet.");
      }
    }
  }
}