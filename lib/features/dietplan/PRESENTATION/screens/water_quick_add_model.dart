// NOTE: Place this new widget definition near the other helper widgets.

// --- WIDGET: Water Quick Add Modal ---
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart';

class WaterQuickAddModal extends ConsumerWidget {
  final ActivityData currentData;
  final StateProvider<ActivityData> activityProvider;

  const WaterQuickAddModal({
    required this.currentData,
    required this.activityProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Quick Add Water'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Intake: ${currentData.waterL.toStringAsFixed(2)} L',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Goal: ${currentData.goalWaterLiters.toStringAsFixed(1)} L'),
          const Divider(),

          Text('Select Amount to Add:', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: standardSizes.map((size) {
              return ElevatedButton.icon(
                onPressed: () {
                  // 🎯 ACTION: Update the state with the new volume
                  final newVolume = (currentData.waterL + size.volumeL).clamp(0.0, 10.0);
                  ref.read(activityProvider.notifier).state = currentData.copyWith(waterL: newVolume.toDouble());

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${size.label} added!'), duration: const Duration(seconds: 1)));
                  Navigator.of(context).pop(); // Close modal on success
                },
                icon: Icon(size.icon, size: 18),
                label: Text('${size.volumeL.toStringAsFixed(2).replaceAll('0.', '.') } L'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary.withOpacity(0.1),
                    foregroundColor: colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              ref.read(activityProvider.notifier).state = currentData.copyWith(waterL: 0.0);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Today\'s Intake'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}