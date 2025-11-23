import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class WellnessAudioService {
  static final WellnessAudioService _instance = WellnessAudioService._internal();
  factory WellnessAudioService() => _instance;
  WellnessAudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  // --- HAPTICS ---
  void hapticLight() => HapticFeedback.lightImpact();
  void hapticMedium() => HapticFeedback.mediumImpact();
  void hapticHeavy() => HapticFeedback.heavyImpact();
  void hapticSuccess() => HapticFeedback.vibrate();

  // --- SOUNDS (Using Local Assets) ---

  Future<void> playClick() async {
    // Short system click is better for UI taps
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> playDing() async {
    // For timer completion
    await _playSound('audio/ding.mp3');
  }

  Future<void> playSuccess() async {
    // For quiz/goal completion
    await _playSound('audio/success.mp3');
  }

  Future<void> playCrumple() async {
    // For Worry Shredder
    await _playSound('audio/crumple.mp3');
  }

  Future<void> playTick() async {
    // For Metronome
    // Note: For high-speed ticking, SoundPool is better, but AudioPlayer works for simple needs
    await _player.stop(); // Stop previous to prevent overlap lag
    await _playSound('audio/click.mp3');
  }

  Future<void> _playSound(String path) async {
    try {
      // Source is 'AssetSource' which automatically looks in 'assets/'
      // We pass 'audio/filename.mp3'
      await _player.play(AssetSource(path));
    } catch (e) {
      print("Audio Error: $e");
    }
  }

  void stop() {
    _player.stop();
  }
}