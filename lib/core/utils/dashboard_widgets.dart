import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/wave_clipper.dart';

// 🎨 PREMIUM DESIGN CONSTANTS
const double kCardRadius = 24.0; // Slightly reduced for tighter look
const BoxShadow kPremiumShadow = BoxShadow(
  color: Color(0x0D000000),
  blurRadius: 20,
  offset: Offset(0, 8),
);

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
    final bool isEmpty = currentLiters <= 0;
    final double progress = (currentLiters / (goalLiters == 0 ? 3.0 : goalLiters)).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kCardRadius),
          boxShadow: [kPremiumShadow],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 🌊 Background Wave
            if (!isEmpty)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: waveAnimation,
                  builder: (context, child) {
                    return ClipPath(
                      clipper: WaveClipper(waveProgress: waveAnimation.value, fillProgress: progress),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [Color(0xFF4FC3F7), Color(0xFF00BFA5)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 📝 Content
            Padding(
              padding: const EdgeInsets.all(14.0), // Reduced Padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.water_drop_rounded, color: progress > 0.5 ? Colors.white : const Color(0xFF00BFA5), size: 20),
                      if (progress >= 1.0) const Icon(Icons.verified, color: Colors.white, size: 16),
                    ],
                  ),
                  if (isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Hydrate", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF00695C))),
                        const SizedBox(height: 2),
                        Text("Goal: ${goalLiters}L", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("$percent%", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: progress > 0.5 ? Colors.white : const Color(0xFF263238), height: 1.0)),
                        const SizedBox(height: 2),
                        Text("${currentLiters.toStringAsFixed(1)}L", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: progress > 0.5 ? Colors.white.withOpacity(0.9) : Colors.grey.shade600)),
                      ],
                    ),
                ],
              ),
            ),

            // ➕ Add Button
            Positioned(
              bottom: 10, right: 10,
              child: InkWell(
                onTap: onQuickAdd,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                  child: const Icon(Icons.add, size: 16, color: Color(0xFF00BFA5)),
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
// 2. PREMIUM STEP CARD (Fixed Overflow)
// =================================================================
class MiniStepCard extends StatelessWidget {
  final int steps;
  final int goal;
  final VoidCallback onTap;

  const MiniStepCard({super.key, required this.steps, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double progress = (steps / (goal == 0 ? 8000 : goal)).clamp(0.0, 1.0);
    final Color ringColor = progress >= 1.0 ? const Color(0xFF43A047) : const Color(0xFFFF7043);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14), // 🎯 Reduced Padding to prevent overflow
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kCardRadius),
          boxShadow: [kPremiumShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row
            Row(
              children: [
                Icon(Icons.directions_run_rounded, color: Colors.grey.shade400, size: 18),
                const Spacer(),
                if (progress >= 1.0) const Icon(Icons.star, color: Colors.amber, size: 14),
              ],
            ),

            // Centered Ring (Flexible to take available space)
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 65, width: 65, // Slightly smaller ring
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(value: 1.0, strokeWidth: 6, color: Colors.grey.shade100),
                      CircularProgressIndicator(value: progress, strokeWidth: 6, color: ringColor, strokeCap: StrokeCap.round),

                      // 🎯 FIX: FittedBox ensures inner text never overflows the ring
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 14, color: ringColor),
                            Text("${(progress * 100).toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Stats (Flexible to prevent bottom overflow)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(child: Text("$steps", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87))),
                  const Text("Steps", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
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
// 3. PREMIUM SLEEP CARD
// =================================================================
class MiniSleepCard extends StatelessWidget {
  final double hours;
  final int score;
  final VoidCallback onTap;

  const MiniSleepCard({super.key, required this.hours, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool hasData = hours > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2E3A59), Color(0xFF151925)]),
          borderRadius: BorderRadius.circular(kCardRadius),
          boxShadow: [BoxShadow(color: const Color(0xFF2E3A59).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.bedtime_rounded, color: Color(0xFF9FA8DA), size: 18),
                Text("Sleep", style: TextStyle(color: Color(0xFF9FA8DA), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),

            if (hasData)
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(text: hours.floor().toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          const TextSpan(text: "h ", style: TextStyle(fontSize: 12, color: Colors.white70)),
                          TextSpan(text: ((hours - hours.floor()) * 60).toInt().toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          const TextSpan(text: "m", style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)), child: Text("Score: $score", style: const TextStyle(color: Color(0xFFB39DDB), fontSize: 10, fontWeight: FontWeight.bold))),
                  ],
                ),
              )
            else
              const Expanded(child: Center(child: Text("Log\nRest", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)))),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 4. PREMIUM BREATHING CARD (Calm & Soft)
// =================================================================
class MiniBreathingCard extends StatelessWidget {
  final int minutesLogged;
  final VoidCallback onTap;

  const MiniBreathingCard({super.key, required this.minutesLogged, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [kPremiumShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.self_improvement_rounded, color: Colors.teal.shade700, size: 20),
                if (minutesLogged > 0) Icon(Icons.check_circle, color: Colors.teal.shade400, size: 16),
              ],
            ),

            const Spacer(),

            if (minutesLogged > 0)
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(child: Text("$minutesLogged", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.teal.shade800, height: 1.0))),
                    Text("min mindful", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade600)),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Take a\nBreath", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.teal.shade800, height: 1.1)),
                  const SizedBox(height: 4),
                  Text("Start Now", style: TextStyle(fontSize: 10, color: Colors.teal.shade600, fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}