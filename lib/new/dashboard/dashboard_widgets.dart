import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/localization/localization_extension.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/wave_clipper.dart';

// 🎨 PREMIUM DESIGN CONSTANTS
const double kCardRadius = 24.0;

// 🎯 REUSABLE GLASS DECORATION HELPER
// This ensures all cards perfectly inherit the frosted glass look from your themes
BoxDecoration _getGlassDecoration(BuildContext context, {Color? tint}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  // Base glass color from theme, optionally mixed with a slight tint for variety
  Color baseColor = theme.cardTheme.color ?? theme.colorScheme.surface;
  if (tint != null) {
    baseColor = Color.alphaBlend(tint.withOpacity(isDark ? 0.1 : 0.05), baseColor);
  }

  // Extract border color from theme's Card shape
  Color borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.4);
  if (theme.cardTheme.shape is RoundedRectangleBorder) {
    borderColor = (theme.cardTheme.shape as RoundedRectangleBorder).side.color;
  }

  return BoxDecoration(
    color: baseColor, // Translucent fill
    borderRadius: BorderRadius.circular(kCardRadius),
    border: Border.all(color: borderColor, width: 1.5), // Delicate glass rim
  );
}

// =================================================================
// 1. PREMIUM HYDRATION CARD
// =================================================================
class MiniHydrationCard extends StatelessWidget {
  final double currentLiters;
  final double goalLiters;
  final Animation<double> waveAnimation;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  const MiniHydrationCard({
    super.key,
    required this.currentLiters,
    required this.goalLiters,
    required this.waveAnimation,
    required this.onTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isEmpty = currentLiters <= 0;
    final double progress = (currentLiters / (goalLiters == 0 ? 3.0 : goalLiters)).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _getGlassDecoration(context),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 🌊 Background Wave (Now uses theme colors & opacity for liquid glass effect)
            if (!isEmpty)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: waveAnimation,
                  builder: (context, child) {
                    return ClipPath(
                      clipper: WaveClipper(waveProgress: waveAnimation.value, fillProgress: progress),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [
                              colorScheme.secondary.withOpacity(0.6),
                              colorScheme.primary.withOpacity(0.7)
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 📝 Content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.water_drop_rounded, color: progress > 0.5 ? Colors.white : colorScheme.primary, size: 20),
                      if (progress >= 1.0) const Icon(Icons.verified, color: Colors.white, size: 16),
                    ],
                  ),

                  // Stats
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: isEmpty
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${context.tr("dashboard_hydrate")}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                          const SizedBox(height: 2),
                          Text("${context.tr("dashboard_goal")}: ${goalLiters}L", style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            child: Text("$percent%", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: progress > 0.5 ? Colors.white : colorScheme.onSurface, height: 1.0)),
                          ),
                          const SizedBox(height: 2),
                          Text("${currentLiters.toStringAsFixed(1)}L", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: progress > 0.5 ? Colors.white.withOpacity(0.9) : colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ➕ Add Button
            Positioned(
              bottom: 8, right: 8,
              child: InkWell(
                onTap: onQuickAdd,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark ? Colors.white12 : Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.add, size: 16, color: theme.brightness == Brightness.dark ? Colors.white : colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 2. PREMIUM STEP CARD
// =================================================================
class MiniStepCard extends StatelessWidget {
  final int steps;
  final int goal;
  final VoidCallback onTap;

  const MiniStepCard({super.key, required this.steps, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double progress = (steps / (goal == 0 ? 8000 : goal)).clamp(0.0, 1.0);
    final Color ringColor = progress >= 1.0 ? const Color(0xFF43A047) : colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _getGlassDecoration(context), // 🎯 Glass
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row
            Row(
              children: [
                Icon(Icons.directions_run_rounded, color: colorScheme.onSurface.withOpacity(0.4), size: 18),
                const Spacer(),
                if (progress >= 1.0) const Icon(Icons.star, color: Colors.amber, size: 14),
              ],
            ),

            // Centered Ring
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    height: 55, width: 55,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: 1.0, strokeWidth: 5, color: colorScheme.onSurface.withOpacity(0.05)),
                        CircularProgressIndicator(value: progress, strokeWidth: 5, color: ringColor, strokeCap: StrokeCap.round),
                        Icon(Icons.bolt, size: 16, color: ringColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(child: Text("$steps", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorScheme.onSurface))),
                Text("${context.tr("dashboard_steps")}", style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 3. PREMIUM SLEEP CARD
// =================================================================
class MiniSleepCard extends StatelessWidget {
  final double hours;
  final int score;
  final VoidCallback onTap;

  const MiniSleepCard({super.key, required this.hours, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool hasData = hours > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        // 🎯 Glass with a very subtle tint of the secondary color for differentiation
        decoration: _getGlassDecoration(context, tint: colorScheme.secondary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.bedtime_rounded, color: colorScheme.secondary, size: 18),
                Text("${context.tr("dashboard_sleep")}", style: TextStyle(color: colorScheme.secondary, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),

            if (hasData)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(text: hours.floor().toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                          TextSpan(text: "h ", style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6))),
                          TextSpan(text: ((hours - hours.floor()) * 60).toInt().toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                          TextSpan(text: "m", style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6))),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: colorScheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text("Score: $score", style: TextStyle(color: colorScheme.secondary, fontSize: 10, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              )
            else
              Expanded(child: Center(child: Text("${context.tr("dashboard_log_rest")}", textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600)))),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 4. PREMIUM BREATHING CARD
// =================================================================
class MiniBreathingCard extends StatelessWidget {
  final int minutesLogged;
  final VoidCallback onTap;

  const MiniBreathingCard({super.key, required this.minutesLogged, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        // 🎯 Glass with a subtle tint of the primary color
        decoration: _getGlassDecoration(context, tint: colorScheme.primary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.self_improvement_rounded, color: colorScheme.primary, size: 20),
                if (minutesLogged > 0) Icon(Icons.check_circle, color: colorScheme.primary, size: 16),
              ],
            ),

            const Spacer(),

            if (minutesLogged > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(child: Text("$minutesLogged", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1.0))),
                  Text("${context.tr("dashboard_min_mindful")}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${context.tr("dashboard_take_a_breath")}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colorScheme.onSurface, height: 1.1)),
                  const SizedBox(height: 4),
                  Text("${context.tr("dashboard_start_now")}", style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}