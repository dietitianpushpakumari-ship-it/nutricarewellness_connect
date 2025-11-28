import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/wellness_reccomender_service.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:collection/collection.dart';

// 🎯 LOGIC IMPORTS
import 'package:nutricare_connect/core/utils/wellness_tool_registry.dart';


// 🎯 SCREEN IMPORTS
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';
import 'package:nutricare_connect/core/utils/workout_config.dart';
import 'package:nutricare_connect/core/utils/workout_player_sheet.dart';
import 'package:nutricare_connect/core/utils/rhythm_pacer_sheet.dart';
import 'package:nutricare_connect/core/utils/eye-yoga_sheet.dart';
import 'package:nutricare_connect/core/utils/meal_pacer_sheet.dart';
import 'package:nutricare_connect/core/utils/neck_and_wrist_relief.dart';
import 'package:nutricare_connect/core/utils/posture_trainer_screen.dart';
import 'package:nutricare_connect/core/utils/kegal_trainer_sheet.dart';
import 'package:nutricare_connect/core/utils/spiritual_healing_sheet.dart';
import 'package:nutricare_connect/core/utils/worry_shreeder_sheet.dart';
import 'package:nutricare_connect/core/utils/zen_garden_sheet.dart';
import 'package:nutricare_connect/core/utils/grounding_panic_aid.dart';
import 'package:nutricare_connect/core/utils/gratitude_garden_sheet.dart';
import 'package:nutricare_connect/core/utils/focus_grid_sheet.dart';
import 'package:nutricare_connect/core/utils/isochronic_tapping.dart';
import 'package:nutricare_connect/core/utils/sleep_mixer_sheet.dart';
import 'package:nutricare_connect/core/utils/co2_tollerence_sheet.dart';
import 'package:nutricare_connect/core/utils/sleep_debt_bank.dart';
import 'package:nutricare_connect/core/utils/quiz_swipe_screen.dart';
import 'package:nutricare_connect/core/utils/geeta_library_screen.dart';

class WellnessHubScreen extends ConsumerWidget {
  final ClientModel client;
  const WellnessHubScreen({super.key, required this.client});

  void _handleToolTap(BuildContext context, String routeKey, WidgetRef ref, ClientModel client) {
    final state = ref.read(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);
    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    switch (routeKey) {
      case 'quickfit': _showWorkoutMenu(context); break;
      case 'cardio': _launchSheet(context, const RhythmPacerSheet()); break;
      case 'posture': Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: PostureTrainerSheet()))); break;
      case 'neck': _launchSheet(context, const NeckWristSheet(isNeck: true)); break;
      case 'wrist': _launchSheet(context, const NeckWristSheet(isNeck: false)); break;
      case 'kegel': _launchSheet(context, const KegelTrainerSheet()); break;

      case 'breathing':
        if (state.activePlan != null) _showBreathingMenu(context, notifier, state.activePlan!, dailyLog);
        break;
      case 'focus': _launchSheet(context, const FocusGridSheet()); break;
      case 'eye': _launchSheet(context, const EyeYogaSheet()); break;
      case 'worry': _launchSheet(context, const WorryShredderSheet()); break;
      case 'zen': _launchSheet(context, const ZenGardenSheet()); break;
      case 'co2': _launchSheet(context, const Co2ToleranceSheet()); break;
      case 'tapping': _launchSheet(context, const IsochronicTappingSheet()); break;

      case 'mantra': _launchSheet(context, const SpiritualHealingSheet()); break;
      case 'geeta': Navigator.push(context, MaterialPageRoute(builder: (_) => const GeetaLibraryScreen())); break;
      case 'sleep_mix': _launchSheet(context, const SleepMixerSheet()); break;
      case 'gratitude': _launchSheet(context, const GratitudeGardenSheet()); break;
      case 'panic': _launchSheet(context, const GroundingGameSheet()); break;
      case 'sleep_debt': _launchSheet(context, const SleepDebtSheet()); break;

      case 'quiz': Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizSwipeScreen())); break;
      case 'meal_pacer': _launchSheet(context, const MealPacerSheet()); break;

      default: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feature coming soon!")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = WellnessRecommender.getRecommendations();
    final hour = DateTime.now().hour;
    String greeting = "Good Morning";
    if (hour >= 12) greeting = "Good Afternoon";
    if (hour >= 17) greeting = "Good Evening";
    if (hour >= 21) greeting = "Sleep Well";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  Text(client.name ?? "Wellness Warrior", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text("Recommended for You", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SizedBox(
                  height: 140,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.9),
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      final tool = recommendations[index];
                      return _buildHeroCard(context, tool, () => _handleToolTap(context, tool.routeKey, ref, client));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          _buildCategorySection(context, ref, "Move & Energize", WellnessCategory.physical, client),
          _buildCategorySection(context, ref, "Calm & Focus", WellnessCategory.mental, client),
          _buildCategorySection(context, ref, "Soul & Sleep", WellnessCategory.spiritual, client),
          _buildLearningSection(context, ref, client),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, WidgetRef ref, String title, WellnessCategory category, ClientModel client) {
    List<WellnessTool> tools = WellnessRecommender.getByCategory(category);
    if (category == WellnessCategory.spiritual) {
      tools.addAll(WellnessRecommender.getByCategory(WellnessCategory.sleep));
    }
    if (tools.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          ),
          SizedBox(
            height: 145,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return _buildBentoCard(context, tool, () => _handleToolTap(context, tool.routeKey, ref, client));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningSection(BuildContext context, WidgetRef ref, ClientModel client) {
    final tools = WellnessRecommender.getByCategory(WellnessCategory.learning);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Daily Learning", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 10),
            ...tools.map((tool) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildWideCard(context, tool, () => _handleToolTap(context, tool.routeKey, ref, client)),
                )
            ).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, WellnessTool tool, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [tool.color, tool.color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: tool.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                    child: const Text("RECOMMENDED", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Text(tool.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(tool.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            Icon(tool.icon, color: Colors.white, size: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoCard(BuildContext context, WellnessTool tool, VoidCallback onTap) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 10, bottom: 10, top: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: tool.color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(tool.icon, color: tool.color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(tool.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(tool.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideCard(BuildContext context, WellnessTool tool, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: tool.color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(tool.icon, color: tool.color, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tool.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(tool.subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11))]),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  void _launchSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }

  // 🎯 RESTORED: EXPANDED MENUS for Breathing & Quick Fit

  void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel activePlan, ClientLogModel? dailyLog) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Breathing Exercises", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPresetTile(ctx, "Focus & Clarity", "Box Breathing (4-4-4-4)", Icons.crop_square, Colors.teal, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.box)),
            _buildPresetTile(ctx, "Sleep & Anxiety", "4-7-8 Technique", Icons.nightlight_round, Colors.indigo, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.relax)),
            _buildPresetTile(ctx, "Energy Boost", "Rapid Fire Breath", Icons.bolt, Colors.orange, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.energy)),
            _buildPresetTile(ctx, "Balance", "Coherence (Heart Sync)", Icons.favorite, Colors.pink, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.coherence)), // 🎯 NEW
          ],
        ),
      ),
    );
  }

  void _showWorkoutMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quick Workouts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPresetTile(ctx, "Morning Charge", "3 Min Wake Up", Icons.wb_sunny, Colors.orange, () => _launchWorkout(context, WorkoutConfig.morningStretch)),
            _buildPresetTile(ctx, "Desk De-Stress", "5 Min Neck & Back", Icons.chair, Colors.blue, () => _launchWorkout(context, WorkoutConfig.deskRelief)), // 🎯 NEW
          //  _buildPresetTile(ctx, "Sleep Stretch", "5 Min Unwind", Icons.bedtime, Colors.indigo, () => _launchWorkout(context, WorkoutConfig.sleepStretch)), // 🎯 NEW
            //_buildPresetTile(ctx, "Core Igniter", "7 Min Intensity", Icons.local_fire_department, Colors.red, () => _launchWorkout(context, WorkoutConfig.coreBlast)), // 🎯 NEW
          ],
        ),
      ),
    );
  }

  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel plan, ClientLogModel? log, BreathingConfig config) {
    Navigator.pop(context);
    _launchSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: config));
  }

  void _launchWorkout(BuildContext context, WorkoutConfig config) {
    Navigator.pop(context);
    _launchSheet(context, WorkoutPlayerSheet(config: config));
  }

  Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey), onTap: onTap);
  }
}