import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/wellness_reccomender_service.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/features/content/quiz_swipe_screen.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
                                     // FlatClientDietPlanModel
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/new/service/client_service.dart';
import 'package:collection/collection.dart';

import 'package:nutricare_connect/new/wellnesshub/BalanceLockSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/BiometricScannerSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/Co2ToleranceSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/IsometricBPPacerSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/SomaticFluidSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/SomaticPopItSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/SpineDecompressionSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/VagusNerveResetSheet.dart';
import 'package:nutricare_connect/new/wellnesshub/brainwave_pomodoro_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/eft_tapping_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/emdr_pacer_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/stroop_test_sheet.dart';

// 🎯 LOGIC IMPORTS
import 'package:nutricare_connect/new/wellnesshub/wellness_tool_registry.dart';

// 🎯 SCREEN IMPORTS
import 'package:nutricare_connect/new/wellnesshub/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/mindfullness_config.dart';
import 'package:nutricare_connect/core/utils/workout_config.dart';
import 'package:nutricare_connect/new/wellnesshub/workout_player_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/rhythm_pacer_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/eye-yoga_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/meal_pacer_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/neck_and_wrist_relief.dart';
import 'package:nutricare_connect/new/wellnesshub/posture_trainer_screen.dart';
import 'package:nutricare_connect/core/utils/kegal_trainer_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/spiritual_healing_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/worry_shreeder_sheet.dart';
import 'package:nutricare_connect/core/utils/zen_garden_sheet.dart';
import 'package:nutricare_connect/core/utils/grounding_panic_aid.dart';
import 'package:nutricare_connect/new/wellnesshub/gratitude_garden_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/focus_grid_sheet.dart';
import 'package:nutricare_connect/core/utils/isochronic_tapping.dart';
import 'package:nutricare_connect/new/wellnesshub/sleep_mixer_sheet.dart';
import 'package:nutricare_connect/new/wellnesshub/sleep_debt_bank.dart';

import 'package:nutricare_connect/features/content/geeta_library_screen.dart';

import '../FlatClientDietPlanModel.dart';

class WellnessHubScreen extends ConsumerWidget {
  final ClientModel client;
  const WellnessHubScreen({super.key, required this.client});

  void _handleToolTap(BuildContext context, String routeKey, WidgetRef ref, ClientModel client) {
    final state = ref.read(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    // 🎯 Haptic feedback for a premium, tactile feel
    HapticFeedback.selectionClick();

    // 🎯 ATOMIC FIX: Use the single daily record directly
    final dailyRecord = state.dailyRecord;

    switch (routeKey) {
      case 'quickfit': _showWorkoutMenu(context, Theme.of(context)); break;
      case 'cardio': _launchSheet(context, const RhythmPacerSheet()); break;
      case 'posture': Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: PostureTrainerSheet()))); break;
      case 'neck': _launchSheet(context, const NeckWristSheet(isNeck: true)); break;
      case 'wrist': _launchSheet(context, const NeckWristSheet(isNeck: false)); break;
      case 'kegel': _launchSheet(context, const KegelTrainerSheet()); break;
      case 'bp_hold': _launchSheet(context, const IsometricBPPacerSheet()); break;
      case 'vitals_scan': _launchBiometricScanner(context); break;

      case 'glucose_pulse':
        _launchSheet(context, const RhythmPacerSheet(
            prescription: CardioPrescription(
              sets: 3, targetReps: 20,
              tempo: ClinicalTempo(eccentricMs: 1500, isometricMs: 500, concentricMs: 1000),
              maxSafeRpe: 5,
            )
        ));
        break;

      case 'balance': _launchSheet(context, const BalanceLockSheet()); break;
      case 'spine_decompression': _launchSheet(context, const SpineDecompressionSheet()); break;

      case 'breathing':
      // 🎯 SAFETY CHECK: Ensure plan exists before opening the menu
        if (state.activePlan != null) {
          _showBreathingMenu(context, notifier, state.activePlan!, dailyRecord, Theme.of(context));
        } else {
          _showNoPlanSnippet(context);
        }
        break;
      case 'focus': _launchSheet(context, const FocusGridSheet()); break;
      case 'eye': _launchSheet(context, const EyeYogaSheet()); break;
      case 'worry': _launchSheet(context, const WorryShredderSheet()); break;
      case 'zen': _launchSheet(context, const ZenGardenSheet()); break;
      case 'tapping': _launchSheet(context, const IsochronicTappingSheet()); break;
      case 'vagus_reset': _launchSheet(context, const VagusNerveResetSheet()); break;
      case 'emdr': _launchSheet(context, const EmdrPacerSheet()); break;
      case 'stroop': _launchSheet(context, const StroopTestSheet()); break;
      case 'pomodoro': _launchSheet(context, const BrainwavePomodoroSheet()); break;
      case 'eft_tapping': _launchSheet(context, const EftTappingSheet()); break;

      case 'mantra': _launchSheet(context, const SpiritualHealingSheet()); break;
      case 'geeta': Navigator.push(context, MaterialPageRoute(builder: (_) => const GeetaLibraryScreen())); break;
      case 'sleep_mix': _launchSheet(context, const SleepMixerSheet()); break;
      case 'gratitude': _launchSheet(context, const GratitudeGardenSheet()); break;
      case 'panic': _launchSheet(context, const GroundingGameSheet()); break;
      case 'sleep_debt': _launchSheet(context, const SleepDebtSheet()); break;

      case 'quiz': Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizSwipeScreen())); break;
      case 'meal_pacer': _launchSheet(context, const MealPacerSheet()); break;
      case 'co2_tolerance': _launchSheet(context, const Co2ToleranceSheet()); break;
      case 'somatic_popit': _launchSheet(context, const SomaticPopItSheet()); break;
      case 'somatic_fluid': _launchSheet(context, const SomaticFluidSheet()); break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text("Feature coming soon!"), backgroundColor: Theme.of(context).colorScheme.primary)
        );
    }
  }

  // 🎯 Helper to show a snackbar if no diet plan is active
  void _showNoPlanSnippet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please activate a diet plan to use this feature.")),
    );
  }

  // 🎯 ATOMIC FIX: Update menu helpers to accept FlatClientDietPlanModel
  void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan, ClientLogModel? dailyRecord, ThemeData theme) {
    showModalBottomSheet(
      isDismissible: true, // 🎯 Allowed dismissal for better UX
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(3)))),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text("Breathing Exercises", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildPresetTile(ctx, "Focus & Clarity", "Box Breathing (4-4-4-4)", Icons.crop_square_rounded, Colors.teal, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.box), theme),
                      _buildPresetTile(ctx, "Sleep & Anxiety", "4-7-8 Technique", Icons.nightlight_round, Colors.indigo, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.relax), theme),
                      _buildPresetTile(ctx, "Energy Boost", "Rapid Fire Breath", Icons.bolt_rounded, Colors.orange, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.energy), theme),
                      _buildPresetTile(ctx, "Balance", "Coherence (Heart Sync)", Icons.favorite_rounded, Colors.pink, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.coherence), theme),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor.withOpacity(0.1)))
                      ),
                      child: Text("Cancel", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final recommendations = WellnessRecommender.getRecommendations();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 🎨 Themed Background
      // 🎯 Added SafeArea so content doesn't hide behind the top notch/status bar
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text("Recommended for You", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)), // 🎨 Themed Text
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
            _buildCategorySection(context, ref, "Move & Energize", WellnessCategory.physical, client, theme, colorScheme, isDark),
            _buildCategorySection(context, ref, "Calm & Focus", WellnessCategory.mental, client, theme, colorScheme, isDark),
            _buildCategorySection(context, ref, "Soul & Sleep", WellnessCategory.spiritual, client, theme, colorScheme, isDark),
            _buildLearningSection(context, ref, client, theme, colorScheme, isDark),
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ],
        ),
      ),
    );
  }


  // 🎯 NEW: Helper function to handle async camera fetching
  Future<void> _launchBiometricScanner(BuildContext context) async {
    try {
      // 1. Fetch available physical cameras
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No camera hardware found.", style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
        return;
      }

      // 2. Open the Clinical Scanner Sheet
      if (context.mounted) {
        final int? bpmResult = await showModalBottomSheet<int>(
          isDismissible: false,
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BiometricScannerSheet(cameras: cameras),
        );

        // 3. Handle the returned medical data (Optional: Prompt Intervention)
        if (bpmResult != null && context.mounted) {
          _evaluateVitals(context, bpmResult);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Camera Error: $e", style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  // 🎯 NEW: Clinical Routing Logic based on BPM
  void _evaluateVitals(BuildContext context, int bpm) {
    if (bpm > 85) {
      // Patient is stressed (Sympathetic State)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text("High stress detected ($bpm BPM). Vagus Nerve Reset recommended before eating."),
            action: SnackBarAction(
              label: "START",
              textColor: Colors.white,
              onPressed: () => _launchSheet(context, const VagusNerveResetSheet()),
            ),
          )
      );
    } else {
      // Patient is relaxed (Parasympathetic State)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Vitals Optimal ($bpm BPM). Ready for nutrient absorption."),
            backgroundColor: Colors.green,
          )
      );
    }
  }

  Widget _buildCategorySection(BuildContext context, WidgetRef ref, String title, WellnessCategory category, ClientModel client, ThemeData theme, ColorScheme colorScheme, bool isDark) {
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
            child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colorScheme.onSurface)), // 🎨 Themed Text
          ),
          SizedBox(
            height: 145,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return _buildBentoCard(context, tool, () => _handleToolTap(context, tool.routeKey, ref, client), theme, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningSection(BuildContext context, WidgetRef ref, ClientModel client, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final tools = WellnessRecommender.getByCategory(WellnessCategory.learning);
    if (tools.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Daily Learning", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colorScheme.onSurface)), // 🎨 Themed Text
            const SizedBox(height: 10),
            ...tools.map((tool) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildWideCard(context, tool, () => _handleToolTap(context, tool.routeKey, ref, client), theme, colorScheme, isDark),
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

  Widget _buildBentoCard(BuildContext context, WellnessTool tool, VoidCallback onTap, ThemeData theme, bool isDark) {
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
              color: theme.cardColor, // 🎨 Themed Card
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)), // 🎨 Subtle border
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.04), blurRadius: 6, offset: const Offset(0, 3))],
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
                Text(tool.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)), // 🎨 Themed Text
                const SizedBox(height: 2),
                Text(tool.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.hintColor, fontSize: 11)), // 🎨 Themed Hint
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideCard(BuildContext context, WellnessTool tool, VoidCallback onTap, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: theme.cardColor, // 🎨 Themed Card
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)), // 🎨 Subtle border
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 6, offset: const Offset(0, 3))]
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: tool.color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(tool.icon, color: tool.color, size: 20)
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface)), // 🎨 Themed Text
                  Text(tool.subtitle, style: TextStyle(color: theme.hintColor, fontSize: 11)) // 🎨 Themed Hint
                ]
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: theme.iconTheme.color?.withOpacity(0.5), size: 18), // 🎨 Themed Icon
          ],
        ),
      ),
    );
  }

  void _launchSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(isDismissible : false,context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }

  // 🎯 RESTORED & THEMED: EXPANDED MENUS for Breathing & Quick Fit

  void _showWorkoutMenu(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      isDismissible: false,
      isScrollControlled: true, // 🎯 FIX 1: Allows height adjustment
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85, // 🎯 Safety constraint
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: SingleChildScrollView( // 🎯 FIX 2: Prevents overflow
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 Drag Handle
                const SizedBox(height: 16),
                Center(
                    child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2))
                    )
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text("Quick Workouts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildPresetTile(ctx, "Morning Charge", "3 Min Wake Up", Icons.wb_sunny_rounded, Colors.orange, () => _launchWorkout(context, WorkoutConfig.morningStretch), theme),
                      _buildPresetTile(ctx, "Desk De-Stress", "5 Min Neck & Back", Icons.chair_rounded, Colors.blue, () => _launchWorkout(context, WorkoutConfig.deskRelief), theme),
                    ],
                  ),
                ),

                // 🎯 Cancel Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.cardColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: theme.dividerColor.withOpacity(0.1))
                          )
                      ),
                      child: Text("Cancel", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, FlatClientDietPlanModel plan, ClientLogModel? log, BreathingConfig config) {
    Navigator.pop(context); // 🎯 Close menu first
    _launchSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: config));
  }

  void _launchWorkout(BuildContext context, WorkoutConfig config) {
    Navigator.pop(context);
    _launchSheet(context, WorkoutPlayerSheet(config: config));
  }

  Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, ThemeData theme) {
    return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18)
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface)), // 🎨 Themed Text
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.hintColor)), // 🎨 Themed Hint
        trailing: Icon(Icons.chevron_right_rounded, size: 16, color: theme.iconTheme.color?.withOpacity(0.5)), // 🎨 Themed Icon
        onTap: onTap
    );
  }
}