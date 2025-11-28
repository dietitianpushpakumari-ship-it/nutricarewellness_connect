import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class GratitudeGardenSheet extends StatefulWidget {
  const GratitudeGardenSheet({super.key});
  @override
  State<GratitudeGardenSheet> createState() => _GratitudeGardenSheetState();
}

class _GratitudeGardenSheetState extends State<GratitudeGardenSheet> {
  final List<String> _items = ["Family", "Health"]; // Initial seeds
  final TextEditingController _controller = TextEditingController();
  final _audio = WellnessAudioService();

  void _plantSeed() {
    if (_controller.text.isEmpty) return;
    setState(() => _items.add(_controller.text));
    _controller.clear();
    _audio.playDing();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          // 🎯 Sky Gradient
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE1F5FE), Color(0xFFB3E5FC)]),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Stack(
          children: [
            // Clouds (Static Decoration)
            Positioned(top: 50, left: 30, child: Icon(Icons.cloud, size: 60, color: Colors.white.withOpacity(0.8))),
            Positioned(top: 80, right: 50, child: Icon(Icons.cloud, size: 40, color: Colors.white.withOpacity(0.6))),
      
            Column(
              children: [
                const SizedBox(height: 20),
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.blue.shade200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text("Gratitude Garden", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                const Text("Plant a seed of positivity today.", style: TextStyle(color: Colors.blueGrey)),
      
                // 🎯 The Garden
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Soil
                      Container(
                        height: 80,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5D4037),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(40)), // Curved Hill
                        ),
                      ),
                      // Flowers
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _items.map((label) => _buildGrowingFlower(label)).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
      
                // Input Area
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: "I am grateful for...",
                            filled: true,
                            fillColor: Colors.green.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        onPressed: _plantSeed,
                        backgroundColor: Colors.green,
                        child: const Icon(Icons.local_florist),
                      )
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowingFlower(String label) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 1),
      curve: Curves.elasticOut,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40), // Above soil
            child: Tooltip(
              message: label,
              triggerMode: TooltipTriggerMode.tap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.local_florist, color: Colors.pinkAccent, size: 40),
                  Container(width: 4, height: 60, color: Colors.green),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}