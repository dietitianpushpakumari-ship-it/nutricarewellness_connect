import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/core/utils/wellness_reccomender_service.dart';
import 'package:pure_shift/core/utils/wellness_tool_model.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

import 'package:pure_shift/new/wellnesshub/BalanceLockSheet.dart';
import 'package:pure_shift/new/wellnesshub/BiometricScannerSheet.dart';
import 'package:pure_shift/new/wellnesshub/Co2ToleranceSheet.dart';
import 'package:pure_shift/new/wellnesshub/IsometricBPPacerSheet.dart';
import 'package:pure_shift/new/wellnesshub/SomaticFluidSheet.dart';
import 'package:pure_shift/new/wellnesshub/SomaticPopItSheet.dart';
import 'package:pure_shift/new/wellnesshub/SpineDecompressionSheet.dart';
import 'package:pure_shift/new/wellnesshub/VagusNerveResetSheet.dart';
import 'package:pure_shift/new/wellnesshub/brainwave_pomodoro_sheet.dart';
import 'package:pure_shift/new/wellnesshub/eft_tapping_sheet.dart';
import 'package:pure_shift/new/wellnesshub/emdr_pacer_sheet.dart';
import 'package:pure_shift/new/wellnesshub/stroop_test_sheet.dart';
import 'package:pure_shift/new/wellnesshub/wellness_tool_registry.dart';
import 'package:pure_shift/new/wellnesshub/breathing_detail_screen.dart';
import 'package:pure_shift/core/utils/mindfullness_config.dart';
import 'package:pure_shift/core/utils/workout_config.dart';
import 'package:pure_shift/new/wellnesshub/workout_player_sheet.dart';
import 'package:pure_shift/new/wellnesshub/rhythm_pacer_sheet.dart';
import 'package:pure_shift/new/wellnesshub/eye-yoga_sheet.dart';
import 'package:pure_shift/new/wellnesshub/meal_pacer_sheet.dart';
import 'package:pure_shift/new/wellnesshub/neck_and_wrist_relief.dart';
import 'package:pure_shift/new/wellnesshub/spiritual_healing_sheet.dart';
import 'package:pure_shift/new/wellnesshub/worry_shreeder_sheet.dart';
import 'package:pure_shift/core/utils/zen_garden_sheet.dart';
import 'package:pure_shift/core/utils/grounding_panic_aid.dart';
import 'package:pure_shift/new/wellnesshub/gratitude_garden_sheet.dart';
import 'package:pure_shift/new/wellnesshub/focus_grid_sheet.dart';
import 'package:pure_shift/core/utils/isochronic_tapping.dart';
import 'package:pure_shift/new/wellnesshub/sleep_mixer_sheet.dart';
import 'package:pure_shift/new/wellnesshub/sleep_debt_bank.dart';
import 'package:pure_shift/features/content/geeta_library_screen.dart';
import '../FlatClientDietPlanModel.dart';

// 🎯 GLOBAL FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class WellnessHubScreen extends ConsumerWidget {
  final ClientModel client;
  const WellnessHubScreen({super.key, required this.client});

  void _handleToolTap(BuildContext context, String routeKey, WidgetRef ref, ClientModel client) {
    final state = ref.read(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    HapticFeedback.selectionClick();
    final dailyRecord = state.dailyRecord;

    switch (routeKey) {
    // 🚀 Pass the client to _showWorkoutMenu to access assignedWorkouts
      case 'quickfit': _showWorkoutMenu(context, Theme.of(context), client); break;
      case 'cardio': _launchSheet(context, const RhythmPacerSheet()); break;
      case 'neck': _launchSheet(context, const NeckWristSheet(isNeck: true)); break;
      case 'wrist': _launchSheet(context, const NeckWristSheet(isNeck: false)); break;
      case 'bp_hold': _launchSheet(context, const IsometricBPPacerSheet()); break;
      case 'vitals_scan': _launchBiometricScanner(context); break;
      case 'glucose_pulse':
        _launchSheet(context, const RhythmPacerSheet(
            prescription: CardioPrescription(
              sets: 3, targetReps: 20, tempo: ClinicalTempo(eccentricMs: 1500, isometricMs: 500, concentricMs: 1000), maxSafeRpe: 5,
            )
        ));
        break;
      case 'balance': _launchSheet(context, const BalanceLockSheet()); break;
      case 'spine_decompression': _launchSheet(context, const SpineDecompressionSheet()); break;
      case 'breathing':
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
      case 'geeta': _launchSheet(context, const GeetaLibrarySheet()); break;
      case 'sleep_mix': _launchSheet(context, const SleepMixerSheet()); break;
      case 'gratitude': _launchSheet(context, const GratitudeGardenSheet()); break;
      case 'panic': _launchSheet(context, const GroundingGameSheet()); break;
      case 'sleep_debt': _launchSheet(context, const SleepDebtSheet()); break;
      case 'meal_pacer': _launchSheet(context, const MealPacerSheet()); break;
      case 'co2_tolerance': _launchSheet(context, const Co2ToleranceSheet()); break;
      case 'somatic_popit': _launchSheet(context, const SomaticPopItSheet()); break;
      case 'somatic_fluid': _launchSheet(context, const SomaticFluidSheet()); break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Refining this protocol..."), backgroundColor: Theme.of(context).colorScheme.primary));
    }
  }

  void _showNoPlanSnippet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please activate a diet plan to use this feature.")));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recommendations = WellnessRecommender.getRecommendations();

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: context.scale(16)),
                  _buildSectionHeader(context, "RECOMMENDED PROTOCOLS", theme),
                  SizedBox(
                    height: context.scale(140),
                    child: PageView.builder(
                      physics: const BouncingScrollPhysics(),
                      controller: PageController(viewportFraction: 0.90),
                      itemCount: recommendations.length,
                      itemBuilder: (context, index) {
                        return _buildHeroCard(context, recommendations[index], () => _handleToolTap(context, recommendations[index].routeKey, ref, client));
                      },
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: context.scale(24))),
            _buildCategorySection(context, ref, "MOVE & ENERGIZE", WellnessCategory.physical, client, theme, isDark),
            _buildCategorySection(context, ref, "CALM & FOCUS", WellnessCategory.mental, client, theme, isDark),
            _buildCategorySection(context, ref, "SOUL & SLEEP", WellnessCategory.spiritual, client, theme, isDark),
            SliverToBoxAdapter(child: SizedBox(height: context.scale(170))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(10), context.scale(24), context.scale(14)),
      child: Text(
        title,
        style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, WellnessTool tool, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: context.scale(12)),
        padding: EdgeInsets.all(context.scale(20)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [tool.color, tool.color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight
          ),
          borderRadius: BorderRadius.circular(context.scale(24)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(4)),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(context.scale(8))),
                    child: Text("FOR YOU", style: TextStyle(fontFamily: kDisplayFont, color: Colors.white, fontSize: context.scale(8), fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  ),
                  SizedBox(height: context.scale(12)),
                  Text(tool.title, style: TextStyle(fontFamily: kDisplayFont, color: Colors.white, fontSize: context.scale(16), fontWeight: FontWeight.w700, height: 1.1)),
                  SizedBox(height: context.scale(4)),
                  Text(tool.subtitle, style: TextStyle(fontFamily: kBodyFont, color: Colors.white70, fontSize: context.scale(10), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(context.scale(12)),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(tool.icon, color: Colors.white, size: context.scale(28)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, WidgetRef ref, String title, WellnessCategory category, ClientModel client, ThemeData theme, bool isDark) {
    List<WellnessTool> tools = WellnessRecommender.getByCategory(category);
    if (category == WellnessCategory.spiritual) tools.addAll(WellnessRecommender.getByCategory(WellnessCategory.sleep));
    if (tools.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, title, theme),
          SizedBox(
            height: context.scale(120),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: context.scale(20)),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                return _buildBentoCard(context, tools[index], () => _handleToolTap(context, tools[index].routeKey, ref, client), theme, isDark);
              },
            ),
          ),
          SizedBox(height: context.scale(8)),
        ],
      ),
    );
  }

  Widget _buildBentoCard(BuildContext context, WellnessTool tool, VoidCallback onTap, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.scale(110),
        margin: EdgeInsets.only(right: context.scale(12), bottom: context.scale(8)),
        padding: EdgeInsets.all(context.scale(12)),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(context.scale(20)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(8)),
              decoration: BoxDecoration(color: tool.color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(tool.icon, color: tool.color, size: context.scale(16)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tool.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: context.scale(10), color: theme.colorScheme.onSurface)),
                SizedBox(height: context.scale(2)),
                Text(tool.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(9), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _launchSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(isDismissible: false, context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
  }

  // 🚀 UPDATED: Parses ClientModel to find assigned workouts dynamically
  // 🚀 UPDATED: Parses ClientModel to find ALL assigned workouts dynamically
  void _showWorkoutMenu(BuildContext context, ThemeData theme, ClientModel client) {
    final isDark = theme.brightness == Brightness.dark;

    // --- 🏋️ PARSE ALL DIETITIAN ASSIGNED WORKOUTS ---
    List<WorkoutConfig> prescribedRoutines = [];

    if (client.assignedWorkouts.isNotEmpty) {
      for (var routine in client.assignedWorkouts) {
        final Map<String, dynamic> routineJson = routine as Map<String, dynamic>;
        final List stepsData = routineJson['steps'] ?? [];

        final List<WorkoutStep> parsedSteps = stepsData.map((s) {
          ExerciseType parsedType = ExerciseType.rest;
          try {
            parsedType = ExerciseType.values.byName(s['type']);
          } catch (_) {}

          return WorkoutStep(
            type: parsedType,
            duration: s['duration'] ?? 30,
            reps: s['reps'] ?? 0,
            isRepBased: (s['reps'] ?? 0) > 0, // Ensure rep-based flag is set
            title: parsedType.name.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ').toUpperCase(),
            instruction: "Execute with proper form.",
            icon: Icons.fitness_center_rounded, // Provide a default icon
          );
        }).toList();

        prescribedRoutines.add(
            WorkoutConfig(
              title: routineJson['title']?.toString().toUpperCase() ?? "CLINICAL PROTOCOL",
              description: "Scheduled for ${routineJson['scheduledTime'] ?? 'today'}.",
              color: const Color(0xFF1E1E1E), // Industrial Luxury Black
              steps: parsedSteps,
            )
        );
      }
    }

    showModalBottomSheet(
      isDismissible: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121826) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(ctx.scale(28))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: ctx.scale(12)),
              Center(child: Container(width: ctx.scale(36), height: ctx.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(ctx.scale(2))))),
              SizedBox(height: ctx.scale(16)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ctx.scale(24)),
                child: Text("QUICK FIT", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(10), fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.6))),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(ctx.scale(24), ctx.scale(4), ctx.scale(24), ctx.scale(16)),
                child: Text("Select a Routine", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(16), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ctx.scale(20)),
                child: Column(
                  children: [

                    // 🚀 PREMIUM RENDER: Loop through ALL custom configs
                    if (prescribedRoutines.isNotEmpty) ...[
                      ...prescribedRoutines.map((config) => _buildPresetRow(
                          ctx,
                          config.title,
                          "Dietitian Prescribed • ${config.steps.length} Steps",
                          Icons.verified_user_rounded,
                          isDark ? Colors.white : Colors.black,
                              () => _launchWorkout(context, config, client),
                          theme
                      )),

                      // Divider text before standard routines
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: ctx.scale(8), horizontal: ctx.scale(16)),
                        child: Text("STANDARD ROUTINES", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(9), fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.hintColor.withOpacity(0.5))),
                      ),
                    ],

                    // Fallback / Standard Routines
                    _buildPresetRow(ctx, "Morning Charge", "3 Min Wake Up", Icons.wb_sunny_rounded, Colors.orange, () => _launchWorkout(context, WorkoutConfig.morningStretch, client), theme),
                    _buildPresetRow(ctx, "Desk De-Stress", "5 Min Neck & Back", Icons.chair_rounded, Colors.blueAccent, () => _launchWorkout(context, WorkoutConfig.deskRelief, client), theme),
                  ],
                ),
              ),
              SizedBox(height: ctx.scale(32)),
            ],
          ),
        ),
      ),
    );
  }
  IconData getIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.rest: return Icons.self_improvement_rounded;
      case ExerciseType.squat:
      case ExerciseType.lunges: return Icons.airline_seat_legroom_extra_rounded;
      case ExerciseType.pushup:
      case ExerciseType.plank: return Icons.fitness_center_rounded;
      case ExerciseType.highKnees:
      case ExerciseType.jumpingJack: return Icons.directions_run_rounded;
      case ExerciseType.pacing: return Icons.directions_walk_rounded;
      default: return Icons.accessibility_new_rounded;
    }
  }
  void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan, ClientLogModel? dailyRecord, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      isDismissible: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121826) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ctx.scale(28))),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: ctx.scale(12)),
              Center(child: Container(width: ctx.scale(36), height: ctx.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(ctx.scale(2))))),
              SizedBox(height: ctx.scale(16)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ctx.scale(24)),
                child: Text("RESPIRATORY PROTOCOLS", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(10), fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.6))),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(ctx.scale(24), ctx.scale(4), ctx.scale(24), ctx.scale(16)),
                child: Text("Breathing Exercises", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(16), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ctx.scale(20)),
                child: Column(
                  children: [
                    _buildPresetRow(ctx, "Focus & Clarity", "Box Breathing (4-4-4-4)", Icons.crop_square_rounded, Colors.teal, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.box), theme),
                    _buildPresetRow(ctx, "Sleep & Anxiety", "4-7-8 Technique", Icons.nightlight_round, Colors.indigo, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.relax), theme),
                    _buildPresetRow(ctx, "Energy Boost", "Rapid Fire Breath", Icons.bolt_rounded, Colors.orange, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.energy), theme),
                    _buildPresetRow(ctx, "Balance", "Coherence (Heart Sync)", Icons.favorite_rounded, Colors.pinkAccent, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.coherence), theme),
                  ],
                ),
              ),
              SizedBox(height: ctx.scale(32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetRow(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: context.scale(10)),
        padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(14)),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(context.scale(16)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
                padding: EdgeInsets.all(context.scale(10)),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: context.scale(16))
            ),
            SizedBox(width: context.scale(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: context.scale(12), color: theme.colorScheme.onSurface)),
                  SizedBox(height: context.scale(2)),
                  Text(subtitle, style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(10), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: context.scale(16), color: theme.hintColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, FlatClientDietPlanModel plan, ClientLogModel? log, BreathingConfig config) {
    Navigator.pop(context);
    _launchSheet(context, BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: log, config: config));
  }

  // 🚀 UPDATED: Now requires ClientModel to be passed to WorkoutPlayerSheet
  void _launchWorkout(BuildContext context, WorkoutConfig config, ClientModel client) {
    Navigator.pop(context);
    _launchSheet(context, WorkoutPlayerSheet(config: config, client: client));
  }

  Future<void> _launchBiometricScanner(BuildContext context) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      if (context.mounted) {
        final int? bpmResult = await showModalBottomSheet<int>(
          isDismissible: false, context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => BiometricScannerSheet(cameras: cameras),
        );
        if (bpmResult != null && context.mounted) _evaluateVitals(context, bpmResult);
      }
    } catch (e) {
      debugPrint("Scanner Error: $e");
    }
  }

  void _evaluateVitals(BuildContext context, int bpm) {
    if (bpm > 85) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text("High stress detected ($bpm BPM). Reset recommended.", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11))),
            action: SnackBarAction(label: "START", textColor: Colors.white, onPressed: () => _launchSheet(context, const VagusNerveResetSheet())),
          )
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vitals Optimal ($bpm BPM).", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11))), backgroundColor: Colors.green));
    }
  }
}