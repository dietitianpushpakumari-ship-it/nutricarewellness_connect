import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/smart_dialogs.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class SleepDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog; // Now represents the Master Record

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

      // Convert to Local Time to ensure correct TimeOfDay
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
    final date = widget.notifier.state.selectedDate;

    DateTime sleepDt = DateTime(date.year, date.month, date.day, _sleepTime.hour, _sleepTime.minute);
    DateTime wakeDt = DateTime(date.year, date.month, date.day, _wakeTime.hour, _wakeTime.minute);

    // If wake time is before sleep time, assume wake is next day
    if (wakeDt.isBefore(sleepDt)) {
      wakeDt = wakeDt.add(const Duration(days: 1));
    }
    return wakeDt.difference(sleepDt);
  }

  // 🎯 ATOMIC SLEEP SAVE LOGIC
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

      if (wakeDt.isBefore(sleepDt)) {
        wakeDt = wakeDt.add(const Duration(days: 1));
      }

      // 🎯 THE NEW ATOMIC MAP
      // We directly target the sleep-related properties on the master record.
      final Map<String, dynamic> sleepUpdateMap = {
        'sleepQualityRating': _sleepQuality,
        'sleepTime': sleepDt.toIso8601String(), // Safe serialization
        'wakeTime': wakeDt.toIso8601String(),   // Safe serialization
        'sleepInterruptions': _interruptions,
        'totalSleepDurationHours': totalHours,
        'sleepScore': totalScore,
        'energyLevelRating': _energyRating,
        'moodLevelRating': _moodRating,
        'notesAndFeelings': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      // 1. 🎯 Save atomically to Firestore via the Notifier
      await widget.notifier.updateDailyRecord(data: sleepUpdateMap);

      if (mounted) {
        Navigator.pop(context);
        showContextualSuccessDialog(context, 'sleep');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving sleep: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(bool isSleep) async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: isSleep ? _sleepTime : _wakeTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final duration = _calculateDuration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    final now = DateTime.now();
    final sleepFormat = DateFormat.jm().format(DateTime(now.year, now.month, now.day, _sleepTime.hour, _sleepTime.minute));
    final wakeFormat = DateFormat.jm().format(DateTime(now.year, now.month, now.day, _wakeTime.hour, _wakeTime.minute));

    // 🎯 Enforce solid premium theme styling
    final solidBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: solidBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Hug content
          children: [
            const SizedBox(height: 12),
            Center(
                child: Container(
                    width: 48, height: 5,
                    decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3)
                    )
                )
            ),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  children: [
                    // 1. DURATION PILL
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time_filled_rounded, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                              "$hours",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface)
                          ),
                          Text(
                              " HR ",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorScheme.primary)
                          ),
                          Text(
                              "$minutes",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface)
                          ),
                          Text(
                              " MIN",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorScheme.primary)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. TIME PICKERS
                    Row(
                      children: [
                        _buildMiniTimeTile("Bedtime", sleepFormat, Icons.bedtime_rounded, () => _pickTime(true), theme, colorScheme.primary, isDark),
                        const SizedBox(width: 12),
                        _buildMiniTimeTile("Wake up", wakeFormat, Icons.wb_sunny_rounded, () => _pickTime(false), theme, Colors.orange, isDark),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. COMBINED QUALITY & INTERRUPTIONS
                    _buildCompactCard(
                      theme: theme,
                      isDark: isDark,
                      child: Column(
                        children: [
                          _buildRatingRow(label: "Sleep Quality", icon: Icons.star_rounded, color: Colors.amber, value: _sleepQuality, onChanged: (v) => setState(() => _sleepQuality = v), theme: theme),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Interruptions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              _buildCounter(theme),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. ENERGY, MOOD & JOURNAL
                    _buildCompactCard(
                      theme: theme,
                      isDark: isDark,
                      child: Column(
                        children: [
                          _buildRatingRow(label: "Morning Energy", icon: Icons.bolt_rounded, color: Colors.orange, value: _energyRating, onChanged: (v) => setState(() => _energyRating = v), theme: theme),
                          _buildRatingRow(label: "Morning Mood", icon: Icons.sentiment_satisfied_alt_rounded, color: Colors.green, value: _moodRating, onChanged: (v) => setState(() => _moodRating = v), theme: theme),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Brief notes (e.g., stressful dreams)",
                              hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. SAVE BUTTON (Always visible at bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSleepLog,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Save Sleep Log", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildRatingRow({required String label, required IconData icon, required Color color, required int value, required ValueChanged<int> onChanged, required ThemeData theme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text("$value/5", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final int rating = index + 1;
              final bool isSelected = rating <= value;
              return GestureDetector(
                onTap: () => onChanged(rating),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : theme.dividerColor.withOpacity(0.05),
                      shape: BoxShape.circle
                  ),
                  child: Icon(
                    isSelected ? icon : _getOutlineIcon(icon),
                    color: isSelected ? color : theme.disabledColor,
                    size: 24,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTimeTile(String label, String time, IconData icon, VoidCallback onTap, ThemeData theme, Color color, bool isDark) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
              color: isDark ? theme.cardColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
                  const SizedBox(height: 2),
                  Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard({required Widget child, required ThemeData theme, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: child,
    );
  }

  Widget _buildCounter(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
          color: theme.dividerColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.remove_rounded, size: 20), onPressed: () => setState(() => _interruptions = (_interruptions - 1).clamp(0, 10))),
          Container(
            width: 24, alignment: Alignment.center,
            child: Text("$_interruptions", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          IconButton(icon: const Icon(Icons.add_rounded, size: 20), onPressed: () => setState(() => _interruptions = (_interruptions + 1).clamp(0, 10))),
        ],
      ),
    );
  }

  IconData _getOutlineIcon(IconData source) {
    if (source == Icons.star_rounded) return Icons.star_outline_rounded;
    if (source == Icons.bolt_rounded) return Icons.bolt_outlined;
    if (source == Icons.sentiment_satisfied_alt_rounded) return Icons.sentiment_neutral_rounded;
    return source;
  }
}