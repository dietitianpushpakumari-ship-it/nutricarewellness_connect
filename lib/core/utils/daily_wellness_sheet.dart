import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_mood_energy_slider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class DailyWellnessSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;

  const DailyWellnessSheet({
    super.key,
    required this.notifier,
    required this.activePlan,
    this.dailyLog,
  });

  @override
  ConsumerState<DailyWellnessSheet> createState() => _DailyWellnessSheetState();
}

class _DailyWellnessSheetState extends ConsumerState<DailyWellnessSheet> {
  final TextEditingController _notesController = TextEditingController();

  int _sleepRating = 3;
  int _energyRating = 3;
  int _moodRating = 3;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.dailyLog != null) {
      final log = widget.dailyLog!;
      _sleepRating = log.sleepQualityRating ?? 3;
      _energyRating = log.energyLevelRating ?? 3;
      _moodRating = log.moodLevelRating ?? 3;
      _notesController.text = log.notesAndFeelings ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveJournal() async {
    setState(() => _isSaving = true);
    try {
      final logToSave = widget.dailyLog ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: widget.notifier.state.selectedDate,
      );

      final updatedLog = logToSave.copyWith(
        sleepQualityRating: _sleepRating,
        energyLevelRating: _energyRating,
        moodLevelRating: _moodRating,
        notesAndFeelings: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Journal Saved!"),
            backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d').format(widget.notifier.state.selectedDate);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // 1. Handle & Header
            const SizedBox(height: 16),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Daily Check-in", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(dateStr, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFFF4E5), // Soft Orange
                    child: Icon(Icons.wb_sunny_rounded, color: Colors.orange),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
      
            // 2. Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. The Sliders
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClientMoodEnergySlider(
                        initialSleepRating: _sleepRating,
                        initialEnergyRating: _energyRating,
                        initialMoodRating: _moodRating,
                        onSleepChanged: (v) => setState(() => _sleepRating = v),
                        onEnergyChanged: (v) => setState(() => _energyRating = v),
                        onMoodChanged: (v) => setState(() => _moodRating = v),
                      ),
                    ),
                    const SizedBox(height: 30),
      
                    // B. The Journal
                    const Text("Journal & Reflections", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEFCE8), // Light Yellow Note color
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.yellow.shade200),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 6,
                        style: const TextStyle(height: 1.5, fontSize: 16, color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: "How are you feeling today? Any cravings, stress, or wins?",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      
            // 3. Save Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveJournal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Journal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}