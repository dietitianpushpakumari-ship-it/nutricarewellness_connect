// -------------------------------------------------------------------------
// --- 4. NEW: DAILY WELLNESS ENTRY DIALOG (Star Ratings & Ranges) ---
// -------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_mood_energy_slider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/helpers/constants.dart';

// 🎯 Defines the ranges. The Key is the display text, the Value is what's stored in Firestore.
const Map<String, double> hydrationRanges = {
  "Less than 1 L": 0.5,
  "1 - 1.5 L": 1.25,
  "1.5 - 2 L": 1.75,
  "2 - 2.5 L": 2.25,
  "More than 2.5 L": 3.0,
};

const Map<String, int> stepRanges = {
  "Sedentary (0 - 2k)": 1000,
  "Low Active (2k - 4k)": 3000,
  "Active (4k - 6k)": 5000,
  "Very Active (6k - 10k)": 8000,
  "Athlete (> 10k)": 12000,
};

class DailyWellnessEntryDialog extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyMetricsLog; // Existing log for pre-filling

  const DailyWellnessEntryDialog({
    super.key, // Added super.key
    required this.notifier,
    required this.activePlan,
    this.dailyMetricsLog,
  });

  @override
  ConsumerState<DailyWellnessEntryDialog> createState() => _DailyWellnessEntryDialogState();
}

class _DailyWellnessEntryDialogState extends ConsumerState<DailyWellnessEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  // 🎯 These state variables are the "Single Source of Truth"
  int? _sleepRating;
  int? _energyRating;
  int? _moodRating;
  double? _hydrationValue;
  int? _stepValue;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.dailyMetricsLog != null) {
      _initializeForEdit(widget.dailyMetricsLog!);
    } else {
      // Set defaults for new entry
      _sleepRating = 3;
      _energyRating = 3;
      _moodRating = 3;
    }
  }

  void _initializeForEdit(ClientLogModel log) {
    _hydrationValue = log.hydrationLiters;
    _stepValue = log.stepCount;
    _notesController.text = log.notesAndFeelings ?? '';

    // 🎯 Pass initial values to the state
    _sleepRating = log.sleepQualityRating;
    _energyRating = log.energyLevelRating;
    _moodRating = log.moodLevelRating;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // --- Submission Handler ---
  Future<void> _handleSubmission() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() { _isSaving = true; });

    try {
      final logToSave = widget.dailyMetricsLog ?? ClientLogModel(
        id: '', // Empty ID for creation
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK', // Unique identifier
        // 🎯 CRITICAL FIX: Assign a List<String> instead of a String
        actualFoodEaten: ['Daily Wellness Data'], // ⬅️ THIS IS THE FIX
        date: widget.notifier.state.selectedDate,
      );

      // 🎯 We update the model using copyWith, pulling from our state variables
      final updatedLog = logToSave.copyWith(
        sleepQualityRating: _sleepRating, // 💾 NOW SAVES VALUE
        hydrationLiters: _hydrationValue,
        stepCount: _stepValue,
        energyLevelRating: _energyRating, // 💾 NOW SAVES VALUE
        moodLevelRating: _moodRating,   // 💾 NOW SAVES VALUE
        notesAndFeelings: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Save using the existing createOrUpdateLog logic
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        _showMessage('Daily metrics saved!', isError: false);
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showMessage('Failed to save metrics: ${e.toString().split(':').last.trim()}', isError: true);
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  // 🎯 SnackBar helper
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Daily Wellness Check'),
      // 🎯 Constrain the width of the dialog's content
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9, // Use 90% of screen width
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CORE METRICS ---

                // 🎯 CRITICAL FIX: Wire up the slider to the parent's state
                ClientMoodEnergySlider(
                  initialSleepRating: _sleepRating,
                  initialEnergyRating: _energyRating,
                  initialMoodRating: _moodRating,
                  // 🎯 Callbacks update the parent dialog's state
                  onSleepChanged: (val) => setState(() => _sleepRating = val),
                  onEnergyChanged: (val) => setState(() => _energyRating = val),
                  onMoodChanged: (val) => setState(() => _moodRating = val),
                ),

                // 🎯 2. Hydration (Range Dropdown)
             /*   _buildRangeDropdown<double>(
                  label: 'Hydration Intake',
                  icon: Icons.opacity,
                  currentValue: _hydrationValue,
                  items: hydrationRanges,
                  onChanged: (val) => setState(() => _hydrationValue = val),
                ),

                // 🎯 3. Step Count (Range Dropdown)
                _buildRangeDropdown<int>(
                  label: 'Steps Count',
                  icon: Icons.directions_run,
                  currentValue: _stepValue,
                  items: stepRanges,
                  onChanged: (val) => setState(() => _stepValue = val),
                ),

                // --- NOTES ---
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes on How You Feel (Optional)',
                    hintText: 'e.g., Felt sluggish.',
                    border: OutlineInputBorder(),
                  ),
                ),*/
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSubmission,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Check'),
        ),
      ],
    );
  }

  // --- 🎯 WIDGET HELPER 2: Range Dropdown (Generic) ---
  Widget _buildRangeDropdown<T>({
    required String label,
    required IconData icon,
    required T? currentValue,
    required Map<String, T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        value: currentValue,
        items: items.entries.map((entry) {
          return DropdownMenuItem<T>(
            value: entry.value,
            // 🎯 Fix for potential overflow in dropdown itself
            child: Text(entry.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: onChanged,
        hint: const Text('Select a range'),
      ),
    );
  }
}