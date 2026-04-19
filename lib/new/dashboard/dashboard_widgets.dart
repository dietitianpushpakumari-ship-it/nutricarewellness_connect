import 'dart:async';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:pure_shift/features/dietplan/PRESENTATION/screens/wave_clipper.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:intl/intl.dart';

// 🚀 LUXURY CONSTANTS
const double kCardRadius = 32.0;

// =================================================================
// 💎 REUSABLE LUXURY BENTO BACKGROUND (Now with Pulse Animation!)
// =================================================================
class LuxuryBentoBackground extends StatefulWidget {
  final Color baseGlowColor;
  final Widget child;
  final VoidCallback onTap;
  final bool clipContent;
  final bool isOverdue; // 🚀 ADDED: Triggers the alert state

  const LuxuryBentoBackground({
    super.key,
    required this.baseGlowColor,
    required this.child,
    required this.onTap,
    this.clipContent = true,
    this.isOverdue = false,
  });

  @override
  State<LuxuryBentoBackground> createState() => _LuxuryBentoBackgroundState();
}

class _LuxuryBentoBackgroundState extends State<LuxuryBentoBackground> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // 🚀 A slow, calm heartbeat for overdue items (2 seconds)
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 🚀 THE COLOR SHIFT: Overdue items glow with a warm Coral/Amber
    final Color activeGlowColor = widget.isOverdue ? const Color(0xFFFF6E40) : widget.baseGlowColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.scale(kCardRadius)),
          boxShadow: [
            BoxShadow(
              color: activeGlowColor.withOpacity(isDark ? 0.08 : 0.04),
              blurRadius: 30, spreadRadius: 0, offset: const Offset(0, 8),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.scale(kCardRadius)),
          clipBehavior: widget.clipContent ? Clip.antiAlias : Clip.none,
          child: Stack(
            children: [
              // 🌌 LAYER 1: Deep Base Color
              Positioned.fill(
                child: Container(color: isDark ? const Color(0xFF0B0F19) : Colors.white),
              ),

              // 🌊 LAYER 2: Soft Corner Glow (Animated if Overdue)
              Positioned(
                bottom: -30, right: -30,
                child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      // If overdue, the opacity pulses between 0.2 and 0.6
                      final double opacity = widget.isOverdue
                          ? (0.2 + (_pulseController.value * 0.4))
                          : (isDark ? 0.4 : 0.2);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 500), // Smooth color transition
                        width: context.scale(120), height: context.scale(120),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeGlowColor.withOpacity(opacity),
                        ),
                      );
                    }
                ),
              ),

              // 🌫️ LAYER 3: Mesh Blur
              Positioned.fill(
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(color: Colors.transparent)),
              ),

              // 🪟 LAYER 4: Glass Border & Content Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(context.scale(kCardRadius)),
                    border: Border.all(
                      // The border itself catches a tiny bit of the amber glow if overdue
                      color: widget.isOverdue
                          ? activeGlowColor.withOpacity(0.3)
                          : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                      width: 1.0,
                    ),
                  ),
                ),
              ),

              // ✨ LAYER 5: The Actual Card Content
              Positioned.fill(
                child: widget.child, // 🚀 Changed from just 'child' to 'Positioned.fill'
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 💎 REUSABLE LUXURY LABEL PILL (Now supports Alert Dot)
Widget _buildLuxuryPill(BuildContext context, String text, IconData icon, Color color, bool isDark, {bool isOverdue = false}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: context.scale(10), vertical: context.scale(4)),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
      borderRadius: BorderRadius.circular(context.scale(16)),
      border: Border.all(color: isOverdue ? const Color(0xFFFF6E40).withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02))),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: context.scale(10), color: isOverdue ? const Color(0xFFFF6E40) : color),
        SizedBox(width: context.scale(6)),
        Text(
          text.toUpperCase(),
          style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(9), fontWeight: FontWeight.w800, letterSpacing: 2.0, color: isDark ? Colors.white : Colors.black87),
        ),
        if (isOverdue) ...[
          SizedBox(width: context.scale(6)),
          Container(width: context.scale(4), height: context.scale(4), decoration: const BoxDecoration(color: Color(0xFFFF6E40), shape: BoxShape.circle)),
        ]
      ],
    ),
  );
}

// =================================================================
// 1. PREMIUM HYDRATION CARD (With Interval Logic)
// =================================================================
// =================================================================
// 1. PREMIUM HYDRATION CARD (With 100% Fill Fix)
// =================================================================
class MiniHydrationCard extends StatelessWidget {
  final double currentLiters;
  final double goalLiters;
  final Animation<double> waveAnimation;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  const MiniHydrationCard({super.key, required this.currentLiters, required this.goalLiters, required this.waveAnimation, required this.onTap, required this.onQuickAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isEmpty = currentLiters <= 0;
    final double safeGoal = goalLiters == 0 ? 3.0 : goalLiters;
    final double progress = (currentLiters / safeGoal).clamp(0.0, 1.0);
    final Color primaryColor = const Color(0xFF00B0FF);

    // Time Logic
    final now = DateTime.now();
    double expectedLiters = 0;
    if (now.hour >= 9) expectedLiters = safeGoal * 0.2;
    if (now.hour >= 13) expectedLiters = safeGoal * 0.4;
    final bool isOverdue = currentLiters < expectedLiters;

    return LuxuryBentoBackground(
      baseGlowColor: primaryColor,
      isOverdue: isOverdue,
      onTap: onTap,
      // 🚀 CRITICAL: We let the background handle the clipping
      clipContent: true,
      child: Stack(
        children: [
          // 🌊 THE WAVE: Must be Positioned.fill to cover the whole grid area
          if (!isEmpty)
            Positioned.fill(
              child: ClipPath(
                clipper: WaveClipper(
                  waveProgress: waveAnimation.value,
                  // We boost the visual fill slightly to ensure it touches the top
                  fillProgress: progress >= 0.95 ? 1.0 : progress,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        primaryColor.withOpacity(0.7),
                        primaryColor.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 🚀 CONTENT LAYER: Positioned on top of the water
          Padding(
            padding: EdgeInsets.all(context.scale(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLuxuryPill(context, "WATER", Icons.water_drop_rounded, progress > 0.4 ? Colors.white : primaryColor, isDark, isOverdue: isOverdue),

                // Use a Column at the bottom for the metrics
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEmpty ? "Hydrate" : "${(progress * 100).toInt()}%",
                      style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: context.scale(20),
                          fontWeight: FontWeight.w700,
                          color: progress > 0.4 ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          letterSpacing: -0.5,
                          height: 1.1
                      ),
                    ),
                    Text(
                      isOverdue ? "Behind schedule" : (isEmpty ? "Log water" : "${currentLiters.toStringAsFixed(1)}L logged"),
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.scale(10),
                          fontWeight: FontWeight.w600,
                          color: isOverdue ? const Color(0xFFFF6E40) : (progress > 0.4 ? Colors.white.withOpacity(0.8) : (isDark ? Colors.white54 : Colors.black54))
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// 2. PREMIUM STEP CARD (With Interval Logic)
// =================================================================
class MiniStepCard extends StatelessWidget {
  final int steps;
  final int goal;
  final VoidCallback onTap;

  const MiniStepCard({super.key, required this.steps, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final int safeGoal = goal == 0 ? 8000 : goal;
    final double progress = (steps / safeGoal).clamp(0.0, 1.0);
    final bool hasData = steps > 0;
    final Color primaryColor = const Color(0xFF00E676);

    // 🚀 TIME LOGIC: Are they too sedentary today?
    final now = DateTime.now();
    int expectedSteps = 0;
    if (now.hour >= 12) expectedSteps = (safeGoal * 0.3).toInt();
    if (now.hour >= 16) expectedSteps = (safeGoal * 0.6).toInt();
    if (now.hour >= 20) expectedSteps = (safeGoal * 0.8).toInt();

    final bool isOverdue = steps < expectedSteps;

    return LuxuryBentoBackground(
      baseGlowColor: primaryColor,
      isOverdue: isOverdue,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.scale(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLuxuryPill(context, "STEPS", Icons.directions_run_rounded, primaryColor, isDark, isOverdue: isOverdue),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    !hasData ? "Move" : NumberFormat('#,###').format(steps),
                    style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(20), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5, height: 1.1),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isOverdue ? "Pacing behind" : (!hasData ? "Track steps" : "${(progress * 100).toInt()}% of goal"),
                    style: TextStyle(
                        fontFamily: 'Inter', fontSize: context.scale(10), fontWeight: FontWeight.w600,
                        color: isOverdue ? const Color(0xFFFF6E40) : (isDark ? Colors.white54 : Colors.black54)
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 3. PREMIUM SLEEP CARD (With Interval Logic)
// =================================================================
class MiniSleepCard extends StatelessWidget {
  final double hours;
  final int score;
  final VoidCallback onTap;

  const MiniSleepCard({super.key, required this.hours, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool hasData = hours > 0;
    final int displayHours = hours.floor();
    final int displayMinutes = ((hours - displayHours) * 60).round();
    final Color primaryColor = const Color(0xFF536DFE);

    // 🚀 TIME LOGIC: If it is past 10 AM and no sleep is logged, remind them!
    final now = DateTime.now();
    final bool isOverdue = now.hour >= 10 && hours == 0;

    return LuxuryBentoBackground(
      baseGlowColor: primaryColor,
      isOverdue: isOverdue,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.scale(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLuxuryPill(context, "SLEEP", Icons.bedtime_rounded, primaryColor, isDark, isOverdue: isOverdue),
                if (hasData && score > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(6), vertical: context.scale(2)),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(context.scale(6))),
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, color: primaryColor, size: context.scale(8)),
                        SizedBox(width: context.scale(2)),
                        Text("$score", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(9), fontWeight: FontWeight.w800, color: primaryColor)),
                      ],
                    ),
                  )
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasData)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text("$displayHours", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(20), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5, height: 1.1)),
                          Text("h ", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(12), fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                          Text("$displayMinutes", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(20), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5, height: 1.1)),
                          Text("m", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(12), fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                    )
                  else
                    Text("Rest", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(20), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5, height: 1.1)),

                  Text(
                    isOverdue ? "Log last night" : (!hasData ? "Log sleep" : "Quality logged"),
                    style: TextStyle(
                        fontFamily: 'Inter', fontSize: context.scale(10), fontWeight: FontWeight.w600,
                        color: isOverdue ? const Color(0xFFFF6E40) : (isDark ? Colors.white54 : Colors.black54)
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 4. PREMIUM BREATHING CARD (With Interval Logic)
// =================================================================
class MiniBreathingCard extends StatelessWidget {
  final int minutesLogged;
  final VoidCallback onTap;

  const MiniBreathingCard({super.key, required this.minutesLogged, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool hasData = minutesLogged > 0;
    final Color primaryColor = const Color(0xFF00BFA5);

    // 🚀 TIME LOGIC: If the day is ending (8 PM) and they haven't paused
    final now = DateTime.now();
    final bool isOverdue = now.hour >= 20 && minutesLogged == 0;

    return LuxuryBentoBackground(
      baseGlowColor: primaryColor,
      isOverdue: isOverdue,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.scale(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLuxuryPill(context, "BREATH", Icons.air_rounded, primaryColor, isDark, isOverdue: isOverdue),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    hasData ? "${minutesLogged}m" : "Focus",
                    style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(20), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5, height: 1.1),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isOverdue ? "Take a moment" : (hasData ? "Mindful time" : "Breathe"),
                    style: TextStyle(
                        fontFamily: 'Inter', fontSize: context.scale(10), fontWeight: FontWeight.w600,
                        color: isOverdue ? const Color(0xFFFF6E40) : (isDark ? Colors.white54 : Colors.black54)
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}