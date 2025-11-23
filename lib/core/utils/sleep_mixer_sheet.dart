import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SleepMixerSheet extends StatefulWidget {
  const SleepMixerSheet({super.key});

  @override
  State<SleepMixerSheet> createState() => _SleepMixerSheetState();
}

class _SleepMixerSheetState extends State<SleepMixerSheet> {
  // 🎯 Audio Players (One for each track)
  final AudioPlayer _rainPlayer = AudioPlayer();
  final AudioPlayer _firePlayer = AudioPlayer();
  final AudioPlayer _windPlayer = AudioPlayer();

  // 🎯 Volume State
  double _rainVol = 0.0;
  double _fireVol = 0.0;
  double _windVol = 0.0;

  @override
  void initState() {
    super.initState();
    _initPlayers();
  }

  Future<void> _initPlayers() async {
    // Configure for looping
    await _rainPlayer.setReleaseMode(ReleaseMode.loop);
    await _firePlayer.setReleaseMode(ReleaseMode.loop);
    await _windPlayer.setReleaseMode(ReleaseMode.loop);

    // 🎯 Preload Local Assets
    // Note: AssetSource automatically prefixes 'assets/'
    await _rainPlayer.setSource(AssetSource('audio/rain.mp3'));
    await _firePlayer.setSource(AssetSource('audio/fire.mp3'));
    await _windPlayer.setSource(AssetSource('audio/wind.mp3'));
  }

  @override
  void dispose() {
    _rainPlayer.dispose();
    _firePlayer.dispose();
    _windPlayer.dispose();
    super.dispose();
  }

  void _updateVolume(AudioPlayer player, double vol) async {
    if (vol > 0 && player.state != PlayerState.playing) {
      await player.resume(); // Use resume for preloaded sources
    } else if (vol == 0 && player.state == PlayerState.playing) {
      await player.pause();
    }
    await player.setVolume(vol);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Deep Night Blue
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text("Sleep Soundscapes", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Mix your perfect environment", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 40),

          // 🎯 Sliders
          _buildSoundControl("Rain", Icons.water_drop, _rainVol, (val) {
            setState(() => _rainVol = val);
            _updateVolume(_rainPlayer, val);
          }),
          const SizedBox(height: 20),
          _buildSoundControl("Campfire", Icons.local_fire_department, _fireVol, (val) {
            setState(() => _fireVol = val);
            _updateVolume(_firePlayer, val);
          }),
          const SizedBox(height: 20),
          _buildSoundControl("Wind", Icons.air, _windVol, (val) {
            setState(() => _windVol = val);
            _updateVolume(_windPlayer, val);
          }),

          const Spacer(),

          // Stop Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
              child: const Text("Stop & Close"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSoundControl(String label, IconData icon, double value, ValueChanged<double> onChanged) {
    final bool isActive = value > 0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? Colors.indigoAccent.withOpacity(0.2) : Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isActive ? Colors.indigoAccent : Colors.white54),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
              Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                activeColor: Colors.indigoAccent,
                inactiveColor: Colors.white10,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}