import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class IsochronicTappingSheet extends StatefulWidget {
  const IsochronicTappingSheet({super.key});

  @override
  State<IsochronicTappingSheet> createState() => _IsochronicTappingSheetState();
}

class _IsochronicTappingSheetState extends State<IsochronicTappingSheet> {
  bool _isLeft = true;
  Timer? _timer;
  bool _isRunning = false;
  final _audio = WellnessAudioService();

  void _toggle() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(milliseconds: 600), (t) {
        setState(() => _isLeft = !_isLeft);
        // 🎯 Sound & Haptic
        _audio.playTick();
        _audio.hapticLight();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Anxiety Reset", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Tap the glowing orb to the beat.", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOrb(_isLeft),
              _buildOrb(!_isLeft),
            ],
          ),
          const SizedBox(height: 40),
          ElevatedButton(onPressed: _toggle, child: Text(_isRunning ? "Stop" : "Start"))
        ],
      ),
    );
  }

  Widget _buildOrb(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.blueAccent : Colors.white10,
        boxShadow: active ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 30, spreadRadius: 10)] : [],
      ),
    );
  }
}