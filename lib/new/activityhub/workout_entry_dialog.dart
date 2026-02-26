import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkoutEntrySheet extends StatefulWidget {
  final Function(String type, int duration, int calories) onSave;

  const WorkoutEntrySheet({super.key, required this.onSave});

  @override
  State<WorkoutEntrySheet> createState() => _WorkoutEntrySheetState();
}

class _WorkoutEntrySheetState extends State<WorkoutEntrySheet> {
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
    'Walking': Icons.directions_walk_rounded,
    'Running': Icons.directions_run_rounded,
    'Cycling': Icons.directions_bike_rounded,
    'Yoga': Icons.self_improvement_rounded,
    'Gym': Icons.fitness_center_rounded,
    'Swimming': Icons.pool_rounded,
    'Sports': Icons.sports_basketball_rounded,
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
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🎯 FIXED: Use sheer glass instead of opaque grey for dark mode
    final glassFillColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // 🎨 Themed Background
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.1))),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5), // 🎨 Themed Icon Bg
                      shape: BoxShape.circle
                  ),
                  child: Icon(Icons.local_fire_department_rounded, color: colorScheme.primary), // 🎨 Themed Icon
                ),
                const SizedBox(width: 12),
                Text(
                    "Log Activity",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface) // 🎨 Themed Text
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. Visual Selector
            Text("What did you do?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.hintColor)), // 🎨 Themed Hint
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
                      // 🎯 FIXED: Glass background for inactive pills in dark mode
                      color: isSelected ? colorScheme.primary : glassFillColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            _icons[type],
                            size: 18,
                            color: isSelected ? colorScheme.onPrimary : theme.iconTheme.color?.withOpacity(0.6) // 🎨 Themed Icon
                        ),
                        const SizedBox(width: 8),
                        Text(
                            type,
                            style: TextStyle(
                                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface, // 🎨 Themed Text
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                            )
                        ),
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
                Text("Duration", style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor)), // 🎨 Themed Text
                Text("${_duration.toInt()} min", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)), // 🎨 Themed Text
              ],
            ),
            Slider(
              value: _duration,
              min: 5,
              max: 120,
              divisions: 23,
              activeColor: colorScheme.primary, // 🎨 Themed Slider Active
              inactiveColor: colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5), // 🎨 Themed Slider Inactive
              onChanged: (val) {
                setState(() => _duration = val);
                _updateCalories();
              },
            ),

            // 4. 🎯 THEMED Calories Input
            const SizedBox(height: 10),
            TextField(
              controller: _caloriesCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: "Calories Burned (kcal)",
                labelStyle: TextStyle(color: theme.hintColor),
                prefixIcon: Icon(Icons.local_fire_department_outlined, color: theme.hintColor, size: 22),
                filled: true,
                // 🎯 FIXED: Uses the sheer glass background
                fillColor: glassFillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.5))
                ),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.5))
                ),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.primary, width: 1.5)
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 5. Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text("Cancel", style: TextStyle(color: theme.hintColor)), // 🎨 Themed Text
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
                      backgroundColor: colorScheme.primary, // 🎨 Themed Button
                      foregroundColor: colorScheme.onPrimary,
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