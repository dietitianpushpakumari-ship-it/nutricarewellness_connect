import 'dart:collection';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/daily_wellness_entry_dialog.dart';

import '../../features/dietplan/domain/entities/diet_plan_item_model.dart'; // For sleep/wellness
// Import your meal logging dialog if you want to trigger it directly

class PendingActionsBanner extends ConsumerWidget {
  final String clientId;
  const PendingActionsBanner({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDietPlanProvider);
    final now = DateTime.now();

    // 1. Only show after 6 PM
    if (now.hour > 18) return const SizedBox.shrink();

    // 2. Check what is missing
    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    bool missingWellness = dailyLog == null;
    // Assuming standard 3 meals + 1 snack = 4 logs approx
    int mealCount = state.dailyLogs.where((l) => l.mealName != 'DAILY_WELLNESS_CHECK').length;
    bool missingMeals = mealCount < 3;

    if (!missingWellness && !missingMeals) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
            begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Finish Your Day", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  _getMissingText(missingWellness, missingMeals),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Trigger the wellness dialog as a catch-all
              // You could also show a bottom sheet with links to both
              showDialog(
                  context: context,
                  builder: (_) => DailyWellnessEntryDialog(
                    notifier: ref.read(dietPlanNotifierProvider(clientId).notifier),
                    activePlan: state.activePlan!,
                    dailyMetricsLog: dailyLog,
                  )
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36)
            ),
            child: const Text("Log Now"),
          ),
        ],
      ),
    );
  }

  String _getMissingText(bool wellness, bool meals) {
    if (wellness && meals) return "You haven't logged your meals or wellness check yet.";
    if (wellness) return "Don't forget your Daily Wellness Check-in!";
    return "You missed logging some meals today.";
  }
}