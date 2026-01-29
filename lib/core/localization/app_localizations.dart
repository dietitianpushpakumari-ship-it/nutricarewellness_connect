import 'dart:async';
import 'dart:convert'; // Required for json.decode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for rootBundle

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  // Usage: AppLocalizations.of(context)!.translate('key');
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // Static member to have simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  // 🎯 LOAD LOGIC
  Future<bool> load() async {
    try {
      // 1. Load the JSON file from the "assets/lang" folder
      String jsonString = await rootBundle.loadString('assets/lang/${locale.languageCode}.json');

      // 2. Decode the JSON
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      // 3. Map values to Dart Map
      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });

      return true;
    } catch (e) {
      // Fallback or error logging if file is missing/corrupt
      debugPrint("⚠️ Error loading localization file for ${locale.languageCode}: $e");
      _localizedStrings = {}; // Prevent null crash
      return false;
    }
  }

  // 🎯 TRANSLATE METHOD
  String translate(String key) {
    return _localizedStrings[key] ?? key; // Returns the key if translation is missing
  }
}

// 🎯 DELEGATE CLASS
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  // This delegate instance will never change (it doesn't even have fields!)
  // It can provide a constant constructor.
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all of your supported language codes here
    return ['en', 'hi', 'or'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // AppLocalizations class is where the JSON loading actually happens
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}