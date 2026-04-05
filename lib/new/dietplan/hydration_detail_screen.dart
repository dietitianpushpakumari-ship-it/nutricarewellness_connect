import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/wave_clipper.dart';

// FlatClientDietPlanModel
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class HydrationDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final FlatClientDietPlanModel activePlan; // 🚀 Flat Model
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
  ConsumerState<HydrationDetailSheet> createState() => _HydrationDetailSheetState();
}

class _HydrationDetailSheetState extends ConsumerState<HydrationDetailSheet> with SingleTickerProviderStateMixin {
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

  // 🎯 ATOMIC WATER UPDATE LOGIC
  Future<void> _updateWater(double amountToAdd) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Optimistic UI Update for instant visual feedback
      final newTotal = (_displayIntake + amountToAdd).clamp(0.0, 10.0);
      setState(() => _displayIntake = newTotal);

      // 2. 🎯 Atomic Update to Firestore
      await widget.notifier.updateDailyRecord(
        data: {
          'hydrationLiters': newTotal,
        },
      );

    } catch (e) {
      // Revert UI on failure
      setState(() => _displayIntake = widget.currentIntake);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving water: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Quick reset logic
  Future<void> _resetWater() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      setState(() => _displayIntake = 0.0);

      await widget.notifier.updateDailyRecord(
        data: {
          'hydrationLiters': 0.0,
        },
      );
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
    final double progress = goalLiters > 0 ? (_displayIntake / goalLiters).clamp(0.0, 1.0) : 0.0;
    final int percent = (progress * 100).toInt();

    // 🎯 Use Solid Opaque Colors for Premium Look
    final solidBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: solidBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Handle & Header
              Center(
                child: Container(
                  width: 48, height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                      color: theme.dividerColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3)
                  ),
                ),
              ),

              // 2. Stats
              Text(
                  "Today's Hydration",
                  style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 14)
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _displayIntake.toStringAsFixed(2),
                    style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        height: 1.0
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                      "/ $goalLiters L",
                      style: TextStyle(
                          fontSize: 22,
                          color: theme.hintColor,
                          fontWeight: FontWeight.bold
                      )
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 3. WATER TANK VISUAL
              SizedBox(
                height: 280,
                width: 160,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? colorScheme.primary.withOpacity(0.05) : colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return ClipPath(
                                  clipper: WaveClipper(waveProgress: _waveController.value, fillProgress: progress),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          colorScheme.primary,
                                          colorScheme.primary.withOpacity(0.7)
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Measurement Lines
                            Positioned(
                              right: 0, top: 0, bottom: 0, width: 20,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(5, (index) => Container(
                                  height: 2,
                                  width: index % 2 == 0 ? 12 : 8,
                                  color: Colors.white.withOpacity(0.4),
                                  margin: const EdgeInsets.only(right: 4),
                                )),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 120,
                      child: Text(
                        "$percent%",
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: progress > 0.4
                                ? Colors.white.withOpacity(0.9)
                                : colorScheme.primary.withOpacity(0.6)
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 4. Controls
              Text(
                  "Quick Add",
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: colorScheme.onSurface
                  )
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAddBtn(0.25, "Glass", Icons.local_drink_rounded, theme, colorScheme, isDark),
                  _buildAddBtn(0.50, "Bottle", Icons.water_drop_rounded, theme, colorScheme, isDark),
                  _buildAddBtn(0.75, "Jug", Icons.local_cafe_rounded, theme, colorScheme, isDark),
                ],
              ),

              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _isSaving ? null : _resetWater,
                icon: Icon(Icons.refresh_rounded, color: colorScheme.error.withOpacity(0.8), size: 18),
                label: Text(
                    "Reset Tank",
                    style: TextStyle(
                        color: colorScheme.error.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14
                    )
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddBtn(double amount, String label, IconData icon, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _updateWater(amount),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            backgroundColor: isDark ? colorScheme.primaryContainer.withOpacity(0.15) : colorScheme.primaryContainer.withOpacity(0.5),
            foregroundColor: colorScheme.primary,
            elevation: 0,
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
            "+${amount.toStringAsFixed(2)}L",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface
            )
        ),
        Text(
            label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.hintColor
            )
        ),
      ],
    );
  }
}