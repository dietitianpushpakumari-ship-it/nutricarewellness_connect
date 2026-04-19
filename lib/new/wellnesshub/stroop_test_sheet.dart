import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class StroopTestSheet extends StatefulWidget {
  const StroopTestSheet({super.key});

  @override
  State<StroopTestSheet> createState() => _StroopTestSheetState();
}

class _StroopTestSheetState extends State<StroopTestSheet> with SingleTickerProviderStateMixin {
  final _audio = WellnessAudioService();
  final Random _random = Random();

  // ⏱️ Game State
  int _score = 0;
  int _timeLeft = 45; // 45-second brain workout
  bool _isPlaying = false;
  bool _isGameOver = false;
  Timer? _timer;

  // 🧠 Stroop Data
  final List<Map<String, dynamic>> _colors = [
    {"name": "RED", "color": Colors.red.shade500},
    {"name": "BLUE", "color": Colors.blue.shade500},
    {"name": "GREEN", "color": Colors.green.shade500},
    {"name": "YELLOW", "color": Colors.orange.shade500},
    {"name": "PURPLE", "color": Colors.purple.shade500},
    {"name": "PINK", "color": Colors.pink.shade500},
  ];

  late String _displayText;
  late Color _displayColor;
  late Color _correctColor;

  // 🎬 Animations
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _generateNextWord();
  }

  void _generateNextWord() {
    int textIndex = _random.nextInt(_colors.length);
    int colorIndex = _random.nextInt(_colors.length);

    if (_random.nextDouble() > 0.2 && textIndex == colorIndex) {
      colorIndex = (colorIndex + 1) % _colors.length;
    }

    setState(() {
      _displayText = _colors[textIndex]["name"];
      _displayColor = _colors[colorIndex]["color"];
      _correctColor = _displayColor; // The user must tap the color the word is written in.
    });
  }

  void _startGame() {
    HapticFeedback.lightImpact();
    setState(() {
      _score = 0;
      _timeLeft = 45;
      _isPlaying = true;
      _isGameOver = false;
    });
    _generateNextWord();
    _audio.playClick();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _timer?.cancel();
    _audio.playSuccess();
    HapticFeedback.mediumImpact();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
  }

  void _checkAnswer(Color tappedColor) {
    if (!_isPlaying) return;

    if (tappedColor == _correctColor) {
      // ✅ Correct
      HapticFeedback.selectionClick();
      _audio.playClick();
      setState(() => _score += 10);
      _generateNextWord();
    } else {
      // ❌ Wrong
      HapticFeedback.heavyImpact(); // Premium tactile warning
      _shakeController.forward(from: 0.0);
      setState(() {
        _score = max(0, _score - 5);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32))
      ),
      // 🚀 STRICT SAFE AREA HANDLING
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            // ==========================================
            // 🎯 THE ULTRA-PREMIUM COMPACT HEADER
            // ==========================================
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("COGNITIVE FOCUS", style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Stroop Test", style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),

                  // ⏱️ Compact Stats Pill (Score & Time)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isPlaying && _timeLeft <= 10 ? Colors.red.withOpacity(0.1) : colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isPlaying && _timeLeft <= 10 ? Colors.red.withOpacity(0.3) : colorScheme.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text("$_score", style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Icon(Icons.timer_outlined, size: 14, color: _isPlaying && _timeLeft <= 10 ? Colors.red : colorScheme.primary),
                        const SizedBox(width: 4),
                        Text("0:${_timeLeft.toString().padLeft(2, '0')}", style: TextStyle(fontFamily: kDisplayFont, color: _isPlaying && _timeLeft <= 10 ? Colors.red : colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ✖️ Compact Close Button
                  Container(
                    decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: IconButton(
                      iconSize: 16, padding: const EdgeInsets.all(6), constraints: const BoxConstraints(),
                      icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: theme.dividerColor.withOpacity(0.1)),

            // ==========================================
            // 🎯 MAIN GAMEPLAY AREA
            // ==========================================
            Expanded(
              child: _isGameOver ? _buildGameOverState(theme, colorScheme) : _buildPlayingState(theme, colorScheme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // 🎮 THE PLAYING UI
  // ----------------------------------------------------
  Widget _buildPlayingState(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isPlaying)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Tap the button that matches the INK COLOR, not the word itself. Go as fast as you can!",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, color: theme.hintColor, height: 1.5),
            ),
          ),

        const Spacer(),

        // 🎯 The Focus Word
        AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final sineValue = sin(4 * pi * _shakeController.value);
              return Transform.translate(
                offset: Offset(sineValue * 10, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: theme.shadowColor.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)
                      ]
                  ),
                  child: Text(
                    _isPlaying ? _displayText : "READY",
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      // 🚀 THE FIX: Using _displayColor so "RED" written in blue ink actually shows up blue!
                      color: _isPlaying ? _displayColor : theme.disabledColor,
                    ),
                  ),
                ),
              );
            }
        ),

        const Spacer(),

        // 🎯 Responsive Color Buttons
        if (_isPlaying)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _colors.map((colorData) {
                return _buildColorButton(colorData["name"], colorData["color"], theme);
              }).toList(),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text("Start Test", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildColorButton(String name, Color btnColor, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _checkAnswer(btnColor),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: btnColor.withOpacity(0.15),
            border: Border.all(color: btnColor.withOpacity(0.5), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              name,
              style: TextStyle(fontFamily: kDisplayFont, color: btnColor, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // 🏆 THE GAME OVER UI
  // ----------------------------------------------------
  Widget _buildGameOverState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.psychology_rounded, size: 48, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text("Test Complete!", style: TextStyle(fontFamily: kBodyFont, fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text("Your Focus Score", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, color: theme.hintColor)),
          const SizedBox(height: 8),
          Text("$_score", style: TextStyle(fontFamily: kDisplayFont, fontSize: 36, fontWeight: FontWeight.w700, color: colorScheme.primary)),

          const SizedBox(height: 48),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Try Again", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}