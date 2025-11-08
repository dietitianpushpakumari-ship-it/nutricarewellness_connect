import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';
import 'package:nutricare_connect/services/client_service.dart';

// 🎯 ADJUST IMPORTS

// Import the detail screen we will define next
import 'lab_report_detail_screen.dart';


// --- Data Provider ---
final clientVitalsFutureProvider = FutureProvider.family<List<VitalsModel>, String>((ref, clientId) async {
  final service = VitalsService();
  return service.getClientVitals(clientId);
});


class LabReportListScreen extends ConsumerWidget {
  final ClientModel client;

  const LabReportListScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Consume the Vitals FutureProvider
    final vitalsAsync = ref.watch(clientVitalsFutureProvider(client.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Lab & Vitals History'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: vitalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading history: ${e.toString()}')),
        data: (vitalsList) {
          if (vitalsList.isEmpty) {
            return const Center(child: Text('No Vitals or Lab Reports found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: vitalsList.length,
            itemBuilder: (context, index) {
              final record = vitalsList[index];
              return _buildReportTile(context, record);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportTile(BuildContext context, VitalsModel record) {
    final hasLabs = record.labResults.isNotEmpty;
    final date = DateFormat.yMMMd().format(record.date);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          // Navigate to the detail view
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LabReportDetailScreen(record: record),
            ),
          );
        },
        leading: Icon(
          hasLabs ? Icons.science : Icons.monitor_weight,
          color: hasLabs ? Colors.red.shade700 : Colors.indigo,
        ),
        title: Text('Vitals Entry from $date', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Weight: ${record.weightKg.toStringAsFixed(1)} kg | BMI: ${record.bmi.toStringAsFixed(1)}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}