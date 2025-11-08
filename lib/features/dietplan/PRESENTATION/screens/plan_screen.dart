import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/daily_wellness_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/services/client_service.dart';

class PlanScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // 1. Fetch the active plan state (which includes selectedDate and dailyLogs)
    final state = ref.watch(activeDietPlanProvider);

    // 2. Access the Notifier for actions
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    // --- Manual State Handling ---
    if (state.isLoading) { return const Center(child: CircularProgressIndicator()); }
    if (state.error != null) { return Center(child: Text('Error loading plan: ${state.error}')); }

    final activePlan = state.activePlan;
    final dailyLogs = state.dailyLogs;

    if (activePlan == null) { return const Center(child: Text('No active diet plan assigned.')); }

    final dayPlan = activePlan.days.firstWhereOrNull((d) => true);

    // 🎯 CRITICAL: Find existing log for the SELECTED DATE's wellness metrics
    final ClientLogModel? dailyWellnessLog = dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
    final bool isWellnessCheckComplete = dailyWellnessLog != null;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 🎯 1. DATE SELECTOR (Enables back-dating)
        _buildDateSelector(context, notifier, state.selectedDate),
        const SizedBox(height: 20),

        // 🎯 2. DAILY WELLNESS CHECK-IN CARD (The daily form)
        _buildDailyWellnessCard(context, isWellnessCheckComplete, notifier, dailyWellnessLog, activePlan),
        const SizedBox(height: 20),

        // Header for Meal Routine
        Text('Meal Plan: ${activePlan.name}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
        Text('Assigned Date: ${DateFormat.yMMMd().format(activePlan.assignedDate ?? DateTime.now())}', style: TextStyle(color: Colors.grey.shade600)),
        const Divider(height: 30),

        // 🎯 3. DAILY MEAL TRACKER (Per-meal logs)
        if (dayPlan != null)
          ...dayPlan.meals.map((meal) {
            final mealName = meal.mealName ?? 'Meal';
            final mealLog = dailyLogs.firstWhereOrNull((log) => log.mealName == mealName);
            final isLogged = mealLog != null;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              child: ExpansionTile(
                leading: Icon(isLogged ? Icons.check_circle : Icons.radio_button_unchecked, color: isLogged ? Colors.green : Colors.grey),
                title: Text(mealName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isLogged
                    ? 'Logged: ${mealLog!.actualFoodEaten}'
                    : 'Planned: ${meal.items.length} items'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // --- Planned Items List (Items & Alternatives) ---
                  ...meal.items.map((item) => _buildPlannedItemTile(context, item)),

                  // --- Log/Edit Button ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
                    child: ElevatedButton.icon(
                      icon: Icon(isLogged ? Icons.edit : Icons.add, color: colorScheme.onPrimary),
                      onPressed: () {
                        // Launch the existing MEAL log dialog
                        // 🎯 This opens the dialog for MEALS
                        showLogModificationDialog(context, notifier, mealName, activePlan, logToEdit: mealLog);
                      },
                      label: Text(isLogged ? 'EDIT MEAL' : 'LOG MEAL'),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

        const Divider(height: 30),
        Text(
          'Assigned Guidelines',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        const SizedBox(height: 8),
        _buildGuidelinesSection(context, activePlan.guidelineIds,ref),
        const Divider(height: 30),

      ],
    );
  }

  // --- NEW: Date Selector Widget ---
  Widget _buildDateSelector(BuildContext context, DietPlanNotifier notifier, DateTime selectedDate) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    String formatDate(DateTime date) {
      if (DateUtils.isSameDay(date, DateTime.now())) return 'Today';
      if (DateUtils.isSameDay(date, DateTime.now().subtract(const Duration(days: 1)))) return 'Yesterday';
      return DateFormat('EEE, MMM d').format(date);
    }

    return Card(
      elevation: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () {
              final previousDay = selectedDate.subtract(const Duration(days: 1));
              notifier.selectDate(previousDay); // 🎯 Triggers loadInitialData
            },
          ),

          GestureDetector(
            onTap: () async {
              final newDate = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(), // Don't allow future logging
              );
              if (newDate != null && !DateUtils.isSameDay(newDate, selectedDate)) {
                notifier.selectDate(newDate); // 🎯 Triggers loadInitialData
              }
            },
            child: Text(
              formatDate(selectedDate),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isToday ? Theme.of(context).colorScheme.primary : Colors.black87
              ),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            onPressed: isToday ? null : () {
              final nextDay = selectedDate.add(const Duration(days: 1));
              notifier.selectDate(nextDay); // 🎯 Triggers loadInitialData
            },
            color: isToday ? Colors.grey : Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // --- NEW: Daily Wellness Check Card Widget ---
  Widget _buildDailyWellnessCard(BuildContext context, bool isComplete, DietPlanNotifier notifier, ClientLogModel? dailyLog, ClientDietPlanModel activePlan) {
    final Color backgroundColor = isComplete ? Colors.green.shade50 : Colors.amber.shade50;
    final Color iconColor = isComplete ? Colors.green.shade700 : Colors.amber.shade700;
    final String statusText = isComplete ? 'Check-in Complete' : 'ACTION REQUIRED: Daily Wellness Check';

    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: backgroundColor,
          border: Border.all(color: iconColor.withOpacity(0.5))
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
          const Divider(),
          Text('Record your sleep, hydration, and energy levels for today.', style: TextStyle(color: Colors.black87)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              // 🎯 LAUNCH THE NEW DAILY WELLNESS DIALOG
              showDialog(context: context, builder: (_) => DailyWellnessEntryDialog(
                notifier: notifier,
                activePlan: activePlan,
                dailyMetricsLog: dailyLog, // Pass existing data (if any) or null
              ));
            },
            icon: Icon(isComplete ? Icons.edit_note : Icons.add_task),
            label: Text(isComplete ? 'Edit Wellness Metrics' : 'Daily Wellness Check'),
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

// ... (omitted helper functions _buildPlannedItemTile, _buildGuidelinesSection, etc.) ...
}


// -------------------------------------------------------------------------
Widget _buildPlannedItemTile(BuildContext context, DietPlanItemModel item) {
  // Check if foodItemName exists and assume it has a value
  if (item.foodItemName.isEmpty) return const SizedBox.shrink();

  final hasAlternatives = item.alternatives.isNotEmpty;

  return ListTile(
    dense: true,
    minLeadingWidth: 20,
    leading: Icon(
      hasAlternatives ? Icons.swap_horiz : Icons.fiber_manual_record,
      size: 16,
      color: hasAlternatives ? Colors.orange : Colors.green,
    ),
    title: Text(
      item.foodItemName,
      style: const TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: hasAlternatives
        ? Text(
      'Alternatives: ${item.alternatives.map((a) => a.foodItemName).join(', ')}',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    )
        : null,
    trailing: Text(
      '${item.quantity.toStringAsFixed(1)} ${item.unit}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );
}

Widget _buildGuidelinesSection(BuildContext context, List<String> guidelineIds,WidgetRef ref) {
  // 🎯 CRITICAL FIX: Use Riverpod to watch the actual data
  final guidelinesAsync = ref.watch(guidelineProvider(guidelineIds));

  return guidelinesAsync.when(
    loading: () => const LinearProgressIndicator(),
    error: (e, s) => Text('Failed to load guidelines: $e', style: const TextStyle(color: Colors.red)),
    data: (guidelines) {
      if (guidelines.isEmpty) {
        return const Text('No general guidelines assigned for this plan.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
      }

      return Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Column(
            children: guidelines.map((guideline) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  // Use the title from the Guideline model
                  Expanded(child: Text(guideline.enTitle, style: TextStyle(color: Colors.black87))),
                ],
              ),
            )).toList(),
          ),
        ),
      );
    },
  );
}