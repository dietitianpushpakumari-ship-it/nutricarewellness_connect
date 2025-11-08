// lib/features/diet_plan/presentation/screens/diet_plan_dashboard_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart' hide clientServiceProvider;
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_log_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import '../providers/diet_plan_provider.dart';

class DietPlanDashboardScreen extends ConsumerWidget {
  const DietPlanDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDietPlanProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    // Safety check for notifier access: Only access if a client ID is available
    final clientId = ref.watch(currentClientIdProvider);
    final notifier = clientId != null
        ? ref.read(dietPlanNotifierProvider(clientId).notifier)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Daily Plan'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Log History',
            onPressed: () {
              // Navigate to the new history screen
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ClientLogHistoryScreen(),
              ));
            },
          ),
          IconButton(
            onPressed: () => authNotifier.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
          if (notifier != null)
            IconButton(
              onPressed: () => notifier.loadInitialData(state.selectedDate),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : state.error != null
          ? Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)))
          : _buildContent(context, state, notifier),
    );
  }

  Widget _buildContent(
      BuildContext context,
      DietPlanState state,
      DietPlanNotifier? notifier,
      ) {
    if (state.activePlan == null) {
      return const Center(child: Text('No active diet plan found.', style: TextStyle(fontSize: 16)));
    }

    // We assume the plan object is valid if we reached here
    final dayPlan = state.activePlan!.days.isNotEmpty ? state.activePlan!.days.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Active Plan: ${state.activePlan!.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        Expanded(
          child: dayPlan == null
              ? const Center(child: Text('No meal details for today.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            itemCount: dayPlan.meals.length,
            itemBuilder: (context, index) {
              final meal = dayPlan.meals[index];
              final logs = state.dailyLogs.where((log) => log.mealName == meal.mealName).toList();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                child: ExpansionTile(
                  leading: Icon(Icons.restaurant_menu, color: logs.isEmpty ? Colors.grey : Colors.green.shade700),
                  title: Text(meal.mealName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${meal.items.length} items planned. ${logs.length} logged.'),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ...meal.items.map((item) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.arrow_right, color: Colors.teal),
                      title: Text(item.foodItemName),
                      trailing: Text('${item.quantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    )),
                    const Divider(height: 10),
                    if (logs.isNotEmpty)
                      ...logs.map((log) => ListTile(
                        dense: true,
                        leading: log.isDeviation ? const Icon(Icons.warning, color: Colors.red) : const Icon(Icons.done_all, color: Colors.blue),
                        title: Text(
                            log.actualFoodEaten.join(', '), // Join the list
                            style: TextStyle(color: log.isDeviation ? Colors.red.shade700 : Colors.black)
                        ),
                        subtitle: Text('Calories: ${log.caloriesEstimate}', style: const TextStyle(fontSize: 12)),
                      )),
                    // Log Button
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: notifier != null ? () => _showLogMealDialog(context, notifier, meal.mealName,state.activePlan!) : null,
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: Text('Log ${meal.mealName}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade50,
                          foregroundColor: Colors.teal.shade700,
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Helper for Logging ---
void _showLogMealDialog(BuildContext context, DietPlanNotifier notifier, String mealName, ClientDietPlanModel activePlan) {
  showDialog(
    context: context,
    builder: (context) {
      return MealLogEntryDialog(
        notifier: notifier,
        mealName: mealName,
        activePlan: activePlan,
      );
    },
  );
}

// --- The Stateful Dialog Content Widget ---
