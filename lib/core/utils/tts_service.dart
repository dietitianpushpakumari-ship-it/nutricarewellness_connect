import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';

class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();

  Function(int start, int end)? onProgress;
  Function()? onComplete;

  TextToSpeechService() {
    _tts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
      if (onProgress != null) onProgress!(startOffset, endOffset);
    });

    _tts.setCompletionHandler(() {
      if (onComplete != null) onComplete!();
    });

    if (Platform.isIOS) {
      _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    }
  }

  Future<List<dynamic>> getIndianVoices() async {
    try {
      final voices = await _tts.getVoices;
      // Filter for Indian locales
      return voices.where((v) {
        final locale = v['locale'].toString().toLowerCase();
        return locale.contains('in');
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> isLanguageAvailable(String lang) async {
    return await _tts.isLanguageAvailable(lang);
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
  }

  // 🎯 FIX: Accept 'voice' parameter and set it AFTER language
  Future<void> speak({
    required String text,
    required String languageCode,
    double rate = 0.5,
    double pitch = 1.0,
    Map<String, String>? voice,
  }) async {
    // 1. Set Language First
    await _tts.setLanguage(languageCode);

    // 2. Set Voice Second (Critical for Male/Female to stick)
    if (voice != null) {
      await _tts.setVoice(voice);
    }

    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}