import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/layout_utils.dart'; // 🚀 Required for scaling
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

const String kFontFamily = 'Inter';
const String kDisplayFont = 'Space Grotesk';

class SleepDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final FlatClientDietPlanModel activePlan;
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
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 6, minute: 30);
  int _sleepQuality = 3;
  int _energyRating = 3;
  int _moodRating = 3;
  int _interruptions = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.dailyLog != null) {
      final log = widget.dailyLog!;
      if (log.sleepTime != null) _sleepTime = TimeOfDay.fromDateTime(log.sleepTime!.toLocal());
      if (log.wakeTime != null) _wakeTime = TimeOfDay.fromDateTime(log.wakeTime!.toLocal());
      _sleepQuality = log.sleepQualityRating ?? 3;
      _energyRating = log.energyLevelRating ?? 3;
      _moodRating = log.moodLevelRating ?? 3;
      _interruptions = log.sleepInterruptions ?? 0;
    }
  }

  Duration _calculateDuration() {
    final date = widget.notifier.state.selectedDate;
    DateTime sleepDt = DateTime(date.year, date.month, date.day, _sleepTime.hour, _sleepTime.minute);
    DateTime wakeDt = DateTime(date.year, date.month, date.day, _wakeTime.hour, _wakeTime.minute);

    // If you wake up before you went to sleep, it means you crossed midnight!
    if (wakeDt.isBefore(sleepDt)) wakeDt = wakeDt.add(const Duration(days: 1));
    return wakeDt.difference(sleepDt);
  }

  // 🚀 NEW: The Native Time Picker Dialog
  Future<void> _pickTime(BuildContext context, bool isSleepTime) async {
    HapticFeedback.lightImpact();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isSleepTime ? _sleepTime : _wakeTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isSleepTime) {
          _sleepTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final duration = _calculateDuration();

    // Formatting the date for the header
    final String displayDate = DateFormat('EEEE, MMM d').format(widget.notifier.state.selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(32))),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.scale(24)),
          child: Column(
            children: [
              // 1. Header & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SLEEP ANALYSIS", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w800, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.6))),
                      SizedBox(height: context.scale(4)),
                      // 🚀 NEW: Date context so they know what night they are editing
                      Text("Night of $displayDate", style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(12), fontWeight: FontWeight.w600, color: colorScheme.primary)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: CircleAvatar(radius: context.scale(14), backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), child: Icon(Icons.close_rounded, size: context.scale(16), color: colorScheme.onSurface)),
                  )
                ],
              ),
              SizedBox(height: context.scale(24)),

              // 🚀 2. THE NEW TIME PICKER CARDS
              Row(
                children: [
                  Expanded(child: _buildTimePickerCard("Bedtime", _sleepTime, Icons.bedtime_rounded, Colors.indigoAccent, () => _pickTime(context, true), context)),
                  SizedBox(width: context.scale(12)),
                  Expanded(child: _buildTimePickerCard("Wake Up", _wakeTime, Icons.wb_sunny_rounded, Colors.orangeAccent, () => _pickTime(context, false), context)),
                ],
              ),
              SizedBox(height: context.scale(24)),

              // 3. Duration Visual
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(context.scale(20)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colorScheme.primary.withOpacity(0.1), colorScheme.primary.withOpacity(0.02)]),
                  borderRadius: BorderRadius.circular(context.scale(24)),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text("Total Rest Calculated", style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(11), fontWeight: FontWeight.w600, color: theme.hintColor)),
                    SizedBox(height: context.scale(4)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text("${duration.inHours}", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(42), fontWeight: FontWeight.w700, color: colorScheme.primary)),
                        Text("h ", style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(18), fontWeight: FontWeight.w500, color: theme.hintColor)),
                        Text("${duration.inMinutes % 60}", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(42), fontWeight: FontWeight.w700, color: colorScheme.primary)),
                        Text("m", style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(18), fontWeight: FontWeight.w500, color: theme.hintColor)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.scale(32)),

              // 4. Modern Rating Selectors
              _buildSegmentedRating("Sleep Quality", _sleepQuality, (v) => setState(() => _sleepQuality = v), colorScheme.primary, context),
              SizedBox(height: context.scale(20)),
              _buildSegmentedRating("Morning Energy", _energyRating, (v) => setState(() => _energyRating = v), Colors.orange, context),
              SizedBox(height: context.scale(20)),
              _buildSegmentedRating("Waking Mood", _moodRating, (v) => setState(() => _moodRating = v), Colors.green, context),

              SizedBox(height: context.scale(32)),

              // 5. Save Button
              // 5. Save Button
              SizedBox(
                width: double.infinity,
                height: context.scale(54),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    HapticFeedback.mediumImpact();
                    setState(() => _isSaving = true);

                    try {
                      final date = widget.notifier.state.selectedDate;

                      // 1. Calculate the exact DateTimes
                      DateTime sleepDt = DateTime(date.year, date.month, date.day, _sleepTime.hour, _sleepTime.minute);
                      DateTime wakeDt = DateTime(date.year, date.month, date.day, _wakeTime.hour, _wakeTime.minute);

                      // Handle midnight crossover
                      if (wakeDt.isBefore(sleepDt)) wakeDt = wakeDt.add(const Duration(days: 1));

                      // 1. Calculate the actual duration
// This handles the "sleeping past midnight" logic automatically if wakeDt is properly set to the next day
                      final duration = wakeDt.difference(sleepDt);
                      final double hours = duration.inMinutes / 60.0;

// 2. Send the exact payload to your Provider & Firestore
                      await widget.notifier.updateDailyRecord(data: {
                        'sleepTime': sleepDt.toUtc().toIso8601String(),
                        'wakeTime': wakeDt.toUtc().toIso8601String(),
                        'sleepQualityRating': _sleepQuality,
                        'energyLevelRating': _energyRating,
                        'moodLevelRating': _moodRating,
                        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
                        'totalSleepDurationHours': double.parse(hours.toStringAsFixed(1)), // 🔥 Fixed: Added value with 1 decimal precision
                      });
                      // 3. Close the sheet on success
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      debugPrint("Error saving sleep log: $e");
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16))),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? SizedBox(width: context.scale(24), height: context.scale(24), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Update Sleep Log", style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w700, fontSize: context.scale(15))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 NEW: The Premium Tappable Time Cards
  Widget _buildTimePickerCard(String title, TimeOfDay time, IconData icon, Color color, VoidCallback onTap, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.scale(16)),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(context.scale(20)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: context.scale(16), color: color),
                SizedBox(width: context.scale(8)),
                Text(title, style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(11), color: theme.hintColor, fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: context.scale(12)),
            Text(
              time.format(context), // Automatically handles 12h/24h based on phone settings!
              style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(22), fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, letterSpacing: -0.5),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 INDUSTRY GRADE SEGMENTED SELECTOR
  Widget _buildSegmentedRating(String label, int currentValue, ValueChanged<int> onSelect, Color activeColor, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.scale(4), bottom: context.scale(8)),
          child: Text(label.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w800, letterSpacing: 1.0, color: theme.hintColor)),
        ),
        Container(
          height: context.scale(48),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(context.scale(14)),
            border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
          ),
          child: Row(
            children: List.generate(5, (index) {
              final int value = index + 1;
              final bool isSelected = value == currentValue;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.all(context.scale(4)),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(context.scale(10)),
                      boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
                    ),
                    child: Center(
                      child: Text(
                        "$value",
                        style: TextStyle(
                          fontFamily: kDisplayFont,
                          fontSize: context.scale(16),
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : theme.hintColor.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}