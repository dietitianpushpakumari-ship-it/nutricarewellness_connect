import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class GratitudeGardenSheet extends StatefulWidget {
  const GratitudeGardenSheet({super.key});

  @override
  State<GratitudeGardenSheet> createState() => _GratitudeGardenSheetState();
}

class _GratitudeGardenSheetState extends State<GratitudeGardenSheet> {
  final List<String> _items = [];
  final TextEditingController _controller = TextEditingController();
  final _audio = WellnessAudioService();

  void _add() {
    if (_controller.text.isEmpty) return;
    setState(() => _items.add(_controller.text));
    _controller.clear();

    // 🎯 Growth Sound
    _audio.playDing();
    _audio.hapticMedium();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFFE8F5E9), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          const Text("Gratitude Garden", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
          const Text("Plant a seed for everything you are grateful for.", style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),

          // Garden Area
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(width: double.infinity, height: 20, color: Colors.brown.shade300), // Soil
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _items.map((e) => _buildFlower(e)).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: "I am grateful for...", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              FloatingActionButton(onPressed: _add, backgroundColor: Colors.green, child: const Icon(Icons.add)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFlower(String label) {
    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.tap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_florist, color: Colors.pink, size: 40),
          Container(width: 4, height: 60, color: Colors.green),
        ],
      ),
    );
  }
}