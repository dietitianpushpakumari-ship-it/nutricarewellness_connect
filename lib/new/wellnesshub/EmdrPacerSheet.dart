import 'package:flutter/material.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

class EmdrPacerSheet extends StatefulWidget {
  const EmdrPacerSheet({super.key});

  @override
  State<EmdrPacerSheet> createState() => _EmdrPacerSheetState();
}

class _EmdrPacerSheetState extends State<EmdrPacerSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pacerController;
  final _audio = WellnessAudioService();

  bool _isActive = false;
  double _speedMultiplier = 1.0; // 1.0 = Normal, 1.5 = Fast (Anxiety), 0.7 = Slow (Sleep)
  String _modeLabel = "Processing Mode";

  @override
  void initState() {
    super.initState();
    // Default duration is 1.5 seconds per sweep (Left to Right)
    _pacerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 🎯 The Clinical Haptic Trigger
    // This ensures the vibration happens EXACTLY when the orb hits the edge
    _pacerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _audio.hapticMedium();
        _pacerController.reverse(); // Bounce back
      } else if (status == AnimationStatus.dismissed) {
        _audio.hapticMedium();
        _pacerController.forward(); // Bounce forward
      }
    });
  }

  void _toggleSession() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _pacerController.forward();
      } else {
        _pacerController.stop();
        // Reset to center smoothly when stopped
        _pacerController.animateTo(0.5, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      }
    });
  }

  void _changeSpeed(double multiplier, String label) {
    setState(() {
      _speedMultiplier = multiplier;
      _modeLabel = label;
      // Adjust the duration dynamically
      _pacerController.duration = Duration(milliseconds: (1500 / multiplier).round());
      if (_isActive) {
        // Restart the animation with the new speed
        if (_pacerController.status == AnimationStatus.forward) {
          _pacerController.forward();
        } else {
          _pacerController.reverse();
        }
      }
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
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Dark mode recommended for EMDR to reduce eye strain
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // 🎯 1. COMPACT MEDICAL HEADER
          const SizedBox(height: 12),
          Center(
            child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2))
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BILATERAL STIMULATION", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      Text("EMDR Orbit Pacer", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

          // 🎯 2. CLINICAL INSTRUCTIONS
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  _isActive ? "Keep your head perfectly still. Track the orb using only your eyes." : "Select a therapeutic speed below to begin.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  "Bilateral eye movements tax the working memory, rapidly desensitizing the nervous system to active stress.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.4),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 🎯 3. THE TRACKING ORBIT (High-Performance Animation)
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(60),
              border: Border.all(color: cs.primary.withOpacity(0.3), width: 2), // 🎯 Subtle glowing border replaces the inset shadow
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center Focal Line
                Container(width: 2, height: 40, color: Colors.white12),

                // The Moving Orb
                AnimatedBuilder(
                  animation: _pacerController,
                  builder: (context, child) {
                    // Map animation value (0.0 to 1.0) to Alignment (-1.0 to 1.0)
                    // We use 0.9 instead of 1.0 to keep the orb fully inside the capsule
                    double alignmentX = (_pacerController.value * 1.8) - 0.9;

                    return Align(
                      alignment: Alignment(alignmentX, 0),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isActive ? cs.primary : Colors.grey.shade700,
                          boxShadow: _isActive ? [
                            BoxShadow(color: cs.primary.withOpacity(0.6), blurRadius: 15, spreadRadius: 2),
                          ] : [],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const Spacer(),

          // 🎯 4. SPEED / INTENSITY CONTROLS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSpeedButton("Sleep Prep", 0.7, Icons.bedtime_rounded, cs),
                _buildSpeedButton("Processing", 1.0, Icons.sync_rounded, cs),
                _buildSpeedButton("Anxiety Spike", 1.6, Icons.bolt_rounded, cs),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text("Current State: $_modeLabel", style: TextStyle(color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 32),

          // 🎯 5. MASTER PLAY/PAUSE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _toggleSession,
                icon: Icon(_isActive ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_isActive ? "PAUSE SESSION" : "COMMENCE TRACKING", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: FilledButton.styleFrom(
                  backgroundColor: _isActive ? theme.colorScheme.error.withOpacity(0.8) : cs.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(String label, double multiplier, IconData icon, ColorScheme cs) {
    bool isSelected = _speedMultiplier == multiplier;
    return GestureDetector(
      onTap: () => _changeSpeed(multiplier, label),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? cs.primary.withOpacity(0.2) : Colors.transparent,
              border: Border.all(color: isSelected ? cs.primary : Colors.grey.withOpacity(0.3), width: 2),
            ),
            child: Icon(icon, color: isSelected ? cs.primary : Colors.grey, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? cs.primary : Colors.grey)),
        ],
      ),
    );
  }
}