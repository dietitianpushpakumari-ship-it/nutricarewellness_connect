import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/wave_clipper.dart';

// =================================================================
// 1. MINI HYDRATION CARD (Live Wave + Quick Add)
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
    final double progress = (currentLiters / (goalLiters == 0 ? 3.0 : goalLiters)).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias, // Clips the wave inside
        child: Stack(
          children: [
            // 🌊 The Wave Background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: waveAnimation,
                builder: (context, child) {
                  return ClipPath(
                    clipper: WaveClipper(waveProgress: waveAnimation.value, fillProgress: progress),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF0077B6), Color(0xFF48CAE4)],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 📝 Content Overlay
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon & Label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.water_drop, color: progress > 0.5 ? Colors.white : Colors.blue, size: 20),
                      if (progress >= 1.0)
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    ],
                  ),

                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$percent%",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: progress > 0.6 ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        "${currentLiters.toStringAsFixed(1)}L",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: progress > 0.6 ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ➕ Quick Add Button (Floating)
            Positioned(
              bottom: 8,
              right: 8,
              child: InkWell(
                onTap: onQuickAdd,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.add, size: 18, color: Colors.blue),
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
// 2. MINI STEP CARD (Radial Progress)
// =================================================================
class MiniStepCard extends StatelessWidget {
  final int steps;
  final int goal;
  final VoidCallback onTap;

  const MiniStepCard({
    super.key,
    required this.steps,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (steps / (goal == 0 ? 8000 : goal)).clamp(0.0, 1.0);
    final Color ringColor = progress >= 1.0 ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.directions_walk, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text("Movement", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ],
            ),

            // Radial Graph
            SizedBox(
              height: 80,
              width: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    color: Colors.grey.shade100,
                  ),
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    color: ringColor,
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, size: 16, color: ringColor),
                      Text(
                        "${(progress * 100).toInt()}%",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Text(
              "$steps Steps",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 3. MINI SLEEP CARD (Simple Stat)
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2E3A59), // Dark Indigo
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.bedtime, color: Colors.white, size: 20),
                Text("Sleep", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),

            if (hasData) ...[
              Text(
                "${hours.toStringAsFixed(1)} hr",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text("Score: $score", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Log\nSleep", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ),
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.add_circle_outline, color: Colors.white54, size: 20),
              )
            ],
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 4. MINI BREATHING CARD
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.self_improvement, color: Colors.teal.shade700, size: 20),
                if (minutesLogged > 0)
                  const Icon(Icons.check, color: Colors.teal, size: 16),
              ],
            ),

            const Spacer(),
            Text(
              minutesLogged > 0 ? "$minutesLogged min" : "Start\nBreathe",
              style: TextStyle(
                  fontSize: minutesLogged > 0 ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900
              ),
            ),
            if (minutesLogged == 0)
              Text("Relax now", style: TextStyle(fontSize: 11, color: Colors.teal.shade600)),
          ],
        ),
      ),
    );
  }
}