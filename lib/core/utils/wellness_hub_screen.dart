import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

  // 🎯 CENTRALIZED NAVIGATION ROUTER
  void _handleToolTap(BuildContext context, String routeKey, WidgetRef ref, ClientModel client) {
    final state = ref.read(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);
    final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    switch (routeKey) {
    // Physical
      case 'quickfit': _showWorkoutMenu(context); break;
      case 'cardio': _launchSheet(context, const RhythmPacerSheet()); break;
      case 'posture': Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: PostureTrainerSheet()))); break;
      case 'neck': _launchSheet(context, const NeckWristSheet(isNeck: true)); break;
      case 'wrist': _launchSheet(context, const NeckWristSheet(isNeck: false)); break;
      case 'kegel': _launchSheet(context, const KegelTrainerSheet()); break;

    // Mental
      case 'breathing':
        if (state.activePlan != null) _showBreathingMenu(context, notifier, state.activePlan!, dailyLog);
        break;
      case 'focus': _launchSheet(context, const FocusGridSheet()); break;
      case 'eye': _launchSheet(context, const EyeYogaSheet()); break;
      case 'worry': _launchSheet(context, const WorryShredderSheet()); break;
      case 'zen': _launchSheet(context, const ZenGardenSheet()); break;
      case 'co2': _launchSheet(context, const Co2ToleranceSheet()); break;
      case 'tapping': _launchSheet(context, const IsochronicTappingSheet()); break;

    // Spiritual / Sleep
      case 'mantra': _launchSheet(context, const SpiritualHealingSheet()); break;
      case 'geeta': Navigator.push(context, MaterialPageRoute(builder: (_) => const GeetaLibraryScreen())); break;
      case 'sleep_mix': _launchSheet(context, const SleepMixerSheet()); break;
      case 'gratitude': _launchSheet(context, const GratitudeGardenSheet()); break;
      case 'panic': _launchSheet(context, const GroundingGameSheet()); break;
      case 'sleep_debt': _launchSheet(context, const SleepDebtSheet()); break;

    // Learning
      case 'quiz': Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizSwipeScreen())); break;
      case 'meal_pacer': _launchSheet(context, const MealPacerSheet()); break;

      default: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feature coming soon!")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = WellnessRecommender.getRecommendations();

    // Time-based greeting
    final hour = DateTime.now().hour;
    String greeting = "Good Morning";
    if (hour >= 12) greeting = "Good Afternoon";
    if (hour >= 17) greeting = "Good Evening";
    if (hour >= 21) greeting = "Sleep Well";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          // 1. Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  Text(client.name ?? "Wellness Warrior", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                ],
              ),
            ),
          ),

          // 2. 🎯 SMART RECOMMENDER CAROUSEL
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text("Recommended for You", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SizedBox(
                  height: 160,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.85),
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

          const SliverToBoxAdapter(child: SizedBox(height: 30)),

          // 3. DYNAMIC CATEGORY RAILS
          // Note: We create rails dynamically from the Registry logic
          _buildCategorySection(context, ref, "Move & Energize", WellnessCategory.physical, client),
          _buildCategorySection(context, ref, "Calm & Focus", WellnessCategory.mental, client),
          _buildCategorySection(context, ref, "Soul & Sleep", WellnessCategory.spiritual, client), // Includes sleep

          // 4. Learning Section (Large Card)
          _buildLearningSection(context, ref, client),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildCategorySection(BuildContext context, WidgetRef ref, String title, WellnessCategory category, ClientModel client) {
    // Merge Sleep into Spiritual row if needed, or handle separately
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          ),
          SizedBox(
            height: 180,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Daily Learning", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 10),
            ...tools.map((tool) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [tool.color, tool.color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: tool.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
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
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: const Text("TRY NOW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Text(tool.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(tool.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            Icon(tool.icon, color: Colors.white, size: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoCard(BuildContext context, WellnessTool tool, VoidCallback onTap) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12, bottom: 12, top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: tool.color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(tool.icon, color: tool.color, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(tool.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                )
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: tool.color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(tool.icon, color: tool.color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tool.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(tool.subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  // --- HELPER METHODS (Menus) ---
  void _launchSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }

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
            const Text("Choose a Mode", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPresetTile(ctx, "Focus & Clarity", "Box Breathing", Icons.crop_square, Colors.teal, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.box)),
            _buildPresetTile(ctx, "Sleep & Anxiety", "4-7-8 Relaxing", Icons.nightlight_round, Colors.indigo, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.relax)),
            _buildPresetTile(ctx, "Energy Boost", "Rapid Awakening", Icons.bolt, Colors.orange, () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.energy)),
          ],
        ),
      ),
    );
  }

  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel plan, ClientLogModel? log, BreathingConfig config) {
    Navigator.pop(context);
    _launchSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: config));
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
            const Text("Choose a Routine", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPresetTile(ctx, "Morning Warmup", "Wake Up (3 min)", Icons.wb_sunny, Colors.orange, () => _launchWorkout(context, WorkoutConfig.morningStretch)),
            _buildPresetTile(ctx, "7-Min HIIT", "Fat Burn", Icons.local_fire_department, Colors.red, () => _launchWorkout(context, WorkoutConfig.quickHIIT)),
            _buildPresetTile(ctx, "Desk Detox", "Stiff Neck Relief", Icons.chair, Colors.blue, () => _launchWorkout(context, WorkoutConfig.deskRelief)),
          ],
        ),
      ),
    );
  }

  void _launchWorkout(BuildContext context, WorkoutConfig config) {
    Navigator.pop(context);
    _launchSheet(context, WorkoutPlayerSheet(config: config));
  }

  Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}