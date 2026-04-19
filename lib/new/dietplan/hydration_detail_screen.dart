import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/screens/wave_clipper.dart';
import 'package:pure_shift/layout_utils.dart'; // 🚀 Ensure this is imported
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

const String kFontFamily = 'Inter';

class HydrationDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final FlatClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;
  final double currentIntake;

  const HydrationDetailSheet({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
    required this.currentIntake,
  });

  @override
  ConsumerState<HydrationDetailSheet> createState() =>
      _HydrationDetailSheetState();
}

class _HydrationDetailSheetState extends ConsumerState<HydrationDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  bool _isSaving = false;
  late double _displayIntake;

  @override
  void initState() {
    super.initState();
    _displayIntake = widget.currentIntake;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _updateWater(double litersToAdd) async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final newTotal = (_displayIntake + litersToAdd).clamp(0.0, 10.0);
      setState(() => _displayIntake = newTotal);
      await widget.notifier
          .updateDailyRecord(data: {'hydrationLiters': newTotal});
    } catch (e) {
      setState(() => _displayIntake = widget.currentIntake);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final double goalLiters = widget.activePlan.dailyWaterGoal;
    final double progress =
        goalLiters > 0 ? (_displayIntake / goalLiters).clamp(0.0, 1.0) : 0.0;
    final int percent = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(context.scale(32))),
      ),
      child: Stack(
        children: [
          // 🚀 1. THE CLOSE BUTTON

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(12),
                  context.scale(24), context.scale(24)),
              child: Column(
                children: [
                  // 🚀 1. IMPROVED HEADER & CLOSE ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Invisible spacer to keep the handle centered
                      SizedBox(width: context.scale(40)),

                      // Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2)),
                      ),

                      // 🚀 THE WORKING CLOSE BUTTON
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(
                                context); // 🚀 Explicitly closes the sheet
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: EdgeInsets.all(context.scale(8)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded,
                                size: context.scale(20),
                                color: colorScheme.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.scale(24)),

                  // ... rest of your Column (DAILY PROGRESS, etc.)


                  // 🚀 2. REFINED TYPOGRAPHY
                  Text(
                    "DAILY PROGRESS",
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: context.scale(10),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: theme.hintColor.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: context.scale(12)),

                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _displayIntake.toStringAsFixed(1),
                          style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: context.scale(48),
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              letterSpacing: -1),
                        ),
                        TextSpan(
                          text: " / $goalLiters L",
                          style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: context.scale(18),
                              fontWeight: FontWeight.w500,
                              color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.scale(32)),

                  // 🚀 3. THE TANK (Visual)
                  SizedBox(
                    height: context.scale(240),
                    width: context.scale(140),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.black.withOpacity(0.02),
                            borderRadius:
                                BorderRadius.circular(context.scale(40)),
                            border: Border.all(
                                color: colorScheme.primary.withOpacity(0.1),
                                width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(context.scale(38)),
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return ClipPath(
                                  clipper: WaveClipper(
                                      waveProgress: _waveController.value,
                                      fillProgress: progress),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          colorScheme.primary,
                                          colorScheme.primary.withOpacity(0.6)
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Percent Overlay
                        Text(
                          "$percent%",
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: context.scale(32),
                            fontWeight: FontWeight.w800,
                            color: progress > 0.4
                                ? Colors.white.withOpacity(0.9)
                                : colorScheme.onSurface.withOpacity(0.2),
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.scale(40)),

                  // 🚀 4. REALISTIC CONTROLS (ml units)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAddBtn(0.20, "200 ml", Icons.local_drink_rounded,
                          colorScheme, isDark),
                      _buildAddBtn(0.25, "250 ml", Icons.water_drop_rounded,
                          colorScheme, isDark),
                      _buildAddBtn(0.50, "500 ml", Icons.wine_bar_rounded,
                          colorScheme, isDark),
                    ],
                  ),

                  SizedBox(height: context.scale(32)),

                  // Reset
                  GestureDetector(
                    onTap:
                        _isSaving ? null : () => _updateWater(-_displayIntake),
                    child: Text(
                      "Reset Progress",
                      style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: context.scale(12),
                          fontWeight: FontWeight.w600,
                          color: colorScheme.error.withOpacity(0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddBtn(double liters, String label, IconData icon,
      ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _updateWater(liters),
          child: Container(
            padding: EdgeInsets.all(context.scale(18)),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, color: colorScheme.primary, size: context.scale(24)),
          ),
        ),
        SizedBox(height: context.scale(8)),
        Text(
          label,
          style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: context.scale(12),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
