import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

// =================================================================
// 🚀 THE FIX: RIVERPOD PROVIDER TO SAVE THE GARDEN STATE
// This keeps your flowers alive even when the sheet is closed!
// =================================================================
class GratitudeGardenNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  GratitudeGardenNotifier() : super([
    {"text": "Family", "x": 0.2, "y": 0.8},    // Close (Large)
    {"text": "Health", "x": 0.7, "y": 0.5},    // Mid (Medium)
    {"text": "Inner Peace", "x": 0.4, "y": 0.2}, // Far (Small)
  ]);

  void plantSeed(String text) {
    state = [
      ...state,
      {
        "text": text,
        "x": 0.1 + (Random().nextDouble() * 0.8),
        "y": 0.15 + (Random().nextDouble() * 0.75),
      }
    ];
  }
}

final gratitudeGardenProvider = StateNotifierProvider<GratitudeGardenNotifier, List<Map<String, dynamic>>>((ref) {
  return GratitudeGardenNotifier();
});

// =================================================================
// 🌺 THE UI SHEET (Converted to ConsumerStatefulWidget)
// =================================================================
class GratitudeGardenSheet extends ConsumerStatefulWidget {
  const GratitudeGardenSheet({super.key});
  @override
  ConsumerState<GratitudeGardenSheet> createState() => _GratitudeGardenSheetState();
}

class _GratitudeGardenSheetState extends ConsumerState<GratitudeGardenSheet> {
  final TextEditingController _controller = TextEditingController();
  final _audio = WellnessAudioService();

  void _plantSeed() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 🚀 Save to the global provider instead of local state
    ref.read(gratitudeGardenProvider.notifier).plantSeed(text);

    _controller.clear();
    _audio.playDing();
    HapticFeedback.mediumImpact(); // Premium haptic feel
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 🚀 Read the saved seeds from the provider
    final savedSeeds = ref.watch(gratitudeGardenProvider);

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

          // 🚀 THE FIX: Premium Typography in Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("COGNITIVE REFRAMING",
                        style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)
                    ),
                    Text("Infinite Gratitude Meadow",
                        style: TextStyle(fontFamily: kDisplayFont, color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.5)
                    ),
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
                  final sortedSeeds = List.of(savedSeeds)..sort((a, b) => a['y'].compareTo(b['y']));

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
                    // 🚀 THE FIX: Premium Inter font for input
                    style: const TextStyle(fontFamily: kBodyFont, fontSize: 10, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: "What are you grateful for?",
                      hintStyle: TextStyle(fontFamily: kBodyFont, color: theme.hintColor.withOpacity(0.6), fontSize: 12),
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

  // 🚀 THE FIX: Space Grotesk applied to the Flower Labels
  Widget _buildGrowingFlower(String label, ColorScheme cs, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      // If you want them to 'pop' instantly if already loaded,
      // you could adjust this, but the growing animation is nice!
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
                child: Text(
                    label,
                    style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)
                ),
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