import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

// 🎯 Models & Providers
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/models/vitals_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 Sheets & Screens
import 'package:pure_shift/new/dietplan/meal_detail_sheet.dart';
import 'package:pure_shift/new/dietplan/hydration_detail_screen.dart';
import 'package:pure_shift/new/dashboard/daily_log_logging_screen.dart';
import 'package:pure_shift/elite_nudge_hub.dart';

import 'layout_utils.dart';

class TickerNudge {
  final String title;
  final String priority;
  final VoidCallback? onTap;
  TickerNudge({required this.title, required this.priority, this.onTap});
}

class UnifiedNudgeRow extends ConsumerStatefulWidget {
  final String clientId;
  const UnifiedNudgeRow({super.key, required this.clientId});

  @override
  ConsumerState<UnifiedNudgeRow> createState() => _UnifiedNudgeRowState();
}

class _UnifiedNudgeRowState extends ConsumerState<UnifiedNudgeRow> {
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<TickerNudge> _generateLiveNudges() {
    final state = ref.watch(activeDietPlanProvider);
    final plan = state.activePlan;
    final dailyRecord = state.dailyRecord;
    List<TickerNudge> nudges = [];

    // Simulated Nudges for demo (Ensure your real logic is here)
    nudges.add(TickerNudge(title: "MISSED MEAL: Lunch is pending. Tap to log.", priority: "high"));

    if (plan != null) {
      final currentWater = dailyRecord?.hydrationLiters ?? 0.0;
      final waterGoal = plan.dailyWaterGoal > 0 ? plan.dailyWaterGoal : 2.0;
      if (currentWater < waterGoal) {
        nudges.add(TickerNudge(
          title: "HYDRATE: ${(waterGoal - currentWater).toStringAsFixed(1)}L remaining.",
          priority: "medium",
          onTap: () { /* Launch Hydration Sheet */ },
        ));
      }
    }

    final currentSteps = dailyRecord?.stepCount ?? 0;
    nudges.add(TickerNudge(title: "ACTIVITY: $currentSteps steps logged.", priority: "low"));
    nudges.add(TickerNudge(title: "INBOX: New clinical messages ready.", priority: "info"));

    return nudges;
  }

  Color _getPriorityColor(String priority, bool isDark) {
    switch (priority.toLowerCase()) {
      case 'high': return isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);
      case 'medium': return isDark ? const Color(0xFFFFD54F) : const Color(0xFFF57C00);
      case 'low': return isDark ? const Color(0xFF00E676) : const Color(0xFF388E3C);
      case 'info': return isDark ? const Color(0xFF448AFF) : const Color(0xFF1976D2);
      default: return Colors.grey;
    }
  }

  // 🚀 THE NEW GLOW ENGINE: Returns blur radius based on priority
  double _getGlowIntensity(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return 12.0;   // Massive radioactive glow
      case 'medium': return 8.0;  // Solid warning glow
      default: return 3.0;        // Soft ambient sheen
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final activeNudges = _generateLiveNudges();
    if (activeNudges.isEmpty) return const SizedBox.shrink();

    final displayIndex = _currentIndex % activeNudges.length;
    final currentNudge = activeNudges[displayIndex];

    final glowColor = _getPriorityColor(currentNudge.priority, isDark);
    final glowRadius = _getGlowIntensity(currentNudge.priority);

    final parts = currentNudge.title.split(':');
    final categoryTitle = parts.isNotEmpty ? parts[0].trim() : "";
    final subMessage = parts.length > 1 ? parts.sublist(1).join(':').trim() : "";

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(4)),
      // 🚀 1. REMOVED THE ROW AND FLEX SPLITS. IT NOW TAKES FULL WIDTH!
      child: GestureDetector(
        onTap: () {
          if (currentNudge.onTap != null) {
            HapticFeedback.lightImpact();
            currentNudge.onTap!();
          }
        },
        child: Container(
          height: context.scale(44), // Slightly taller for breathing room
          padding: EdgeInsets.symmetric(horizontal: context.scale(16)),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(context.scale(12)),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              // 🚀 Priority-Glowing Icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(glowColor),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withOpacity(0.6),
                          blurRadius: glowRadius,
                        )
                      ]
                  ),
                  child: Icon(
                      Icons.notifications_active_rounded,
                      color: glowColor,
                      size: context.scale(18)
                  ),
                ),
              ),
              SizedBox(width: context.scale(12)),

              // 🚀 The Flipping Text Animation
              // 🚀 The Flipping Text Animation
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Align(
                    key: ValueKey(currentNudge.title),
                    alignment: Alignment.centerLeft,
                    child: Row( // Use Row instead of RichText to separate Category and SubMessage
                      children: [
                        // 🚀 STACK FOR CATEGORY TITLE (Crisp text + Background Glow)
                        Stack(
                          children: [
                            // 1. The Background Glow Layer (Blurry)
                            Text(
                              "$categoryTitle: ",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.transparent, // Invisible text, just the shadow
                                fontSize: context.scale(12),
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: glowColor.withOpacity(0.8),
                                    blurRadius: glowRadius,
                                  )
                                ],
                              ),
                            ),
                            // 2. The Foreground Text Layer (Sharp)
                            Text(
                              "$categoryTitle: ",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: glowColor, // Sharp text color
                                fontSize: context.scale(12),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),

                        // SubMessage (No Glow, just clean text)
                        Expanded(
                          child: Text(
                            subMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colorScheme.onSurface,
                              fontSize: context.scale(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 🚀 A subtle trailing arrow to show it's clickable
              Icon(Icons.chevron_right_rounded, size: context.scale(18), color: theme.hintColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}