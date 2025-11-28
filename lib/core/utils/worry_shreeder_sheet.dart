import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class WorryShredderSheet extends StatefulWidget {
  const WorryShredderSheet({super.key});

  @override
  State<WorryShredderSheet> createState() => _WorryShredderSheetState();
}

class _WorryShredderSheetState extends State<WorryShredderSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isShredding = false;
  final _audio = WellnessAudioService();

  late AnimationController _shredController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _shredController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _slideAnimation = Tween<double>(begin: 0, end: 300).animate(
      CurvedAnimation(parent: _shredController, curve: Curves.easeIn),
    );

    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _shredController, curve: const Interval(0.5, 1.0)),
    );
  }

  void _shred() async {
    if (_controller.text.isEmpty) return;
    FocusScope.of(context).unfocus();

    _audio.playCrumple(); // Ensure you have a crumple sound or noise
    _audio.hapticHeavy();

    setState(() => _isShredding = true);
    await _shredController.forward();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Worry released to the void. 🍃"), backgroundColor: Colors.black87)
      );
    }
  }

  @override
  void dispose() {
    _shredController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF121212), // Deep Void Black
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 30),
      
            const Text("The Worry Shredder", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const Text("Write it down. Watch it disappear.", style: TextStyle(color: Colors.white54)),
            const Spacer(),
      
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // The "Shredder" Mouth
                if (_isShredding)
                  Positioned(
                    top: 280, // Just below the paper
                    child: Container(
                      width: 320, height: 20,
                      decoration: BoxDecoration(
                          boxShadow: [BoxShadow(color: Colors.black, blurRadius: 20, spreadRadius: 10)]
                      ),
                    ),
                  ),
      
                // The Paper
                AnimatedBuilder(
                  animation: _shredController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    height: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDE7), // Paper Yellow
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(children: [const Spacer(), Icon(Icons.push_pin, color: Colors.red.shade800, size: 20), const Spacer()]),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: 10,
                            style: const TextStyle(color: Colors.black87, fontFamily: 'Courier', fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: "I am worried about...",
                              hintStyle: TextStyle(color: Colors.black38),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      
            const Spacer(),
      
            if (!_isShredding)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _shred,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("SHRED THIS THOUGHT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}