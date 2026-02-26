import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SleepMixerSheet extends StatefulWidget {
  const SleepMixerSheet({super.key});
  @override
  State<SleepMixerSheet> createState() => _SleepMixerSheetState();
}

class _SleepMixerSheetState extends State<SleepMixerSheet> {
  // 🎯 4 Clinical Players
  final AudioPlayer _brownPlayer = AudioPlayer();
  final AudioPlayer _pinkPlayer = AudioPlayer();
  final AudioPlayer _whitePlayer = AudioPlayer();
  final AudioPlayer _rainPlayer = AudioPlayer();

  // 🎯 Volume States
  double _brownVol = 0.0;
  double _pinkVol = 0.0;
  double _whiteVol = 0.0;
  double _rainVol = 0.0;

  @override
  void initState() {
    super.initState();
    _initPlayers();
  }

  Future<void> _initPlayers() async {
    final players = [_brownPlayer, _pinkPlayer, _whitePlayer, _rainPlayer];
    for (var p in players) {
      await p.setReleaseMode(ReleaseMode.loop);
    }
    // Preload Clinical Assets
    await _brownPlayer.setSource(AssetSource('audio/brown_noise.mp3'));
    await _pinkPlayer.setSource(AssetSource('audio/pink_noise.mp3'));
    await _whitePlayer.setSource(AssetSource('audio/white_noise.mp3'));
    await _rainPlayer.setSource(AssetSource('audio/rain.mp3'));
  }

  void _fadeVolume(AudioPlayer p, double target) async {
    if (target > 0 && p.state != PlayerState.playing) {
      await p.setVolume(0);
      await p.resume();
    }

    double current = p.volume;
    Timer.periodic(const Duration(milliseconds: 15), (t) {
      if ((current - target).abs() < 0.05) {
        p.setVolume(target);
        if (target == 0) p.pause();
        t.cancel();
      } else {
        current += (target > current) ? 0.05 : -0.05;
        p.setVolume(current.clamp(0.0, 1.0));
      }
    });
  }

  @override
  void dispose() {
    for (var p in [_brownPlayer, _pinkPlayer, _whitePlayer, _rainPlayer]) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SOUNDSCAPE MIXER", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text("Clinical Sleep Support", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildTrack("Deep Brown", "Delta Wave Calm", Icons.blur_on_rounded, _brownVol, (v) {
                    setState(() => _brownVol = v);
                    _fadeVolume(_brownPlayer, v);
                  }, Colors.orangeAccent),
                  _buildTrack("Pink Noise", "Sleep Stability", Icons.graphic_eq_rounded, _pinkVol, (v) {
                    setState(() => _pinkVol = v);
                    _fadeVolume(_pinkPlayer, v);
                  }, Colors.pinkAccent),
                  _buildTrack("White Noise", "Sound Masking", Icons.grain_rounded, _whiteVol, (v) {
                    setState(() => _whiteVol = v);
                    _fadeVolume(_whitePlayer, v);
                  }, Colors.tealAccent),
                  _buildTrack("Rainfall", "Anxiety Reduction", Icons.water_drop_rounded, _rainVol, (v) {
                    setState(() => _rainVol = v);
                    _fadeVolume(_rainPlayer, v);
                  }, Colors.blueAccent),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 20),
            child: SizedBox(
              width: double.infinity, height: 56,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Keep Playing & Close", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTrack(String t, String s, IconData i, double v, ValueChanged<double> onC, Color c) {
    final theme = Theme.of(context);
    bool active = v > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? c.withOpacity(0.2) : theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(i, color: active ? c : theme.hintColor, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: active ? theme.colorScheme.onSurface : theme.hintColor)),
                  Text(s, style: TextStyle(fontSize: 10, color: theme.hintColor)),
                ]),
              ),
              Text("${(v * 100).toInt()}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(value: v, min: 0.0, max: 1.0, activeColor: c, inactiveColor: theme.dividerColor.withOpacity(0.1), onChanged: onC),
          ),
        ],
      ),
    );
  }
}