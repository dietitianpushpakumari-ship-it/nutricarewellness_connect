// lib/helper/language_config.dart

const Map<String, String> supportedLanguages = {
  'en': 'English',
  'hi': 'Hindi (हिन्दी)',
  'or': 'Odia (ଓଡ଼ିଆ)', // 🎯 CHANGE 'od' TO 'or'
};

// 🎯 This is the variable the error refers to
final List<String> supportedLanguageCodes = supportedLanguages.keys.toList();