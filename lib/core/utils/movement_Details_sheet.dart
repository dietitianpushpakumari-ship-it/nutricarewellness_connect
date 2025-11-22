import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class MovementDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;
  final int currentSteps;

  const MovementDetailSheet({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
    required this.currentIntake, // 🎯 Mapped to steps in the parent call
  }) : currentSteps = currentIntake; // Alias for clarity

  // Constructor alias helper if passing int directly
  const MovementDetailSheet.withSteps({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
    required this.currentSteps,
  }) : currentIntake = 0; // Unused

  final int currentIntake; // Just to satisfy the signature if reusing patterns

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

    // 1. Spin Animation for the Ring
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

  // --- ACTIONS ---

  Future<void> _toggleTask(String task) async {
    setState(() => _isSaving = true);
    try {
      final currentCompleted = List<String>.from(widget.dailyLog?.completedMandatoryTasks ?? []);

      if (currentCompleted.contains(task)) {
        currentCompleted.remove(task);
      } else {
        currentCompleted.add(task);
      }

      final logToSave = _getOrCreateLog();
      final updatedLog = logToSave.copyWith(completedMandatoryTasks: currentCompleted);

      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveManualSteps() async {
    setState(() => _isSaving = true);
    try {
      final newSteps = int.tryParse(_manualController.text) ?? _displaySteps;
      final logToSave = _getOrCreateLog();

      // Calculate calories (approx 0.04 kcal per step)
      final calories = (newSteps * 0.04).round();

      final updatedLog = logToSave.copyWith(
        stepCount: newSteps,
        caloriesBurned: calories,
        // Note: We might want to clear sensor baseline if going manual,
        // but for simplicity, we just update the count here.
      );

      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);
      if(mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ClientLogModel _getOrCreateLog() {
    return widget.dailyLog ?? ClientLogModel(
      id: '',
      clientId: widget.activePlan.clientId,
      dietPlanId: widget.activePlan.id,
      mealName: 'DAILY_WELLNESS_CHECK',
      actualFoodEaten: ['Daily Wellness Data'],
      date: widget.notifier.state.selectedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int goal = widget.activePlan.dailyStepGoal > 0 ? widget.activePlan.dailyStepGoal : 8000;
    final double progress = (_displaySteps / goal).clamp(0.0, 1.0);

    // Derived Stats
    final double km = (_displaySteps * 0.762) / 1000; // Avg stride 0.762m
    final int kcal = (_displaySteps * 0.04).round();
    final int score = ((progress * 50) + ((widget.dailyLog?.completedMandatoryTasks.length ?? 0) * 10)).clamp(0, 100).toInt();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          // Background Gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 300,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade50, Colors.white],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                // 1. Handle
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),

                // 2. Header & Toggle
                // 2. Header & Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🎯 FIX: Wrap Text in Expanded to prevent overflow
                    const Expanded(
                      child: Text(
                        "Daily Movement",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Adds "..." if it gets too tight
                      ),
                    ),
                    const SizedBox(width: 8), // Small gap between text and toggle

                    // The Toggle Container
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // 🎯 Keeps the toggle compact
                        children: [
                          _buildModeBtn("Sensor", !_isManualMode),
                          _buildModeBtn("Manual", _isManualMode),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 30),

                // 3. THE TURBO RING
                if (!_isManualMode)
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: TurboRingPainter(
                            progress: progress * _progressAnimation.value,
                            color: Colors.deepOrange,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_walk, color: Colors.orange, size: 32),
                                Text(
                                  "$_displaySteps",
                                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.0),
                                ),
                                Text(
                                  "/ $goal Steps",
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                // Manual Input Mode
                  Container(
                    height: 220,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Enter Steps Manually", style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _manualController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: Colors.orange.shade50,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveManualSteps,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                          child: const Text("Update Count"),
                        )
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                // 4. Stat Row (Calculated Metrics)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatBubble(Icons.local_fire_department, "$kcal", "Kcal", Colors.red),
                    _buildStatBubble(Icons.straighten, km.toStringAsFixed(1), "Km", Colors.blue),
                    _buildStatBubble(Icons.bolt, "$score", "Score", Colors.amber),
                  ],
                ),

                const SizedBox(height: 30),
                const Divider(),

                // 5. Daily Missions (Scrollable)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text("Daily Missions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),

                Expanded(
                  child: widget.activePlan.mandatoryDailyTasks.isEmpty
                      ? Center(child: Text("No missions assigned today.", style: TextStyle(color: Colors.grey.shade400)))
                      : ListView.separated(
                    itemCount: widget.activePlan.mandatoryDailyTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = widget.activePlan.mandatoryDailyTasks[index];
                      final isCompleted = widget.dailyLog?.completedMandatoryTasks.contains(task) ?? false;

                      return _buildMissionCard(task, isCompleted);
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

  Widget _buildModeBtn(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isManualMode = label == "Manual";
          if (_isManualMode) _manualController.text = _displaySteps.toString();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected ? Colors.deepOrange : Colors.grey
          ),
        ),
      ),
    );
  }

  Widget _buildStatBubble(IconData icon, String value, String unit, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildMissionCard(String title, bool isCompleted) {
    return InkWell(
      onTap: () => _toggleTask(title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
              width: 2
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: isCompleted ? Colors.green : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isCompleted ? Colors.green.shade800 : Colors.black87,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🎨 Custom Painter for the "Turbo Ring"
class TurboRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  TurboRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;

    // 1. Background Track
    final trackPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active Arc
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.5), color],
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        transform: GradientRotation(-pi / 2), // Rotate to start at top
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start at top (12 o'clock)
      2 * pi * progress, // Sweep amount
      false,
      activePaint,
    );

    // 3. Glow Effect (at tip)
    if (progress > 0) {
      final angle = -pi / 2 + (2 * pi * progress);
      final tipX = center.dx + radius * cos(angle);
      final tipY = center.dy + radius * sin(angle);

      final glowPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawCircle(Offset(tipX, tipY), 15, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TurboRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}