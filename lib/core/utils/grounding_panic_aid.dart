import 'package:flutter/material.dart';

class GroundingGameSheet extends StatefulWidget {
  const GroundingGameSheet({super.key});

  @override
  State<GroundingGameSheet> createState() => _GroundingGameSheetState();
}

class _GroundingGameSheetState extends State<GroundingGameSheet> {
  int _step = 5;
  final Map<int, String> _instructions = {
    5: "Look around and find 5 things you can SEE.",
    4: "Find 4 things you can TOUCH.",
    3: "Listen for 3 things you can HEAR.",
    2: "Identify 2 things you can SMELL.",
    1: "Name 1 thing you can TASTE.",
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30))
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Grounding Technique", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Column(
              key: ValueKey(_step),
              children: [
                Text("$_step", style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
                const SizedBox(height: 20),
                Text(_instructions[_step]!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              if (_step > 1) setState(() => _step--);
              else Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            child: Text(_step > 1 ? "Next Step" : "I Feel Better"),
          )
        ],
      ),
    );
  }
}