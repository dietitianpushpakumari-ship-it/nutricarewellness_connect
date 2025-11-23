import 'package:flutter/material.dart';

class SleepDebtSheet extends StatefulWidget {
  const SleepDebtSheet({super.key});

  @override
  State<SleepDebtSheet> createState() => _SleepDebtSheetState();
}

class _SleepDebtSheetState extends State<SleepDebtSheet> {
  double _ideal = 8;
  double _actual = 6;

  @override
  Widget build(BuildContext context) {
    final debt = _ideal - _actual;
    final weeklyDebt = debt * 7;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          const Text("Sleep Debt Calculator", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildSlider("Ideal Sleep", _ideal, (v) => setState(() => _ideal = v)),
          _buildSlider("Actual Sleep", _actual, (v) => setState(() => _actual = v)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const Text("You owe your body:", style: TextStyle(color: Colors.red)),
                Text("${weeklyDebt.toStringAsFixed(1)} hours", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.red)),
                const Text("of sleep this week.", style: TextStyle(color: Colors.red)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double val, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: ${val.toStringAsFixed(1)} hrs", style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: val, min: 4, max: 12, divisions: 16, onChanged: onChanged, activeColor: Colors.indigo),
      ],
    );
  }
}