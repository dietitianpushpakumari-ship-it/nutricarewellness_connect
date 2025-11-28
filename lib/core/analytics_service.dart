import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Observer for automatic screen tracking in MaterialApp
  FirebaseAnalyticsObserver getAnalyticsObserver() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ==================================================
  // 🛠 CORE LOGGING
  // ==================================================
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      if (kDebugMode) {
        print("📊 ANALYTICS: $name | Params: $parameters");
      }
    } catch (e) {
      if (kDebugMode) print("❌ ANALYTICS ERROR: $e");
    }
  }

  // ==================================================
  // 👤 USER IDENTITY
  // ==================================================
  Future<void> identifyUser({required String userId, String? userType}) async {
    await _analytics.setUserId(id: userId);
    if (userType != null) {
      await _analytics.setUserProperty(name: 'client_type', value: userType);
    }
    logEvent('user_identified', parameters: {'client_type': userType ?? 'unknown'});
  }

  Future<void> clearUser() async {
    await _analytics.setUserId(id: null);
    await _analytics.setUserProperty(name: 'client_type', value: null);
  }

  // ==================================================
  // 🏥 HEALTH & ENGAGEMENT EVENTS
  // ==================================================

  // Diet & Nutrition
  Future<void> logMealLogged({required String mealType, required bool hasPhoto}) async {
    await logEvent('meal_logged', parameters: {
      'meal_type': mealType,
      'has_photo': hasPhoto.toString(),
    });
  }

  // Vitals
  Future<void> logVitalsUpdated({required bool weight, required bool bp, required bool sugar}) async {
    await logEvent('vitals_update', parameters: {
      'weight_logged': weight.toString(),
      'bp_logged': bp.toString(),
      'sugar_logged': sugar.toString(),
    });
  }

  // Wellness
  Future<void> logWellnessToolUsed({required String toolName, int? durationSeconds}) async {
    await logEvent('wellness_tool_used', parameters: {
      'tool_name': toolName,
      'duration_seconds': durationSeconds ?? 0,
    });
  }

  // Support
  Future<void> logChatSent({required String type}) async {
    await logEvent('chat_message_sent', parameters: {'message_type': type});
  }
}