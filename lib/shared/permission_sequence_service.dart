import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionSequenceService {
  Future<void> runWelcomeSequence(BuildContext context) async {
    // 🛑 1. Web Guard: Browsers don't support native health/activity sensors
    if (kIsWeb) return;

    // 🚀 2. Health v10+ requires configure() to be called before anything else
    Health().configure();

    // 3. Request Notifications
    await _requestNotifications();

    // 4. Request Physical Activity (Hardware Sensor)
    await _requestActivityRecognition();

    // 5. Request Health Database (Apple Health or Health Connect)
    if (context.mounted) {
      await _requestHealthDatabase(context);
    }
  }

  Future<void> _requestNotifications() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
  }

  Future<void> _requestActivityRecognition() async {
    // On Android this asks for Physical Activity. On iOS it asks for Motion & Fitness.
    await Permission.activityRecognition.request();
  }

  Future<void> _requestHealthDatabase(BuildContext context) async {
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    // 🤖 ANDROID LOGIC: Health Connect
    if (Platform.isAndroid) {
      var status = await Health().getHealthConnectSdkStatus();

      if (status == HealthConnectSdkStatus.sdkAvailable) {
        // Installed! Check and request permissions.
        bool? hasPerms = await Health().hasPermissions(types, permissions: permissions);
        if (hasPerms != true) {
          await Health().requestAuthorization(types, permissions: permissions);
        }
      } else {
        // 🚀 THE FIX: It's not installed. Prompt the user to download it from the Play Store!
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please install Health Connect to sync your steps.")),
          );
        }
        await Health().installHealthConnect();
      }
    }
    // 🍎 iOS LOGIC: Apple Health
    else if (Platform.isIOS) {
      // iOS doesn't use SDK status checks, Apple Health is built-in.
      bool? hasPerms = await Health().hasPermissions(types, permissions: permissions);
      if (hasPerms != true) {
        await Health().requestAuthorization(types, permissions: permissions);
      }
    }
  }
}