import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class EmdrPacerSheet extends StatefulWidget {
  const EmdrPacerSheet({super.key});
  @override
  State<EmdrPacerSheet> createState() => _EmdrPacerSheetState();
}

class _EmdrPacerSheetState extends State<EmdrPacerSheet> with SingleTickerProviderStateMixin {
  final _audio = WellnessAudioService();
  late AnimationController _pacerController;
  late Animation<double> _pacerAnimation;
  bool _isPlaying = false;
  String _currentSpeed = "Medium";

  final Map<String, int> _speedOptions = {"Slow": 2200, "Medium": 1400, "Fast": 800};

  @override
  void initState() {
    super.initState();
    _pacerController = AnimationController(vsync: this, duration: Duration(milliseconds: _speedOptions[_currentSpeed]!));
    _pacerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(CurvedAnimation(parent: _pacerController, curve: Curves.easeInOutSine));
    _pacerController.addStatusListener((s) {
      if (s == AnimationStatus.completed) _pacerController.reverse();
      else if (s == AnimationStatus.dismissed) _pacerController.forward();
    });
  }

  void _togglePlayback() {
    HapticFeedback.lightImpact();
    _audio.playClick();
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _pacerController.forward() : _pacerController.stop();
    });
  }

  void _updateSpeed(String speed) {
    if (_currentSpeed == speed) return;
    HapticFeedback.selectionClick();
    _audio.playClick();
    setState(() {
      _currentSpeed = speed;
      _pacerController.duration = Duration(milliseconds: _speedOptions[speed]!);
      if (_isPlaying) _pacerController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _pacerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      // 🚀 STRICT SAFE AREA HANDLING
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

            // 🎯 COMPACT MINIMALIST HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🚀 REFINED HEADER (Max Size 10, w700)
                        Text("EMDR PACER", style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        // 🚀 REFINED SUBTITLE (Max Size 12, w700)
                        Text(_isPlaying ? "Active Session" : "Ready to Start", style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // 🚀 REFINED INSTRUCTION TEXT (Max Size 12, w500)
                    Text("Follow the sphere with your eyes", textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 40),

                    // 🎾 COMPACT PACER TRACK
                    Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedBuilder(
                        animation: _pacerAnimation,
                        builder: (context, _) => Align(
                          alignment: Alignment(_pacerAnimation.value, 0),
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary,
                              boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 12, spreadRadius: 1)],
                              gradient: RadialGradient(colors: [Colors.white.withOpacity(0.5), colorScheme.primary], center: const Alignment(-0.3, -0.3)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // 🎛️ COMPACT SEGMENTED SPEED CONTROL
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                      child: Row(
                        children: _speedOptions.keys.map((speed) {
                          bool isSel = _currentSpeed == speed;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _updateSpeed(speed),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? colorScheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                // 🚀 REFINED SEGMENT TEXT (Max Size 11, w700)
                                child: Text(speed, textAlign: TextAlign.center, style: TextStyle(fontFamily: kDisplayFont, color: isSel ? Colors.white : theme.hintColor, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 🎯 MINIMALIST ACTION BUTTON
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 20),
              child: SizedBox(
                width: double.infinity, height: 50, // 🚀 Standardized to 50 for compact premium feel
                child: FilledButton(
                  onPressed: _togglePlayback,
                  style: FilledButton.styleFrom(
                    elevation: 0, // 🚀 Flat premium look
                    backgroundColor: _isPlaying ? Colors.red.withOpacity(0.1) : colorScheme.primary,
                    foregroundColor: _isPlaying ? Colors.red : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  // 🚀 REFINED BUTTON TEXT (Max Size 12, w700)
                  child: Text(_isPlaying ? "Stop Session" : "Start Tracking", style: const TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}