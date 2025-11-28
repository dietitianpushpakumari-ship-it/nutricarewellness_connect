import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/core/utils/sleep_details_screen.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:collection/collection.dart';

import '../../features/dietplan/domain/entities/diet_plan_item_model.dart';

class DailyCompletionBanner extends ConsumerWidget {
  final String clientId;
  final ClientModel client; // Need client for navigation if we go to plan

  const DailyCompletionBanner({
    super.key,
    required this.clientId,
    required this.client
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDietPlanProvider);

    // 1. Time Check (Only show in Evening/Night)
    final hour = DateTime.now().hour;
    if (hour < 18) return const SizedBox.shrink(); // Hidden during day

    // 2. Data Checks
    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    // Check Wellness (Sleep/Mood/Energy) - Assumes sleepQualityRating > 0 means logged
    final bool isWellnessDone = dailyLog != null && (dailyLog.sleepQualityRating != null && dailyLog.sleepQualityRating! > 0);

    // Check Meals (Simple count check: Are at least 3 meals logged?)
    final int mealsLogged = state.dailyLogs.where((l) => l.mealName != 'DAILY_WELLNESS_CHECK').length;
    final bool areMealsDone = mealsLogged >= 3;

    // 3. Exit if everything is done
    if (isWellnessDone && areMealsDone) return const SizedBox.shrink();

    // 4. Determine Message & Action
    String title = "Finish Your Day";
    String subtitle = "";
    VoidCallback onAction;
    String btnLabel = "Log Now";

    if (!isWellnessDone) {
      title = "Sleep & Wellness Check";
      subtitle = "Log your sleep, mood & energy before bed.";
      onAction = () {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SleepDetailSheet(
              notifier: ref.read(dietPlanNotifierProvider(clientId).notifier),
              activePlan: state.activePlan!,
              dailyLog: dailyLog,
            )
        );
      };
    } else {
      // Meals missing
      title = "Missing Meal Logs";
      subtitle = "You've logged $mealsLogged meals. Did you have dinner?";
      btnLabel = "View Plan";
      onAction = () {
        // Switch to Plan Tab (Index 1)
        // Note: This requires access to the parent tab controller or a global key.
        // For a robust standalone widget, we can just navigate to the Plan Screen directly or show a message.
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Go to the 'Plan' tab to log your remaining meals."))
        );
      };
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2E3A59), Color(0xFF4B5D85)], // Night Blue Theme
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.bedtime, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2E3A59),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
            ),
            child: Text(btnLabel),
          ),
        ],
      ),
    );
  }
}