import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class BalanceLockSheet extends StatefulWidget {
  const BalanceLockSheet({super.key});
  @override
  State<BalanceLockSheet> createState() => _BalanceLockSheetState();
}

class _BalanceLockSheetState extends State<BalanceLockSheet> with SingleTickerProviderStateMixin {
  // 🎯 State
  bool _isLive = false;
  int _timeLeft = 20;
  double _swayIndex = 0.0;
  double _peakSway = 0.0;

  // 🎯 Sensor Data
  double _hudX = 0.0;
  double _hudY = 0.0;

  StreamSubscription? _accelSub;
  Timer? _countdownTimer;
  Timer? _uiRenderTimer; // 🚀 Performance Throttler

  final _audio = WellnessAudioService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  void _startAudit() {
    setState(() {
      _isLive = true;
      _timeLeft = 20;
      _swayIndex = 0.0;
      _peakSway = 0.0;
    });

    _audio.playDing();

    // 1. Start Countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) _stopAudit();
      else if (_timeLeft <= 3) _audio.hapticLight(); // Warn approaching end
    });

    // 2. Listen to Hardware Sensors (Data collection only, NO setState here)
    _accelSub = accelerometerEventStream().listen((event) {
      // Map X and Y to a -1.0 to 1.0 alignment grid for the HUD
      _hudX = (event.x / 9.8).clamp(-1.0, 1.0);
      _hudY = (event.y / 9.8).clamp(-1.0, 1.0);

      // Calculate total force vector (Sway)
      double currentSway = sqrt(event.x * event.x + event.y * event.y + event.z * event.z) - 9.8;
      _swayIndex = currentSway.abs();
      if (_swayIndex > _peakSway) _peakSway = _swayIndex;

      // Haptic warning if they are losing balance (High Sway)
      if (_swayIndex > 1.5 && _isLive && _timeLeft % 2 == 0) {
        _audio.hapticHeavy();
      }
    });

    // 3. UI Render Loop (30 FPS for Redmi 8 smooth performance)
    _uiRenderTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted && _isLive) setState(() {}); // Batch visual updates
    });
  }

  void _stopAudit() {
    _accelSub?.cancel();
    _countdownTimer?.cancel();
    _uiRenderTimer?.cancel();
    _audio.playSuccess();
    if (mounted) setState(() => _isLive = false);
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _countdownTimer?.cancel();
    _uiRenderTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool isCritical = _swayIndex > 1.5;
    final Color hudColor = isCritical ? cs.error : cs.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // 🎯 1. COMPACT MEDICAL HEADER
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("NEUROMUSCULAR CONTROL", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text("Vestibular Baseline Audit", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 🎯 2. DATA TELEMETRY ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTelemetry("TIME LEFT", "00:${_timeLeft.toString().padLeft(2, '0')}", cs.primary),
                      _buildTelemetry("SWAY INDEX", _swayIndex.toStringAsFixed(2), hudColor),
                      _buildTelemetry("PEAK DEVIATION", _peakSway.toStringAsFixed(2), theme.hintColor),
                    ],
                  ),

                  const Spacer(),

                  // 🎯 3. BIOMETRIC COG HUD
                  RepaintBoundary(
                    child: SizedBox(
                      width: 240, height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radar Rings
                          Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.dividerColor.withOpacity(0.1), width: 1))),
                          Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.dividerColor.withOpacity(0.2), width: 1))),

                          // The "Safe Zone" Center
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) => Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.primary.withOpacity(0.3 + (_pulseController.value * 0.2)), width: 2),
                                color: cs.primary.withOpacity(0.05),
                              ),
                            ),
                          ),

                          // Crosshairs
                          Container(width: 2, height: 240, color: theme.dividerColor.withOpacity(0.1)),
                          Container(width: 240, height: 2, color: theme.dividerColor.withOpacity(0.1)),

                          // 🎯 The Moving CoG Indicator (The "Bubble")
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 100), // Smooths out sensor jitter
                            alignment: Alignment(-_hudX, _hudY), // Negative X so it mirrors natural tilt
                            child: Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: hudColor,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: hudColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 🎯 4. CLINICAL INSTRUCTIONS / RESULTS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isLive ? "Keep the dot inside the center ring." : (_peakSway > 0 ? "Audit Complete." : "Stand on one leg. Hold phone flat against your chest."),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLive
                              ? "Testing proprioceptive compensation..."
                              : (_peakSway > 0 ? _getClinicalResult() : "Press start to calibrate sensors."),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🎯 5. ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isLive ? null : _startAudit,
                      icon: Icon(_isLive ? Icons.sensors_rounded : Icons.play_arrow_rounded),
                      label: Text(_isLive ? "AUDIT IN PROGRESS" : (_peakSway > 0 ? "RETEST" : "START AUDIT")),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isLive ? theme.dividerColor.withOpacity(0.2) : cs.primary,
                        foregroundColor: _isLive ? theme.hintColor : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetry(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')),
      ],
    );
  }

  String _getClinicalResult() {
    if (_peakSway < 0.5) return "Excellent neuromuscular control. High vestibular stability.";
    if (_peakSway < 1.5) return "Normal sway detected. Proprioception is functional.";
    return "High deviation detected. Your balance required significant compensation.";
  }
}