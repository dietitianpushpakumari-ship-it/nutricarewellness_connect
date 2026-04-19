import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthPermissionService {
  // Singleton pattern so we use the same instance everywhere
  static final HealthPermissionService _instance = HealthPermissionService._internal();
  factory HealthPermissionService() => _instance;
  HealthPermissionService._internal() {
    Health().configure(); // Initialize the package (v10+)
  }

  bool hasPermissions = false;

  Future<bool> requestPermissions(BuildContext context) async {
    // 1. ANDROID ONLY: Request Physical Activity First
    if (Theme.of(context).platform == TargetPlatform.android) {
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) {
        debugPrint("Physical Activity denied.");
        return false;
      }
    }

    // 2. HealthKit / Health Connect Types
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    try {
      // Check if already granted
      bool? granted = await Health().hasPermissions(types, permissions: permissions);

      // If not granted, trigger the OS popup
      if (granted != true) {
        granted = await Health().requestAuthorization(types, permissions: permissions);
      }

      hasPermissions = granted ?? false;
      return hasPermissions;

    } catch (e) {
      debugPrint("Health Auth Error: $e");
      return false;
    }
  }
}