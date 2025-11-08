import 'package:flutter/material.dart';

// --- (StatSlider helper widget remains the same) ---
class StatSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final Color activeColor;

  const StatSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: activeColor, size: 28),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
              ),
              const Spacer(),
              Text(
                '${value.round()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: value.round().toString(),
            onChanged: onChanged,
            activeColor: activeColor,
            inactiveColor: activeColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

// --- Main Widget to Host All Trackers (MODIFIED) ---
class ClientMoodEnergySlider extends StatefulWidget {
  // 🎯 1. Add initial values and callbacks to the constructor
  final int? initialSleepRating;
  final int? initialEnergyRating;
  final int? initialMoodRating;
  final ValueChanged<int> onSleepChanged;
  final ValueChanged<int> onEnergyChanged;
  final ValueChanged<int> onMoodChanged;

  const ClientMoodEnergySlider({
    super.key,
    this.initialSleepRating,
    this.initialEnergyRating,
    this.initialMoodRating,
    required this.onSleepChanged,
    required this.onEnergyChanged,
    required this.onMoodChanged,
  });

  @override
  State<ClientMoodEnergySlider> createState() => _ClientMoodEnergySliderState();
}

class _ClientMoodEnergySliderState extends State<ClientMoodEnergySlider> {
  // 2. State now holds the double values required by the Slider
  double _sleepRating = 3.0;
  double _energyRating = 3.0;
  double _moodRating = 3.0;

  @override
  void initState() {
    super.initState();
    // 3. Initialize state from the parent widget
    _sleepRating = widget.initialSleepRating?.toDouble() ?? 3.0;
    _energyRating = widget.initialEnergyRating?.toDouble() ?? 3.0;
    _moodRating = widget.initialMoodRating?.toDouble() ?? 3.0;
  }

  IconData _getBatteryIcon(double energy) {
    // ... (omitted, no change)
    final rating = energy.round();
    switch (rating) {
      case 1: return Icons.battery_alert;
      case 2: return Icons.battery_charging_full;
      case 3: return Icons.battery_std;
      case 4: return Icons.battery_full;
      case 5: return Icons.flash_on;
      default: return Icons.battery_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Daily Check-in',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Divider(),

          // 1. Sleep Slider
          StatSlider(
            label: 'Sleep Quality',
            icon: Icons.bed,
            value: _sleepRating,
            activeColor: Colors.indigo,
            onChanged: (newValue) {
              setState(() => _sleepRating = newValue);
              // 🎯 4. Report the change back to the parent
              widget.onSleepChanged(newValue.round());
            },
          ),

          // 2. Energy Slider
          StatSlider(
            label: 'Energy Level',
            icon: _getBatteryIcon(_energyRating),
            value: _energyRating,
            activeColor: Colors.green.shade600,
            onChanged: (newValue) {
              setState(() => _energyRating = newValue);
              // 🎯 4. Report the change back to the parent
              widget.onEnergyChanged(newValue.round());
            },
          ),

          // 3. Mood Slider
          StatSlider(
            label: 'Overall Mood',
            icon: Icons.mood,
            value: _moodRating,
            activeColor: Colors.amber.shade700,
            onChanged: (newValue) {
              setState(() => _moodRating = newValue);
              // 🎯 4. Report the change back to the parent
              widget.onMoodChanged(newValue.round());
            },
          ),
        ],
      ),
    );
  }
}