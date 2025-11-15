import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// 🎯 Data Model for Standard Glass/Bottle Sizes (with Color)
class WaterSize {
  final String label;
  final double volumeL;
  final IconData icon;
  final Color color; // 🎨 NEW: Color property

  const WaterSize({
    required this.label,
    required this.volumeL,
    required this.icon,
    required this.color,
  });
}

// 🎯 UPDATED: List now includes colors
const List<WaterSize> standardSizes = [
  WaterSize(label: '200 ml', volumeL: 0.20, icon: Icons.local_drink, color: Colors.lightBlueAccent),
  WaterSize(label: '250 ml', volumeL: 0.25, icon: Icons.local_cafe, color: Colors.blue),
  WaterSize(label: '500 ml', volumeL: 0.50, icon: Icons.water_drop, color: Colors.teal),
  WaterSize(label: '750 ml', volumeL: 0.75, icon: Icons.water_drop_outlined, color: Colors.indigo),
  WaterSize(label: '1 L', volumeL: 1.0, icon: Icons.local_drink_outlined, color: Colors.blueGrey),
];

// --- WIDGET: Water Quick Add Modal ---
class WaterQuickAddModal extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyMetricsLog; // The existing log for this day
  final double currentIntake;

  const WaterQuickAddModal({
    super.key,
    required this.notifier,
    required this.activePlan,
    this.dailyMetricsLog,
    required this.currentIntake,
  });

  @override
  ConsumerState<WaterQuickAddModal> createState() => _WaterQuickAddModalState();
}

class _WaterQuickAddModalState extends ConsumerState<WaterQuickAddModal> {
  bool _isSaving = false;

  // Assuming a static goal for this modal
  final double _goalLiters = 3.0;

  // --- 1. ADD WATER (Called by confirmation dialog) ---
  Future<void> _addWater(double amountL) async {
    setState(() { _isSaving = true; });

    try {
      final newTotal = widget.currentIntake + amountL;

      // 1. Find or create the base log object
      final logToSave = widget.dailyMetricsLog ?? ClientLogModel(
        id: '', // Empty ID for creation
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK', // Unique identifier
        actualFoodEaten: ['Daily Wellness Data'], // Constant value as a List
        date: widget.notifier.state.selectedDate,
      );

      // 2. We update the model using copyWith, ONLY changing hydration
      final updatedLog = logToSave.copyWith(
        hydrationLiters: newTotal.clamp(0.0, 10.0), // Clamp to a reasonable max
      );

      // 3. Save using the existing createOrUpdateLog logic
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${amountL}L added! New total: ${newTotal.toStringAsFixed(1)}L'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(); // Close the main modal
      }

    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save hydration: ${e.toString().split(':').last.trim()}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      // Don't set isSaving to false until after pop, or just let the modal dispose
    }
  }

  // --- 🎯 2. NEW: Confirmation Dialog for ADDING water ---
  Future<void> _showAddConfirmationDialog(BuildContext context, WaterSize size) async {
    if (_isSaving) return; // Prevent double taps

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add ${size.label}?'),
        content: Text('This will add ${size.volumeL} L to your daily total. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: size.color), // Use the button's color
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // User confirmed, now call the actual save logic
      await _addWater(size.volumeL);
    }
  }


  // --- 3. RESET WATER (Shows confirmation dialog) ---
  Future<void> _resetWater() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Hydration?'),
        content: Text('Are you sure you want to reset your hydration for ${DateFormat.yMMMd().format(widget.notifier.state.selectedDate)} to 0?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // User confirmed
    setState(() { _isSaving = true; });

    try {
      // 1. Find or create the base log object
      final logToSave = widget.dailyMetricsLog ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: widget.notifier.state.selectedDate,
      );

      // 2. We update the model using copyWith, setting hydration to 0
      final updatedLog = logToSave.copyWith(
        hydrationLiters: 0.0,
      );

      // 3. Save
      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Hydration reset to 0!'),
          backgroundColor: Colors.orange,
        ));
    Navigator.of(context).pop();
    }
    } on Exception catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('Failed to reset hydration: ${e.toString().split(':').last.trim()}'),
    backgroundColor: Colors.red,
    ));
    } finally {
    if (mounted) setState(() { _isSaving = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Add Water'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Intake: ${widget.currentIntake.toStringAsFixed(2)} L',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Goal: ${_goalLiters.toStringAsFixed(1)} L'),
          const Divider(),

          Text('Select Amount to Add:', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 10),

          // 🎯 3. UPDATED BUTTON LIST
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: standardSizes.map((size) { // Uses the new global list
              return ElevatedButton.icon(
                // 🎨 Calls confirmation dialog
                onPressed: _isSaving ? null : () => _showAddConfirmationDialog(context, size),
                icon: Icon(size.icon, size: 18, color: Colors.white),
                label: Text(size.label, style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: size.color, // 🎨 Use color from model
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                ),
              );
            }).toList(),
          ),

          const Divider(height: 20),

          // 🎯 4. RESET BUTTON (Now included)
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _resetWater,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Today\'s Intake'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade200),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Close')
        ),
      ],
    );
  }
}