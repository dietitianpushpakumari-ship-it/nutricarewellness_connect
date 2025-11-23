import 'package:shared_preferences/shared_preferences.dart';

class RatingService {
  static const String _kLastAskedKey = 'last_rating_ask_date';
  static const String _kHasRatedKey = 'has_rated_app';

  // 🎯 Logic: Should we ask?
  Future<bool> shouldAsk() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. If already rated, never ask again.
    if (prefs.getBool(_kHasRatedKey) ?? false) return false;

    // 2. Check cooldown (e.g., 14 days)
    final lastAsked = prefs.getInt(_kLastAskedKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const cooldown = 14 * 24 * 60 * 60 * 1000; // 14 Days in milliseconds

    // 3. Ask if enough time has passed
    return (now - lastAsked > cooldown);
  }

  // Call this when they click "Rate Now" or "Don't Ask Again"
  Future<void> markAsAsked({bool rated = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastAskedKey, DateTime.now().millisecondsSinceEpoch);
    if (rated) await prefs.setBool(_kHasRatedKey, true);
  }
}