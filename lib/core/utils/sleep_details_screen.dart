import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/localization/localization_extension.dart';
import 'package:nutricare_connect/core/utils/smart_dialogs.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class SleepDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;

  const SleepDetailSheet({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
  });

  @override
  ConsumerState<SleepDetailSheet> createState() => _SleepDetailSheetState();
}

class _SleepDetailSheetState extends ConsumerState<SleepDetailSheet> {
  // Default times if nothing saved
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 6, minute: 30);

  // State Variables
  int _sleepQuality = 3;
  int _interruptions = 0;
  int _energyRating = 3;
  int _moodRating = 3;

  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.dailyLog != null) {
      final log = widget.dailyLog!;

      // 🎯 FIX: Convert to Local Time to ensure correct TimeOfDay
      if (log.sleepTime != null) {
        _sleepTime = TimeOfDay.fromDateTime(log.sleepTime!.toLocal());
      }
      if (log.wakeTime != null) {
        _wakeTime = TimeOfDay.fromDateTime(log.wakeTime!.toLocal());
      }

      // Load other metrics if they exist, otherwise keep defaults
      _sleepQuality = log.sleepQualityRating ?? 3;
      _interruptions = log.sleepInterruptions ?? 0;
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

  // --- Logic ---
  Duration _calculateDuration() {
    // 🎯 FIX: Use the selected date, not 'now'
    final date = widget.notifier.state.selectedDate;

    DateTime sleepDt = DateTime(date.year, date.month, date.day, _sleepTime.hour, _sleepTime.minute);
    DateTime wakeDt = DateTime(date.year, date.month, date.day, _wakeTime.hour, _wakeTime.minute);

    // If wake time is before sleep time, assume wake is next day
    if (wakeDt.isBefore(sleepDt)) {
      wakeDt = wakeDt.add(const Duration(days: 1));
    }
    return wakeDt.difference(sleepDt);
  }

  Future<void> _saveSleepLog() async {
    setState(() => _isSaving = true);

    try {
      final duration = _calculateDuration();
      final double totalHours = duration.inMinutes / 60.0;

      // Simple Score Logic
      int baseScore = (totalHours >= 7 ? 50 : 30) - (_interruptions * 5);
      int qualityScore = _sleepQuality * 4;
      int wellnessScore = (_energyRating * 3) + (_moodRating * 3);
      int totalScore = (baseScore + qualityScore + wellnessScore).clamp(0, 100);

      final date = widget.notifier.state.selectedDate;

      // Construct DateTimes for saving
      DateTime sleepDt = DateTime(date.year, date.month, date.day, _sleepTime.hour, _sleepTime.minute);
      DateTime wakeDt = DateTime(date.year, date.month, date.day, _wakeTime.hour, _wakeTime.minute);

      // Adjust date if sleep crossed midnight
      if (wakeDt.isBefore(sleepDt)) {
        wakeDt = wakeDt.add(const Duration(days: 1));
      }

      // Create/Update Log
      final logToSave = widget.dailyLog ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: date,
      );

      final updatedLog = logToSave.copyWith(
        sleepQualityRating: _sleepQuality,
        sleepTime: sleepDt,
        wakeTime: wakeDt,
        sleepInterruptions: _interruptions,
        totalSleepDurationHours: totalHours,
        sleepScore: totalScore,
        energyLevelRating: _energyRating,
        moodLevelRating: _moodRating,
        notesAndFeelings: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // 1. Save to Firestore
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      // 🎯 2. FIX: Force Refresh of the Diet Plan Provider
      // This ensures the HomeScreen widgets (like the Sleep Card) update instantly.
      // We assume 'widget.activePlan.clientId' is the client ID.
      await widget.notifier.loadInitialData(date);

      if (mounted) {
        Navigator.pop(context);
        showContextualSuccessDialog(context, 'sleep');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(bool isSleep) async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: isSleep ? _sleepTime : _wakeTime,
    );
    if (newTime != null) {
      setState(() {
        if (isSleep) _sleepTime = newTime;
        else _wakeTime = newTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    const bgDark = Color(0xFF1A2138);
    const cardDark = Color(0xFF2E3A59);
    const accentColor = Color(0xFF8DAEF2);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 1. Header Summary
                    Text(context.tr("lbl_sleep_duration"), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text("$hours", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        const Text("h", style: TextStyle(color: accentColor, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Text("$minutes", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        const Text("m", style: TextStyle(color: accentColor, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 2. Time Pickers
                    Row(
                      children: [
                        Expanded(child: _buildTimeCard(context.tr("lbl_bedtime"), _sleepTime, Icons.bedtime, () => _pickTime(true), cardDark, accentColor)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTimeCard(context.tr("lbl_wake_up"), _wakeTime, Icons.wb_sunny, () => _pickTime(false), cardDark, Colors.orange.shade300)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 3. Quality & Interruptions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [
                          _buildRatingRow(
                              label: context.tr("lbl_sleep_quality"),
                              icon: Icons.star,
                              color: Colors.amber,
                              value: _sleepQuality,
                              onChanged: (v) => setState(() => _sleepQuality = v),
                              isDark: true
                          ),
                          const Divider(color: Colors.white10, height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(context.tr("lbl_interruption"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              Container(
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(30)),
                                child: Row(
                                  children: [
                                    IconButton(icon: const Icon(Icons.remove, color: Colors.white70), onPressed: () => setState(() => _interruptions = (_interruptions - 1).clamp(0, 10))),
                                    Text("$_interruptions", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton(icon: const Icon(Icons.add, color: Colors.white70), onPressed: () => setState(() => _interruptions = (_interruptions + 1).clamp(0, 10))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. Energy & Mood (Light Card)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr("lbl_energy_and_mood"), style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                          const Divider(),
                          _buildRatingRow(label: "  ${context.tr("lbl_energy")}", icon: Icons.bolt, color: Colors.orange, value: _energyRating, onChanged: (v) => setState(() => _energyRating = v), isDark: false),
                          _buildRatingRow(label: "  ${context.tr("lbl_mood")}", icon: Icons.sentiment_very_satisfied, color: Colors.green, value: _moodRating, onChanged: (v) => setState(() => _moodRating = v), isDark: false),
                          const SizedBox(height: 20),
                          Text(context.tr("lbl_journal"), style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: context.tr("hint_any_stress"),
                              filled: true, fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Save Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSleepLog,
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: bgDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isSaving ? const CircularProgressIndicator(color: bgDark) : Text(context.tr("sleep_btn_save"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(String label, TimeOfDay time, IconData icon, VoidCallback onTap, Color bgColor, Color iconColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(time.format(context), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow({required String label, required IconData icon, required Color color, required int value, required ValueChanged<int> onChanged, bool isDark = false}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final activeBg = isDark ? color.withOpacity(0.2) : color.withOpacity(0.1);
    final inactiveBg = isDark ? Colors.white10 : Colors.grey.shade100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 16)), const Spacer(), Text("$value/5", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey))]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final int rating = index + 1;
              final bool isSelected = rating <= value;
              return GestureDetector(
                onTap: () => onChanged(rating),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isSelected ? activeBg : inactiveBg, shape: BoxShape.circle),
                  child: Icon(isSelected ? icon : _getOutlineIcon(icon), color: isSelected ? color : (isDark ? Colors.white38 : Colors.grey.shade400), size: 28),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  IconData _getOutlineIcon(IconData source) {
    if (source == Icons.star) return Icons.star_border;
    if (source == Icons.bolt) return Icons.bolt_outlined;
    if (source == Icons.sentiment_very_satisfied) return Icons.sentiment_neutral;
    if (source == Icons.bedtime) return Icons.bedtime_outlined;
    return source;
  }
}