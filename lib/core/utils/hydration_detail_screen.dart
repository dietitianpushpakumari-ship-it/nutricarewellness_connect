import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/wave_clipper.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class HydrationDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
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
  final double _goalLiters = 3.0; // Default goal

  @override
  void initState() {
    super.initState();
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

  // --- LOGIC: Add Water ---
  Future<void> _updateWater(double amountToAdd) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final newTotal = (widget.currentIntake + amountToAdd).clamp(0.0, 10.0);

      final logToSave = widget.dailyLog ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: widget.notifier.state.selectedDate,
      );

      final updatedLog = logToSave.copyWith(hydrationLiters: newTotal);
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) Navigator.pop(context); // Close sheet on success
    } catch (e) {
      // Handle error if needed
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (widget.currentIntake / _goalLiters).clamp(0.0, 1.0);
    final int percent = (progress * 100).toInt();
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85, // Tall sheet
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          children: [
            // 1. Handle Bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 30),
      
            // 2. Header Stats
            Text("Current Hydration", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.currentIntake.toStringAsFixed(1),
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue.shade900, height: 1.0),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 4),
                  child: Text("/ $_goalLiters L", style: TextStyle(fontSize: 20, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
      
            const Spacer(),
      
            // 3. THE BIG WATER TANK VISUAL
            SizedBox(
              height: 300,
              width: 180,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // A. Container Border (The Glass)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.blue.shade100, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          // B. The Animated Wave
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return ClipPath(
                                clipper: WaveClipper(waveProgress: _waveController.value, fillProgress: progress),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Color(0xFF0077B6), Color(0xFF48CAE4)],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
      
                          // C. Measurement Lines (Ticks)
                          Positioned(
                            right: 0, top: 0, bottom: 0, width: 20,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(5, (index) => Container(
                                height: 2,
                                width: index % 2 == 0 ? 12 : 8,
                                color: Colors.white.withOpacity(0.5),
                                margin: const EdgeInsets.only(right: 4),
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      
                  // D. Percent Overlay (Floating in middle)
                  Positioned(
                    bottom: 130,
                    child: Text(
                      "$percent%",
                      style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: progress > 0.5 ? Colors.white.withOpacity(0.9) : Colors.blue.shade900.withOpacity(0.5)
                      ),
                    ),
                  ),
                ],
              ),
            ),
      
            const Spacer(),
      
            // 4. Quick Add Controls
            const Text("Quick Add", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddBtn(0.25, "Glass", Icons.local_drink),
                _buildAddBtn(0.50, "Bottle", Icons.water_drop),
                _buildAddBtn(0.75, "Jug", Icons.local_cafe), // Renamed "Large" to "Jug" for fun
              ],
            ),
      
            // Reset
            const SizedBox(height: 20),
            TextButton(
              onPressed: _isSaving ? null : () => _updateWater(-widget.currentIntake),
              child: const Text("Reset to 0", style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBtn(double amount, String label, IconData icon) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isSaving ? null : () => _updateWater(amount),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade800,
            elevation: 0,
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text("+${amount.toStringAsFixed(2)}L", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}