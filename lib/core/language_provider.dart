import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localization/language_config.dart';

// 🎯 DEFINITION OF LANGUAGE PROVIDER
final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code');
    if (langCode != null && supportedLanguageCodes.contains(langCode)) {
      state = Locale(langCode);
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLanguageCodes.contains(languageCode)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    state = Locale(languageCode);
  }
}