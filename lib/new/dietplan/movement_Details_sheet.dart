import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class MovementDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog; // Represents the Master Record
  final int currentSteps;

  const MovementDetailSheet({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
    required this.currentIntake,
  }) : currentSteps = currentIntake;

  const MovementDetailSheet.withSteps({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
    required this.currentSteps,
  }) : currentIntake = 0;

  final int currentIntake;

  @override
  ConsumerState<MovementDetailSheet> createState() => _MovementDetailSheetState();
}

class _MovementDetailSheetState extends ConsumerState<MovementDetailSheet> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _progressAnimation;

  bool _isManualMode = false;
  bool _isSaving = false;
  late int _displaySteps;
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displaySteps = widget.currentSteps;
    _manualController.text = _displaySteps.toString();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutBack),
    );

    _spinController.forward();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // --- 🎯 ATOMIC ACTIONS ---

  Future<void> _toggleTask(String task) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final currentCompleted = List<String>.from(widget.dailyLog?.completedMandatoryTasks ?? []);

      if (currentCompleted.contains(task)) {
        currentCompleted.remove(task);
      } else {
        currentCompleted.add(task);
      }

      // 🎯 Recalculate score for atomic update
      final int goal = widget.activePlan.dailyStepGoal > 0 ? widget.activePlan.dailyStepGoal : 8000;
      final double progress = (_displaySteps / goal).clamp(0.0, 1.0);
      final int newScore = ((progress * 50) + (currentCompleted.length * 10)).clamp(0, 100).toInt();

      // 🎯 Atomic Update: Only touch tasks and score
      await widget.notifier.updateDailyRecord(
          data: {
            'completedMandatoryTasks': currentCompleted,
            'activityScore': newScore,
          }
      );

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveManualSteps() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final int newSteps = int.tryParse(_manualController.text) ?? _displaySteps;
      final int calories = (newSteps * 0.04).round();

      // 🎯 Recalculate score
      final int goal = widget.activePlan.dailyStepGoal > 0 ? widget.activePlan.dailyStepGoal : 8000;
      final double progress = (newSteps / goal).clamp(0.0, 1.0);
      final int currentCompletedCount = widget.dailyLog?.completedMandatoryTasks.length ?? 0;
      final int newScore = ((progress * 50) + (currentCompletedCount * 10)).clamp(0, 100).toInt();

      // 🎯 Atomic Update: Only touch step-related fields
      await widget.notifier.updateDailyRecord(
          data: {
            'stepCount': newSteps,
            'caloriesBurned': calories,
            'activityScore': newScore,
          }
      );

      if (mounted) {
        setState(() {
          _displaySteps = newSteps;
          _isManualMode = false;
        });

        // Small delay to let the user see the updated ring before closing
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final int goal = widget.activePlan.dailyStepGoal > 0 ? widget.activePlan.dailyStepGoal : 8000;
    final double progress = (_displaySteps / goal).clamp(0.0, 1.0);

    final double km = (_displaySteps * 0.762) / 1000;
    final int kcal = (_displaySteps * 0.04).round();
    final int score = ((progress * 50) + ((widget.dailyLog?.completedMandatoryTasks.length ?? 0) * 10)).clamp(0, 100).toInt();

    // 🎯 Solid Premium Background to prevent transparency bleed
    final solidBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
      child: Stack(
        children: [
          // Premium Background Gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 250,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withOpacity(isDark ? 0.12 : 0.06),
                    solidBgColor.withOpacity(0.0) // Fades perfectly into the solid background
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              children: [
                // 1. Drag Handle
                Center(
                    child: Container(
                        width: 48, height: 5,
                        decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(3)
                        )
                    )
                ),
                const SizedBox(height: 24),

                // 2. Title & Toggles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        context.tr("daily_movement"),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: isDark ? theme.cardColor : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.05))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeBtn(context.tr("sensor"), !_isManualMode, theme, colorScheme, isDark),
                          _buildModeBtn(context.tr("manual"), _isManualMode, theme, colorScheme, isDark),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 32),

                // 3. TURBO RING OR MANUAL INPUT
                Expanded(
                  flex: 3,
                  child: !_isManualMode
                      ? Center(
                    child: SizedBox(
                      height: 220,
                      width: 220,
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: TurboRingPainter(
                              progress: progress * _progressAnimation.value,
                              activeColor: colorScheme.primary,
                              trackColor: theme.dividerColor.withOpacity(isDark ? 0.1 : 0.05),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_walk_rounded, color: colorScheme.primary, size: 36),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$_displaySteps",
                                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1.0),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "/ $goal ${context.tr("lbl_steps")}",
                                    style: TextStyle(fontSize: 14, color: theme.hintColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                      : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(context.tr("enter_steps_manually"), style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _manualController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: colorScheme.primary),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDark ? colorScheme.primary.withOpacity(0.1) : colorScheme.primaryContainer.withOpacity(0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          width: 200,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveManualSteps,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                            ),
                            child: _isSaving
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(context.tr("update_count"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 4. STAT BUBBLES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatBubble(Icons.local_fire_department_rounded, "$kcal", "Kcal", Colors.redAccent, theme, isDark),
                    _buildStatBubble(Icons.straighten_rounded, km.toStringAsFixed(1), "Km", Colors.blueAccent, theme, isDark),
                    _buildStatBubble(Icons.bolt_rounded, "$score", context.tr("lbl_score"), Colors.amber.shade600, theme, isDark),
                  ],
                ),

                const SizedBox(height: 24),
                Divider(color: theme.dividerColor.withOpacity(0.1)),
                const SizedBox(height: 8),

                // 5. MISSIONS
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                        context.tr("daily_mission"),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)
                    ),
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: widget.activePlan.mandatoryDailyTasks.isEmpty
                      ? Center(child: Text("${context.tr("no_mission_assigned_today")}.", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w500)))
                      : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: widget.activePlan.mandatoryDailyTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = widget.activePlan.mandatoryDailyTasks[index];
                      final isCompleted = widget.dailyLog?.completedMandatoryTasks.contains(task) ?? false;

                      return _buildMissionCard(task, isCompleted, theme, colorScheme, isDark);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildModeBtn(String label, bool isSelected, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isManualMode = label == context.tr("manual");
          if (_isManualMode) _manualController.text = _displaySteps.toString();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? (isDark ? theme.scaffoldBackgroundColor : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : []
        ),
        child: Text(
            label,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: isSelected ? colorScheme.primary : theme.hintColor
            )
        ),
      ),
    );
  }

  Widget _buildStatBubble(IconData icon, String value, String unit, Color baseColor, ThemeData theme, bool isDark) {
    return Column(
        children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: isDark ? baseColor.withOpacity(0.1) : baseColor.withOpacity(0.15),
                  shape: BoxShape.circle
              ),
              child: Icon(icon, color: baseColor, size: 26)
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
          Text(unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor))
        ]
    );
  }

  Widget _buildMissionCard(String title, bool isCompleted, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final successColor = Colors.green.shade600;

    // Opaque card colors for premium feel
    final bgColor = isCompleted
        ? (isDark ? successColor.withOpacity(0.15) : successColor.withOpacity(0.08))
        : (isDark ? theme.cardColor : Colors.white);

    final borderColor = isCompleted
        ? successColor.withOpacity(0.3)
        : theme.dividerColor.withOpacity(0.08);

    return InkWell(
      onTap: () => _toggleTask(title),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: !isCompleted && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))] : []
        ),
        child: Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isCompleted ? successColor : theme.hintColor.withOpacity(0.5),
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(
                      title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isCompleted ? successColor : colorScheme.onSurface,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: successColor
                      )
                  )
              )
            ]
        ),
      ),
    );
  }
}

class TurboRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  TurboRingPainter({required this.progress, required this.activeColor, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Active Progress Arc
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
          colors: [activeColor.withOpacity(0.6), activeColor],
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          transform: const GradientRotation(-pi / 2)
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * progress, false, activePaint);

    // Tip Glow
    if (progress > 0) {
      final angle = -pi / 2 + (2 * pi * progress);
      final tipX = center.dx + radius * cos(angle);
      final tipY = center.dy + radius * sin(angle);
      final glowPaint = Paint()
        ..color = activeColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(tipX, tipY), 16, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TurboRingPainter oldDelegate) => oldDelegate.progress != progress;
}