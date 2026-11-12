import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NudgeManager {
  static const String _kLastVitalsLog = 'last_vitals_log_date';
  static const String _kLastNudgeDismissed = 'last_vitals_nudge_dismissed';

  // 1. Call this whenever they actually hit "SAVE" in your LogVitalsSheet
  static Future<void> recordVitalsLogged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastVitalsLog, DateTime.now().toIso8601String());
    // Clear the dismiss timer since they actually did it
    await prefs.remove(_kLastNudgeDismissed);
    if (kIsWeb) {
      await prefs.reload();
    }
  }

  // 2. Call this if they hit "Skip for now"
  static Future<void> dismissNudgeTemporarily() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastNudgeDismissed, DateTime.now().toIso8601String());
    if (kIsWeb) {
      await prefs.reload();
    }
  }

  // 3. The Logic Engine: Should we show the nudge?
  static Future<bool> shouldShowVitalsNudge() async {
    final prefs = await SharedPreferences.getInstance();

    final lastLogStr = prefs.getString(_kLastVitalsLog);
    final lastDismissStr = prefs.getString(_kLastNudgeDismissed);
    final now = DateTime.now();

    // If they dismissed it recently, leave them alone for at least 2 days
    if (lastDismissStr != null) {
      final lastDismiss = DateTime.parse(lastDismissStr);
      if (now.difference(lastDismiss).inDays < 2) return false;
    }

    // If they have NEVER logged, show it.
    if (lastLogStr == null) return true;

    // If it's been more than 7 days since their last real log, show it.
    final lastLog = DateTime.parse(lastLogStr);
    if (now.difference(lastLog).inDays >= 7) return true;

    return false;
  }

  // 🚀 Returns the number of days since last log.
  // Returns -1 if NEVER logged.
  // Returns null if the nudge should be HIDDEN.
  static Future<int?> getNudgeStatus() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      await prefs.reload();
    }
    final lastLogStr = prefs.getString(_kLastVitalsLog);
    final lastDismissStr = prefs.getString(_kLastNudgeDismissed);
    final now = DateTime.now();

    // 1. Check if they hit "Skip" recently (Hide for 2 days)
    if (lastDismissStr != null) {
      final lastDismiss = DateTime.parse(lastDismissStr);
      if (now.difference(lastDismiss).inDays < 2) return null;
    }

    // 2. Brand new user / Never logged (Show immediately)
    if (lastLogStr == null) return -1;

    // 3. Existing user: Calculate exact days
    final daysSince = now.difference(DateTime.parse(lastLogStr)).inDays;

    // Only show if it's been 7 days or more
    if (daysSince >= 7) return daysSince;

    // Otherwise, hide it
    return null;
  }
}