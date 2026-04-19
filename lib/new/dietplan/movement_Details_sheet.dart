import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// 🚀 IMPORTS
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

const String kFontFamily = 'Inter';

class MovementDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final FlatClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;
  final int currentSteps;

  const MovementDetailSheet.withSteps({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
    required this.currentSteps,
  });

  @override
  ConsumerState<MovementDetailSheet> createState() => _MovementDetailSheetState();
}

class _MovementDetailSheetState extends ConsumerState<MovementDetailSheet> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _progressAnimation;
  late int _displaySteps;

  @override
  void initState() {
    super.initState();
    _displaySteps = widget.currentSteps;

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.fastOutSlowIn),
    );

    _spinController.forward();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🎯 CORE CALCULATIONS
    final int goal = widget.activePlan.dailyStepGoal > 0 ? widget.activePlan.dailyStepGoal : 8000;
    final double progress = (_displaySteps / goal).clamp(0.0, 1.0);

    // 🚀 DERIVED DATA (Clinical Averages & Physics-based calculations)
    // 1. General Activity
    final double km = (_displaySteps * 0.762) / 1000; // Average stride 0.762m
    final int kcal = (_displaySteps * 0.04).round(); // ~0.04 kcal per step
    final int activeMins = (_displaySteps / 100).round(); // Avg 100 steps per min of active walking
    final int floors = (_displaySteps / 2500).round(); // 1 flight of stairs roughly equals effort of 2500 steps

    // 2. Clinical Mobility (Gait & Balance)
    // In the future, these can be pulled directly from HealthKit. For now, we derive healthy baselines.
    final String stepLength = _displaySteps > 0 ? "76" : "0"; // cm
    final String walkingSpeed = _displaySteps > 0 ? "1.2" : "0.0"; // m/s (Average healthy speed)
    final String asymmetry = _displaySteps > 0 ? "< 2" : "0"; // Percentage (Ideal healthy gait)

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(32))),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.scale(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Placeholder to keep the handle perfectly centered
                      SizedBox(width: context.scale(40)),

                      // Drag Handle
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2)
                        ),
                      ),

                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: EdgeInsets.all(context.scale(8)),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                Icons.close_rounded,
                                size: context.scale(20),
                                color: colorScheme.onSurface
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.scale(24)),

                  // 🚀 2. HEADER TEXT
                  Center(
                    child: Text(
                      "ACTIVITY INSIGHTS",
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: context.scale(10),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: theme.hintColor.withOpacity(0.6),
                      ),
                    ),
                  ),

                  SizedBox(height: context.scale(32)),

                  // 🚀 3. THE TURBO RING (Centered)
                  Center(
                    child: SizedBox(
                      height: context.scale(220),
                      width: context.scale(220),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: TurboRingPainter(
                              progress: progress * _progressAnimation.value,
                              activeColor: colorScheme.primary,
                              trackColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, color: colorScheme.primary, size: context.scale(24)),
                                  Text(
                                    NumberFormat('#,###').format(_displaySteps),
                                    style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(42), fontWeight: FontWeight.w700, color: colorScheme.onSurface, height: 1.0, letterSpacing: -1),
                                  ),
                                  Text(
                                    "OF $goal STEPS",
                                    style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(11), color: theme.hintColor, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: context.scale(48)),

                  // 🚀 4. THE DATA BENTO GRID (General Activity)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: context.scale(12),
                    crossAxisSpacing: context.scale(12),
                    childAspectRatio: 1.6,
                    children: [
                      _buildMetricTile(
                          "Est. Distance",
                          km.toStringAsFixed(2), "km",
                          Icons.map_outlined,
                          Colors.green
                      ),
                      _buildMetricTile(
                          "Energy Burned",
                          "$kcal", "kcal",
                          Icons.local_fire_department_rounded,
                          Colors.orange
                      ),
                      _buildMetricTile(
                          "Active Time",
                          "$activeMins", "mins",
                          Icons.timer_outlined,
                          Colors.purple
                      ),
                      _buildMetricTile(
                          "Flights ",
                          "$floors", "levels",
                          Icons.unfold_more_rounded,
                          Colors.blue
                      ),
                    ],
                  ),

                  SizedBox(height: context.scale(32)),

                  // 🚀 5. CLINICAL MOBILITY ROW
                  // 🚀 5. CLINICAL MOBILITY ROW
                  Text(
                    "CLINICAL MOBILITY",
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: context.scale(10),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: theme.hintColor.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: context.scale(16)),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(20)),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(context.scale(20)),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 🚀 Changed to spaceEvenly
                      children: [
                        Expanded(child: _buildClinicalStat("Stride", stepLength, "cm", isDark, theme)), // Shortened text
                        Container(width: 1, height: context.scale(30), color: theme.dividerColor.withOpacity(0.2)),
                        Expanded(child: _buildClinicalStat("Pace", walkingSpeed, "m/s", isDark, theme)), // Shortened text
                        Container(width: 1, height: context.scale(30), color: theme.dividerColor.withOpacity(0.2)),
                        Expanded(child: _buildClinicalStat("Balance", asymmetry, "%", isDark, theme)), // Shortened text
                      ],
                    ),
                  ),




                  SizedBox(height: context.scale(32)),

                  // 🚀 6. ANALYTICS BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text("View Weekly History"),
                      style: TextButton.styleFrom(
                          foregroundColor: theme.hintColor,
                          textStyle: const TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(context.scale(20)),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: context.scale(14)),
              SizedBox(width: context.scale(6)),
              Text(label, style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(10), fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          SizedBox(height: context.scale(8)),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: value, style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(18), fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                TextSpan(text: " $unit", style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(11), fontWeight: FontWeight.w500, color: Theme.of(context).hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildClinicalStat(String label, String value, String unit, bool isDark, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min, // 🚀 Keep column tight
      children: [
        // 🚀 Use FittedBox to shrink text if the number gets too large
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min, // 🚀 Keep row tight
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(16), fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)), // Slightly reduced font
              Text(" $unit", style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(10), fontWeight: FontWeight.w600, color: theme.hintColor)),
            ],
          ),
        ),
        SizedBox(height: context.scale(4)),
        Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: kFontFamily, fontSize: context.scale(9), fontWeight: FontWeight.w600, color: theme.hintColor)
        ),
      ],
    );
  }
}

// 🚀 THE CUSTOM PAINTER FOR THE ACTIVITY RING
class TurboRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  TurboRingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [activeColor.withOpacity(0.4), activeColor],
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        transform: const GradientRotation(-pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      activePaint,
    );

    if (progress > 0) {
      final angle = -pi / 2 + (2 * pi * progress);
      final tipX = center.dx + radius * cos(angle);
      final tipY = center.dy + radius * sin(angle);

      final glowPaint = Paint()
        ..color = activeColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(Offset(tipX, tipY), 10, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TurboRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}