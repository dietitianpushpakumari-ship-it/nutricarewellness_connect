import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class FocusGridSheet extends StatefulWidget {
  const FocusGridSheet({super.key});

  @override
  State<FocusGridSheet> createState() => _FocusGridSheetState();
}

class _FocusGridSheetState extends State<FocusGridSheet> {
  List<int> _grid = [];
  int _next = 1;
  bool _playing = false;
  Timer? _timer;
  final _audio = WellnessAudioService();

  // 🎯 OPTIMIZATION: ValueNotifier prevents the whole grid from rebuilding every second
  final ValueNotifier<int> _time = ValueNotifier<int>(0);

  void _startGame() {
    setState(() {
      _grid = List.generate(25, (i) => i + 1)..shuffle();
      _next = 1;
      _playing = true;
    });
    _time.value = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) => _time.value++);
  }

  void _tap(int n) {
    if (n == _next) {
      _audio.playClick();
      setState(() => _next++); // 🎯 Only rebuilds when a correct number is tapped
      if (_next > 25) {
        _timer?.cancel();
        _audio.playSuccess();
        setState(() => _playing = false);
        _showWin();
      }
    } else {
      _audio.hapticHeavy();
    }
  }

  void _showWin() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
        context: context,
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 🎯 Premium Glass Blur Effect
          child: AlertDialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.2))
            ),
            title: Row(
              children: [
                Icon(Icons.stars_rounded, color: colorScheme.primary, size: 28),
                const SizedBox(width: 8),
                Text("Focus Master!", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You cleared the board in:", style: TextStyle(color: theme.hintColor)),
                const SizedBox(height: 8),
                Text("${_time.value} seconds", style: TextStyle(color: colorScheme.primary, fontSize: 32, fontWeight: FontWeight.w900)),
              ],
            ),
            actions: [
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Awesome", style: TextStyle(fontWeight: FontWeight.bold))
              )
            ],
          ),
        )
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, // 🎨 Themed Background
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            // 🎯 Themed Drag Handle
            const SizedBox(height: 16),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),

            // 🎯 Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("SCHULTE TABLE", style: TextStyle(color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text("Find numbers 1 to 25 in order.", style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.hintColor),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🎯 OPTIMIZED TIMER DISPLAY
            ValueListenableBuilder<int>(
              valueListenable: _time,
              builder: (context, seconds, child) {
                return Text(
                    "$seconds s",
                    style: TextStyle(
                        color: _playing ? colorScheme.primary : theme.hintColor.withOpacity(0.3),
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Monospace'
                    )
                );
              },
            ),

            const SizedBox(height: 20),

            // 🎯 THEMED GRID OR START BUTTON
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _playing ? GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10
                  ),
                  itemCount: 25,
                  itemBuilder: (context, index) {
                    final num = _grid[index];
                    final found = num < _next;

                    return GestureDetector(
                      onTap: () => _tap(num),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: found ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.05) : theme.cardColor),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: found
                                  ? theme.dividerColor.withOpacity(0.1)
                                  : theme.dividerColor.withOpacity(0.2)
                          ),
                          boxShadow: found ? [] : [
                            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: found
                            ? Icon(Icons.check_rounded, color: colorScheme.primary.withOpacity(0.5))
                            : Text("$num", style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ) : Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text("START FOCUS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}