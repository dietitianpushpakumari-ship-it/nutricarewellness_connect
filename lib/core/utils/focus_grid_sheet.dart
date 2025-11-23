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
  int _nextNumber = 1;
  int _seconds = 0;
  Timer? _timer;
  bool _isGameOn = false;
  final _audio = WellnessAudioService();

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    _grid = List.generate(25, (index) => index + 1)..shuffle();
    _nextNumber = 1;
    _seconds = 0;
    _isGameOn = false;
    _timer?.cancel();
    setState(() {});
  }

  void _startGame() {
    setState(() => _isGameOn = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) => setState(() => _seconds++));
  }

  void _onTap(int number) {
    if (!_isGameOn) return;
    if (number == _nextNumber) {
      setState(() => _nextNumber++);

      // 🎯 Click Sound
      _audio.playClick();

      if (_nextNumber > 25) {
        _timer?.cancel();
        // 🎯 Win Sound
        _audio.playSuccess();
        _showWinDialog();
      }
    } else {
      // 🎯 Error Haptic
      _audio.hapticMedium();
    }
  }

  void _showWinDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Focus Sharp!"),
      content: Text("Time: $_seconds seconds"),
      actions: [TextButton(onPressed: () { Navigator.pop(context); _resetGame(); }, child: const Text("Retry"))],
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          const Text("Focus Grid (Schulte Table)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Tap 1 to 25 as fast as possible", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Text("Time: $_seconds s", style: const TextStyle(fontSize: 24, color: Colors.blue)),
          const SizedBox(height: 20),

          _isGameOn
              ? Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: 25,
              itemBuilder: (context, index) {
                final num = _grid[index];
                final isFound = num < _nextNumber;
                return GestureDetector(
                  onTap: () => _onTap(num),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFound ? Colors.grey.shade200 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isFound
                        ? const Icon(Icons.check, color: Colors.grey)
                        : Text("$num", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          )
              : Center(
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
              child: const Text("START", style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
}