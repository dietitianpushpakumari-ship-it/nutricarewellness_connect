// -------------------------------------------------------------------------
// --- 4. NEW: DAILY WELLNESS ENTRY DIALOG (Star Ratings & Ranges) ---
// -------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_mood_energy_slider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/helpers/constants.dart';

class DailyWellnessEntryDialog extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyMetricsLog; // Existing log for pre-filling

  const DailyWellnessEntryDialog({
    required this.notifier,
    required this.activePlan,
    this.dailyMetricsLog,
  });

  @override
  ConsumerState<DailyWellnessEntryDialog> createState() => _DailyWellnessEntryDialogState();
}

class _DailyWellnessEntryDialogState extends ConsumerState<DailyWellnessEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  // 🎯 Removed: _hydrationController, _stepsController
  final _notesController = TextEditingController();

  // 🎯 NEW: State variables for the selected values
  int? _sleepRating;
  int? _energyRating;
  int? _moodRating;
  double? _hydrationValue; // Stores 1.25, 1.75, etc.
  int? _stepValue; // Stores 1000, 3000, etc.

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data
    if (widget.dailyMetricsLog != null) {
      _initializeForEdit(widget.dailyMetricsLog!);
    }
  }

  void _initializeForEdit(ClientLogModel log) {
    // 🎯 Set the dropdown values based on the stored numerical value
    _hydrationValue = log.hydrationLiters;
    _stepValue = log.stepCount;
    _notesController.text = log.notesAndFeelings ?? '';

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
      // 🎯 Find or create the base log object (Synthetic Log for Daily Check)
      final logToSave = widget.dailyMetricsLog ?? ClientLogModel(
        id: '', // Empty ID for creation
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK', // Unique identifier
        actualFoodEaten: ['Daily Wellness Data'], //// Constant value
        date: widget.notifier.state.selectedDate,
      );

      // 🎯 We update the model using copyWith
      final updatedLog = logToSave.copyWith(
        sleepQualityRating: _sleepRating,
        hydrationLiters: _hydrationValue, // Pass the numerical value
        stepCount: _stepValue, // Pass the numerical value
        energyLevelRating: _energyRating,
        moodLevelRating: _moodRating,
        notesAndFeelings: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Save using the existing createOrUpdateLog logic (assumed correct)
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily metrics saved!')));
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save metrics: ${e.toString().split(':').last.trim()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }


  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Daily Wellness Check'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CORE METRICS ---
              ClientMoodEnergySlider(
                initialSleepRating: _sleepRating,
                initialEnergyRating: _energyRating,
                initialMoodRating: _moodRating,
                onSleepChanged: (val) => setState(() => _sleepRating = val),
                onEnergyChanged: (val) => setState(() => _energyRating = val),
                onMoodChanged: (val) => setState(() => _moodRating = val),
              ),
              // 🎯 1. Sleep Quality (Star Rating)
             // _buildStarRatingField('Sleep Quality', Icons.nights_stay, _sleepRating, (val) => setState(() => _sleepRating = val)),

              // 🎯 2. Hydration (Range Dropdown)
              _buildRangeDropdown<double>(
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
              ),
            ],
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

  // --- 🎯 WIDGET HELPER 1: Star Rating ---
// ... (rest of the dialog code remains the same) ...
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
            child: Text(entry.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: onChanged,
        hint: const Text('Select a range'),
      ),
    );
  }
}