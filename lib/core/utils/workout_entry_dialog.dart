import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkoutEntryDialog extends StatefulWidget {
  final Function(String type, int duration, int calories) onSave;

  const WorkoutEntryDialog({super.key, required this.onSave});

  @override
  State<WorkoutEntryDialog> createState() => _WorkoutEntryDialogState();
}

class _WorkoutEntryDialogState extends State<WorkoutEntryDialog> {
  String _selectedType = 'Walking';
  double _duration = 30; // Slider value
  final TextEditingController _caloriesCtrl = TextEditingController();

  // 🎯 Smart Calorie Multipliers (approx kcal per minute)
  final Map<String, double> _mets = {
    'Walking': 4.0,
    'Running': 11.0,
    'Cycling': 8.0,
    'Yoga': 3.0,
    'Gym': 6.0,
    'Swimming': 10.0,
    'Sports': 7.0,
  };

  // 🎯 Icons for Visual Selector
  final Map<String, IconData> _icons = {
    'Walking': Icons.directions_walk,
    'Running': Icons.directions_run,
    'Cycling': Icons.directions_bike,
    'Yoga': Icons.self_improvement,
    'Gym': Icons.fitness_center,
    'Swimming': Icons.pool,
    'Sports': Icons.sports_basketball,
  };

  @override
  void initState() {
    super.initState();
    _updateCalories();
  }

  void _updateCalories() {
    // Basic calc: MET * 3.5 * weight(70kg avg) / 200 * minutes
    // Simplified: MET * Duration * 0.8
    final multiplier = _mets[_selectedType] ?? 5.0;
    final est = (multiplier * _duration * 0.8).toInt();
    _caloriesCtrl.text = est.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.local_fire_department, color: Colors.deepOrange),
                ),
                const SizedBox(width: 12),
                const Text("Log Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),

            const SizedBox(height: 24),

            // 2. Visual Selector
            const Text("What did you do?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _icons.keys.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedType = type);
                    _updateCalories();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icons[type], size: 18, color: isSelected ? Colors.white : Colors.grey),
                        const SizedBox(width: 8),
                        Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // 3. Duration Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Duration", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text("${_duration.toInt()} min", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              ],
            ),
            Slider(
              value: _duration,
              min: 5,
              max: 120,
              divisions: 23,
              activeColor: Colors.orange,
              inactiveColor: Colors.orange.shade100,
              onChanged: (val) {
                setState(() => _duration = val);
                _updateCalories();
              },
            ),

            // 4. Calories Input (Editable)
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _caloriesCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: "Calories Burned (kcal)",
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 5. Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final cals = int.tryParse(_caloriesCtrl.text) ?? 0;
                      widget.onSave(_selectedType, _duration.toInt(), cals);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A), // Dark Button
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text("Log Workout", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}