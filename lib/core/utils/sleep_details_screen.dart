import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 30); // Default 10:30 PM
  TimeOfDay _wakeTime = const TimeOfDay(hour: 6, minute: 30);   // Default 6:30 AM
  int _sleepQuality = 3;
  int _interruptions = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.dailyLog != null) {
      final log = widget.dailyLog!;
      if (log.sleepTime != null) _sleepTime = TimeOfDay.fromDateTime(log.sleepTime!);
      if (log.wakeTime != null) _wakeTime = TimeOfDay.fromDateTime(log.wakeTime!);
      _sleepQuality = log.sleepQualityRating ?? 3;
      _interruptions = log.sleepInterruptions ?? 0;
    }
  }

  // --- Logic ---
  Duration _calculateDuration() {
    final now = DateTime.now();
    DateTime sleepDt = DateTime(now.year, now.month, now.day, _sleepTime.hour, _sleepTime.minute);
    DateTime wakeDt = DateTime(now.year, now.month, now.day, _wakeTime.hour, _wakeTime.minute);

    // If wake time is earlier than sleep time, assume next day
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

      // Simple Score Calc
      int score = (_sleepQuality * 10) + (totalHours >= 7 ? 50 : 30) - (_interruptions * 5);

      final date = widget.notifier.state.selectedDate;
      // Reconstruct DateTimes for storage
      DateTime sleepDt = DateTime(date.year, date.month, date.day, _sleepTime.hour, _sleepTime.minute);
      DateTime wakeDt = DateTime(date.year, date.month, date.day, _wakeTime.hour, _wakeTime.minute);
      if (wakeDt.isBefore(sleepDt)) wakeDt = wakeDt.add(const Duration(days: 1));

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
        sleepScore: score.clamp(0, 100),
      );

      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        Navigator.pop(context);
        showContextualSuccessDialog(context, 'sleep');
      }
    } catch (e) {
      // Handle error
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

    // Theme Colors
    const bgDark = Color(0xFF1A2138); // Deep Night Blue
    const cardDark = Color(0xFF2E3A59);
    const accentColor = Color(0xFF8DAEF2); // Soft Moon Blue

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
      
            // 1. Header Summary
            const Text("Sleep Duration", style: TextStyle(color: Colors.white70, fontSize: 14)),
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
      
            // 2. Time Pickers Row
            Row(
              children: [
                Expanded(child: _buildTimeCard("Bedtime", _sleepTime, Icons.bedtime, () => _pickTime(true), cardDark, accentColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeCard("Wake Up", _wakeTime, Icons.wb_sunny, () => _pickTime(false), cardDark, Colors.orange.shade300)),
              ],
            ),
            const SizedBox(height: 30),
      
            // 3. Quality & Interruptions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Stars
                  const Text("Sleep Quality", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _sleepQuality = index + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < _sleepQuality ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  const Divider(color: Colors.white10, height: 30),
      
                  // Interruptions Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Interruptions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white70),
                              onPressed: () => setState(() => _interruptions = (_interruptions - 1).clamp(0, 10)),
                            ),
                            Text("$_interruptions", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white70),
                              onPressed: () => setState(() => _interruptions = (_interruptions + 1).clamp(0, 10)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      
            const Spacer(),
      
            // 4. Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSleepLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: bgDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: bgDark)
                    : const Text("Save Sleep Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}