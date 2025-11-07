import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/diet_plan_dashboard_screen.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';


import '../providers/diet_plan_provider.dart';
import '../../domain/entities/client_log_model.dart';
import 'package:intl/intl.dart';

class ClientLogHistoryScreen extends ConsumerWidget {
  const ClientLogHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientId = ref.watch(currentClientIdProvider);

    if (clientId == null) {
      return const Center(child: Text('Please log in.'));
    }

    // Consume the new FutureProvider for all logs
    final historyAsync = ref.watch(clientLogHistoryProvider(clientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Meal Log History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading history: $e')),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No historical meal logs found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final isReviewed = log.adminReplied;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    isReviewed ? Icons.comment : Icons.food_bank,
                    color: isReviewed ? Colors.green.shade700 : Colors.indigo,
                  ),
                  title: Text(
                    '${log.mealName} - ${DateFormat.yMMMd().format(log.date)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Eaten: ${log.actualFoodEaten}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (log.clientQuery != null && log.clientQuery!.isNotEmpty)
                        Text('❓ Query: ${log.clientQuery}', style: const TextStyle(color: Colors.blueGrey)),
                      if (isReviewed)
                        Text('✅ Reply: ${log.adminComment}', style: TextStyle(color: Colors.green.shade700)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    // 🎯 Tapping opens the same dialog, but in EDIT mode
                    onPressed: () => _openLogModificationDialog(context, ref, log),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }



  void _openLogModificationDialog(BuildContext context, WidgetRef ref, ClientLogModel log) {
    final notifier = ref.read(dietPlanNotifierProvider(log.clientId).notifier);
    final activePlan = ref.read(activeDietPlanProvider.select((state) => state.activePlan));

    if (activePlan != null) {
      // 🎯 CALL THE EXPORTED FUNCTION
      showLogModificationDialog(
          context,
          notifier,
          log.mealName,
          activePlan,
          logToEdit: log // Pass log for editing
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit log: Active plan not loaded.')));
    }
  }
}
