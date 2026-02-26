import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class GratitudeGardenSheet extends StatefulWidget {
  const GratitudeGardenSheet({super.key});
  @override
  State<GratitudeGardenSheet> createState() => _GratitudeGardenSheetState();
}

class _GratitudeGardenSheetState extends State<GratitudeGardenSheet> {
  // 🎯 Coordinates are percentages (0.0 to 1.0)
  final List<Map<String, dynamic>> _seeds = [
    {"text": "Family", "x": 0.2, "y": 0.8},    // Close (Large)
    {"text": "Health", "x": 0.7, "y": 0.5},    // Mid (Medium)
    {"text": "Inner Peace", "x": 0.4, "y": 0.2}, // Far (Small)
  ];

  final TextEditingController _controller = TextEditingController();
  final _audio = WellnessAudioService();

  void _plantSeed() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _seeds.add({
        "text": _controller.text.trim(),
        "x": 0.1 + (Random().nextDouble() * 0.8),
        "y": 0.15 + (Random().nextDouble() * 0.75),
      });
    });

    _controller.clear();
    _audio.playDing();
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("COGNITIVE REFRAMING", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    Text("Infinite Gratitude Meadow", style: TextStyle(color: theme.hintColor, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),

          Expanded(
            child: LayoutBuilder(
                builder: (context, constraints) {
                  // 🎯 Sort by Y so that flowers in front (higher Y) are drawn last (on top)
                  final sortedSeeds = List.of(_seeds)..sort((a, b) => a['y'].compareTo(b['y']));

                  return Stack(
                    children: [
                      // Background Hill
                      Positioned(
                        bottom: -80,
                        left: -constraints.maxWidth * 0.2,
                        child: Container(
                          width: constraints.maxWidth * 1.4,
                          height: 250,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [cs.primary.withOpacity(0.08), Colors.transparent],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                      ...sortedSeeds.map((seed) {
                        // 🎯 3D DEPTH MATH:
                        // Higher Y (closer to bottom) = Scale 1.0 (Full size)
                        // Lower Y (closer to top) = Scale 0.6 (Small & Faded)
                        double depthScale = (0.5 + (seed["y"] * 0.5)).clamp(0.5, 1.0);
                        double depthOpacity = (0.4 + (seed["y"] * 0.6)).clamp(0.4, 1.0);

                        return Positioned(
                          left: seed["x"] * constraints.maxWidth - (40 * depthScale),
                          top: seed["y"] * constraints.maxHeight,
                          child: Opacity(
                            opacity: depthOpacity,
                            child: Transform.scale(
                              scale: depthScale,
                              alignment: Alignment.bottomCenter,
                              child: _buildGrowingFlower(seed["text"], cs, theme),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }
            ),
          ),

          // Glassmorphism Input
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "What are you grateful for?",
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _plantSeed(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  onPressed: _plantSeed,
                  backgroundColor: cs.primary,
                  elevation: 4,
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowingFlower(String label, ColorScheme cs, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                  border: Border.all(color: cs.primary.withOpacity(0.2)),
                ),
                child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Icon(Icons.spa_rounded, color: cs.primary, size: 32),
              Container(
                width: 2,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.primary.withOpacity(0.4), Colors.transparent],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}