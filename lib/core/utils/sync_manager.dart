import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/material.dart';
// import 'package:nutricare_connect/services/client_service.dart';

// Task ID
const String kBackgroundSyncTask = "nutricare.sync.4hr";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kBackgroundSyncTask) {
      // Initialize services here if needed (Firebase.initializeApp())
      final syncService = SyncManager();
      await syncService.performBatchSync();
    }
    return Future.value(true);
  });
}

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final String _kLastSyncKey = 'last_successful_sync_time';

  // 🎯 SETUP: Call this in main.dart
  Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);

    // Schedule the 4-hour "Train"
    await Workmanager().registerPeriodicTask(
      "unique_sync_task", // Unique Name
      kBackgroundSyncTask, // Task Name
      frequency: const Duration(hours: 4),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      // 🎯 FIX: Use ExistingPeriodicWorkPolicy instead of ExistingWorkPolicy
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  // 🎯 APP LAUNCH CHECK
  Future<void> checkAppLaunchSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMillis = prefs.getInt(_kLastSyncKey) ?? 0;
    final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
    final now = DateTime.now();

    if (now.difference(lastSync).inHours >= 4) {
      debugPrint("🚀 App Launch: Sync stale (>4hrs). Syncing now...");
      await performBatchSync();
    } else {
      debugPrint("✅ App Launch: Data is fresh. Skipping DB hit.");
    }
  }

  // 🎯 THE CORE SYNC LOGIC (Consumes 1 DB Hit)
  Future<void> performBatchSync() async {
    debugPrint("🔄 Starting Batch Sync...");

    try {
      // Insert your actual sync logic here
      // Example: await AnalyticsService().flushLocalEvents();

      // 3. MARK SUCCESS
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSyncKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint("✅ Batch Sync Complete.");
    } catch (e) {
      debugPrint("❌ Sync Failed: $e");
    }
  }
}