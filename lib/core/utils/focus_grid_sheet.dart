import 'dart:async';
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
  int _time = 0;
  bool _playing = false;
  Timer? _timer;
  final _audio = WellnessAudioService();

  void _startGame() {
    setState(() {
      _grid = List.generate(25, (i) => i + 1)..shuffle();
      _next = 1;
      _time = 0;
      _playing = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) => setState(() => _time++));
  }

  void _tap(int n) {
    if (n == _next) {
      _audio.playClick();
      setState(() => _next++);
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
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A2138),
      title: const Text("Focus Master!", style: TextStyle(color: Colors.white)),
      content: Text("Time: $_time seconds", style: const TextStyle(color: Colors.tealAccent, fontSize: 24)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
    ));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 650,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A), // Deep Blue/Black
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const Text("Schulte Table", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Find numbers 1 to 25 in order.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
      
            // Timer Display
            Text("$_time s", style: TextStyle(color: _playing ? Colors.tealAccent : Colors.white10, fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'Monospace')),
      
            const SizedBox(height: 20),
      
            Expanded(
              child: _playing ? GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: 25,
                itemBuilder: (context, index) {
                  final num = _grid[index];
                  final found = num < _next;
                  return GestureDetector(
                    onTap: () => _tap(num),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: found ? Colors.transparent : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: found ? Colors.transparent : Colors.teal.withOpacity(0.3)),
                        boxShadow: found ? [] : [BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 5)],
                      ),
                      child: found
                          ? Icon(Icons.check, color: Colors.white10)
                          : Text("$num", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ) : Center(
                child: ElevatedButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("START FOCUS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}