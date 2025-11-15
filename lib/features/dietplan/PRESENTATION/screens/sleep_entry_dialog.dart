// lib/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart

// -------------------------------------------------------------------------
// --- 🎯 NEW: SLEEP-ONLY ENTRY DIALOG ---
// -------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class SleepEntryDialog extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyMetricsLog; // Existing log for pre-filling

  const SleepEntryDialog({
    required this.notifier,
    required this.activePlan,
    this.dailyMetricsLog,
  });

  @override
  ConsumerState<SleepEntryDialog> createState() => _SleepEntryDialogState();
}

class _SleepEntryDialogState extends ConsumerState<SleepEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _interruptionsController = TextEditingController();

  TimeOfDay? _sleepTime;
  TimeOfDay? _wakeTime;
  int? _sleepQualityRating; // Use the slider value

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data
    if (widget.dailyMetricsLog != null) {
      final log = widget.dailyMetricsLog!;
      _interruptionsController.text = log.sleepInterruptions?.toString() ?? '0';
      _sleepQualityRating = log.sleepQualityRating;
      _sleepTime = log.sleepTime != null ? TimeOfDay.fromDateTime(log.sleepTime!) : null;
      _wakeTime = log.wakeTime != null ? TimeOfDay.fromDateTime(log.wakeTime!) : null;
    } else {
      // Set defaults
      _interruptionsController.text = '0';
      _sleepQualityRating = 3; // Default to 3 stars
    }
  }

  @override
  void dispose() {
    _interruptionsController.dispose();
    super.dispose();
  }

  // --- Sleep Calculation Logic ---
  Map<String, dynamic> _calculateSleepData() {
    if (_sleepTime == null || _wakeTime == null) {
      return { 'duration': 0.0, 'score': 0 };
    }

    final date = widget.notifier.state.selectedDate;

    DateTime sleepDateTime = DateTime(date.year, date.month, date.day, _sleepTime!.hour, _sleepTime!.minute);
    DateTime wakeDateTime = DateTime(date.year, date.month, date.day, _wakeTime!.hour, _wakeTime!.minute);

    // Handle overnight sleep (e.g., Sleep 10 PM, Wake 6 AM)
    if (wakeDateTime.isBefore(sleepDateTime) || wakeDateTime.isAtSameMomentAs(sleepDateTime)) {
      wakeDateTime = wakeDateTime.add(const Duration(days: 1));
    }

    final Duration duration = wakeDateTime.difference(sleepDateTime);
    final double totalHours = duration.inMinutes / 60.0;

    // --- Simple Sleep Score Calculation (out of 100) ---
    int score = 0;
    if (totalHours >= 7 && totalHours <= 9) score += 50; // Ideal duration
    else if (totalHours > 6 && totalHours < 10) score += 30; // Good
    else score += 10; // Poor

    score += (_sleepQualityRating ?? 0) * 6; // 5 stars = 30 pts

    final int interruptions = int.tryParse(_interruptionsController.text) ?? 0;
    if (interruptions == 0) score += 20;
    else if (interruptions <= 2) score += 10;

    return {
      'duration': totalHours,
      'score': score.clamp(0, 100),
      'sleepTime': sleepDateTime,
      'wakeTime': wakeDateTime,
      'interruptions': interruptions,
    };
  }

  // --- Submission Handler ---
  Future<void> _handleSubmission() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sleepTime == null || _wakeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a sleep and wake time.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final sleepData = _calculateSleepData();

      // Find or create the base log object
      final logToSave = widget.dailyMetricsLog ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: widget.notifier.state.selectedDate,
      );

      // We update the model using copyWith, ONLY changing sleep fields
      final updatedLog = logToSave.copyWith(
        sleepQualityRating: _sleepQualityRating,
        sleepTime: sleepData['sleepTime'] as DateTime?,
        wakeTime: sleepData['wakeTime'] as DateTime?,
        sleepInterruptions: sleepData['interruptions'] as int?,
        totalSleepDurationHours: sleepData['duration'] as double?,
        sleepScore: sleepData['score'] as int?,
      );

      // Save using the existing createOrUpdateLog logic
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep log saved!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save sleep log: ${e.toString().split(':').last.trim()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log Sleep for ${DateFormat.yMMMd().format(widget.notifier.state.selectedDate)}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimePicker(
                context,
                label: 'Sleep Time (Last Night)',
                time: _sleepTime,
                onTimePicked: (newTime) => setState(() => _sleepTime = newTime),
              ),
              _buildTimePicker(
                context,
                label: 'Wake-up Time (This Morning)',
                time: _wakeTime,
                onTimePicked: (newTime) => setState(() => _wakeTime = newTime),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interruptionsController,
                decoration: const InputDecoration(
                  labelText: 'Sleep Interruptions',
                  hintText: 'e.g., 0, 1, 2...',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter 0 or more.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Using the star rating helper
              _buildStarRatingField('Sleep Quality', Icons.nights_stay, _sleepQualityRating, (val) => setState(() => _sleepQualityRating = val)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSubmission,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Sleep'),
        ),
      ],
    );
  }

  // --- Helper: Time Picker Tile ---
  Widget _buildTimePicker(BuildContext context, {required String label, TimeOfDay? time, required ValueChanged<TimeOfDay> onTimePicked}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(label.contains('Sleep') ? Icons.bedtime : Icons.wb_sunny, color: Theme.of(context).colorScheme.secondary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Text(
        time?.format(context) ?? 'Not Set',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      onTap: () async {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        if (pickedTime != null) {
          onTimePicked(pickedTime);
        }
      },
    );
  }

  // --- Helper: Star Rating ---
  Widget _buildStarRatingField(String label, IconData icon, int? currentValue, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 10.0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4.0,
          children: List.generate(5, (index) {
            final rating = index + 1;
            return IconButton(
              icon: Icon(
                currentValue != null && rating <= currentValue ? Icons.star : Icons.star_border,
                color: Colors.amber.shade700,
                size: 36,
              ),
              onPressed: () => onChanged(rating),
            );
          }),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}