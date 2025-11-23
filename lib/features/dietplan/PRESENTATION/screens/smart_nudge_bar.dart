import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';

import '../../domain/entities/diet_plan_item_model.dart';

class SmartNudgeBar extends ConsumerWidget {
  final String clientId;
  const SmartNudgeBar({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDietPlanProvider);
    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    // 1. Check Status
    final double water = dailyLog?.hydrationLiters ?? 0;
    final int steps = dailyLog?.stepCount ?? 0;
    final int breath = dailyLog?.breathingMinutes ?? 0;
    final int goalSteps = state.activePlan?.dailyStepGoal ?? 8000;

    // 2. Define Nudges
    List<Widget> nudges = [];

    // Water Nudge (Show if < 2.5L)
    if (water < 2.5) {
      nudges.add(_buildNudgeChip(
          context,
          "💧 +250ml",
          Colors.blue, // This is a MaterialColor
              () => _quickAddWater(ref, state.activePlan!, dailyLog, water)
      ));
    }

    // Movement Nudge (Show if < 50% of goal)
    if (steps < (goalSteps * 0.5)) {
      nudges.add(_buildNudgeChip(
          context,
          "👟 Move",
          Colors.orange, // This is a MaterialColor
              () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Time for a quick walk!")))
      ));
    }

    // Breathing Nudge (Show if not done yet)
    if (breath == 0) {
      nudges.add(_buildNudgeChip(
          context,
          "🧘 Breathe",
          Colors.teal, // This is a MaterialColor
              () {
            // Launch Breathing Sheet directly
            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BreathingDetailSheet(
                  notifier: ref.read(dietPlanNotifierProvider(clientId).notifier),
                  activePlan: state.activePlan!,
                  dailyLog: dailyLog,
                  config: BreathingConfig.energy, // Quick Energy boost
                )
            );
          }
      ));
    }

    if (nudges.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const Center(child: Text("Quick Actions:  ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
          ...nudges.map((n) => Padding(padding: const EdgeInsets.only(right: 8), child: n)),
        ],
      ),
    );
  }

  // 🎯 FIX: Changed 'Color' to 'MaterialColor' to access .shade900
  Widget _buildNudgeChip(BuildContext context, String label, MaterialColor color, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      avatar: Icon(Icons.flash_on, size: 14, color: color),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      // Now .shade900 is valid because we specified MaterialColor
      labelStyle: TextStyle(color: color.shade900, fontWeight: FontWeight.bold, fontSize: 12),
      onPressed: onTap,
    );
  }

  Future<void> _quickAddWater(WidgetRef ref, dynamic activePlan, ClientLogModel? log, double current) async {
    final notifier = ref.read(dietPlanNotifierProvider(clientId).notifier);
    final newTotal = (current + 0.25).clamp(0.0, 10.0);
    final logToSave = log ?? ClientLogModel(
      id: '',
      clientId: activePlan.clientId,
      dietPlanId: activePlan.id,
      mealName: 'DAILY_WELLNESS_CHECK',
      actualFoodEaten: ['Daily Wellness Data'],
      date: DateTime.now(),
    );
    await notifier.createOrUpdateLog(log: logToSave.copyWith(hydrationLiters: newTotal), mealPhotoFiles: const []);
  }
}