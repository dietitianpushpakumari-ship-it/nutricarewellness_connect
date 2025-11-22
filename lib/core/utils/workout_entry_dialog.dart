import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkoutEntryDialog extends StatefulWidget {
  final Function(String type, int duration, int calories) onSave;

  const WorkoutEntryDialog({super.key, required this.onSave});

  @override
  State<WorkoutEntryDialog> createState() => _WorkoutEntryDialogState();
}

class _WorkoutEntryDialogState extends State<WorkoutEntryDialog> {
  String _selectedActivity = 'Yoga';
  double _duration = 30; // minutes
  String _intensity = 'Moderate';

  // MET values (Metabolic Equivalent of Task) approx
  final Map<String, double> _activities = {
    'Yoga': 3.0,
    'Weight Training': 4.0,
    'HIIT / Cardio': 8.0,
    'Cycling': 6.0,
    'Swimming': 7.0,
    'Pilates': 3.5,
    'Dance': 5.0,
  };

  int get _estimatedCalories {
    // Formula: MET * 3.5 * weight(kg) / 200 * duration
    // Simplified: MET * duration * 0.1 * 70kg (avg user)
    // Adjusting multiplier for realism without weight data
    double multiplier = 1.0;
    if (_intensity == 'Low') multiplier = 0.8;
    if (_intensity == 'High') multiplier = 1.2;

    return (_activities[_selectedActivity]! * _duration * 5 * multiplier).round();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text("Log Workout"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Activity Dropdown
          DropdownButtonFormField<String>(
            value: _selectedActivity,
            decoration: const InputDecoration(
              labelText: "Activity Type",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              prefixIcon: Icon(Icons.fitness_center),
            ),
            items: _activities.keys.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) => setState(() => _selectedActivity = newValue!),
          ),
          const SizedBox(height: 16),

          // 2. Duration Slider
          Text("Duration: ${_duration.round()} min", style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _duration,
            min: 5,
            max: 180,
            divisions: 35,
            activeColor: colorScheme.primary,
            label: "${_duration.round()} min",
            onChanged: (val) => setState(() => _duration = val),
          ),

          // 3. Intensity Selector
          const Text("Intensity", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: ['Low', 'Moderate', 'High'].map((level) {
              final isSelected = _intensity == level;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _intensity = level),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? colorScheme.primary : Colors.grey.shade300),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 4. Calorie Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  "Est. Burn: $_estimatedCalories kcal",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_selectedActivity, _duration.round(), _estimatedCalories);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text("Log Workout"),
        ),
      ],
    );
  }
}