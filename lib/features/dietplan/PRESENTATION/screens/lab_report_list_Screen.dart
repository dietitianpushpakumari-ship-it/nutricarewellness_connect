import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';

// 🎯 IMPORT YOUR PROVIDER FILE TO ACCESS vitalsServiceProvider
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

// 🎯 ADJUST IMPORTS
import 'lab_report_detail_screen.dart';

// --- 🎯 FIXED Data Provider ---
final clientVitalsFutureProvider = FutureProvider.family<List<VitalsModel>, String>((ref, clientId) async {
  // Use the correctly configured service that injects tenantId automatically!
  final service = ref.watch(vitalsServiceProvider);
  return service.getClientVitals(clientId);
});


class LabReportListScreen extends ConsumerWidget {
  final ClientModel client;

  const LabReportListScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 1. Consume the Vitals FutureProvider
    final vitalsAsync = ref.watch(clientVitalsFutureProvider(client.id));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 🎨 Themed Background
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 2. Custom Themed Header
            _buildHeader(context, theme, colorScheme, isDark),

            // 3. Content Body
            Expanded(
              child: vitalsAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                error: (e, s) => Center(child: Text('Error loading history: ${e.toString()}', style: TextStyle(color: colorScheme.error))),
                data: (vitalsList) {
                  if (vitalsList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined, size: 60, color: theme.disabledColor),
                          const SizedBox(height: 16),
                          Text('No Vitals or Lab Reports found.', style: TextStyle(color: theme.hintColor, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  // Sort newest first
                  final sortedList = List<VitalsModel>.from(vitalsList)
                    ..sort((a, b) => b.date.compareTo(a.date));

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: sortedList.length,
                    itemBuilder: (context, index) {
                      final record = sortedList[index];
                      return _buildReportTile(context, record, theme, colorScheme, isDark);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🎯 CUSTOM GLASS HEADER ---
  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          color: theme.scaffoldBackgroundColor.withOpacity(0.8),
          child: Row(
            children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.iconTheme.color)
                  )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                    "Lab & Vitals History",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 🎯 CUSTOM THEMED TILE ---
  Widget _buildReportTile(BuildContext context, VitalsModel record, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final hasLabs = record.labResults.isNotEmpty;
    final date = DateFormat.yMMMd().format(record.date);

    // Dynamic colors based on whether it has lab results or just vitals
    final iconColor = hasLabs ? colorScheme.error : colorScheme.primary;
    final iconBgColor = hasLabs
        ? colorScheme.errorContainer.withOpacity(isDark ? 0.3 : 0.5)
        : colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LabReportDetailScreen(record: record),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor, // 🎨 Glass card fill
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)), // 🎨 Delicate rim
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14)
              ),
              child: Icon(
                hasLabs ? Icons.science_rounded : Icons.monitor_weight_rounded,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Entry from $date',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Weight: ${record.weightKg.toStringAsFixed(1)} kg • BMI: ${record.bmi.toStringAsFixed(1)}',
                    style: TextStyle(color: theme.hintColor, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Trailing Chevron
            Icon(Icons.chevron_right_rounded, color: theme.iconTheme.color?.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}