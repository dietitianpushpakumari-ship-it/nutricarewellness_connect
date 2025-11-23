import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class WorryShredderSheet extends StatefulWidget {
  const WorryShredderSheet({super.key});

  @override
  State<WorryShredderSheet> createState() => _WorryShredderSheetState();
}

class _WorryShredderSheetState extends State<WorryShredderSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isShredding = false;
  final _audio = WellnessAudioService();

  void _shred() async {
    if (_controller.text.isEmpty) return;
    FocusScope.of(context).unfocus();

    // 🎯 PLAY SOUND
    _audio.playCrumple();
    _audio.hapticHeavy();

    setState(() => _isShredding = true);

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Worry released! 🍃")));
    }
  }
  // ... (Rest of the build method remains exactly as before)
  // Just keep the build() method from the previous WorryShredderSheet code I gave you.
  // The key change is inside _shred() above.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFF222222), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          const Text("Worry Shredder", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Write it down. Let it go.", style: TextStyle(color: Colors.grey)),
          const Spacer(),

          if (_isShredding)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 0.0),
              duration: const Duration(seconds: 2),
              builder: (context, val, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - val) * 200),
                  child: Opacity(
                    opacity: val,
                    child: Transform.scale(
                      scaleX: val,
                      child: child,
                    ),
                  ),
                );
              },
              child: _buildPaperCard(),
            )
          else
            _buildPaperCard(),

          const Spacer(),

          if (!_isShredding)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _shred,
                icon: const Icon(Icons.delete_forever),
                label: const Text("Shred This Thought"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildPaperCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 300,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: TextField(
        controller: _controller,
        maxLines: 10,
        decoration: const InputDecoration(
          hintText: "I am worried about...",
          border: InputBorder.none,
        ),
      ),
    );
  }
}