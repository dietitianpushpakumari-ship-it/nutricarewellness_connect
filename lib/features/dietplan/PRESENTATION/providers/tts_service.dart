import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text, String languageCode, String voiceProfile) async {
    await _tts.setLanguage(languageCode); // e.g., "en-US", "hi-IN" (FR-DAT-06)

    // 🎯 FR-DAT-05: This is a placeholder for voice profile selection.
    // The 'flutter_tts' package's ability to select a specific *persona*
    // (like 'male_coach' vs 'female_child') is highly platform-dependent.
    // We set the language, but the specific voice is often a device default.
    // For a real product, this would require a premium cloud TTS API (like Azure, Google).

    // For now, 'voiceProfile' is used to demonstrate the logic.
    print("TTS Service: Speaking in $languageCode with profile $voiceProfile");

    await _tts.setSpeechRate(0.5); // Slightly slower for clarity
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }
}