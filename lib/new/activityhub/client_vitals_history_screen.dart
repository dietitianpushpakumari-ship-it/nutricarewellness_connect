import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/smart_vitals_card.dart';
import 'package:nutricare_connect/core/utils/vitals_trend_chart.dart';
import 'package:nutricare_connect/new/dietplan/vital_details_Screen.dart';
import 'package:nutricare_connect/core/vitals_comprasion_screen.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

class ClientVitalsHistoryScreen extends ConsumerWidget {
  final String clientId;
  const ClientVitalsHistoryScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Use the provider to fetch history
    final vitalsAsync = ref.watch(vitalsHistoryProvider(clientId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 🎨 Themed Background
      body: Stack(
        children: [
          // 1. Ambient Glow
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05), // 🎨 Themed Glow
                    blurRadius: 80,
                    spreadRadius: 30,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. Custom Header
                _buildHeader(context, theme, colorScheme, isDark),

                // 3. Content
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                    error: (e, s) => Center(child: Text("Error: $e", style: TextStyle(color: colorScheme.error))),
                    data: (history) {
                      if (history.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.monitor_heart_outlined, size: 60, color: theme.disabledColor), // 🎨 Themed
                              const SizedBox(height: 16),
                              Text("No vitals recorded yet.", style: TextStyle(color: theme.hintColor, fontSize: 16)), // 🎨 Themed
                            ],
                          ),
                        );
                      }

                      // Sort: Newest First for List & Report
                      final sortedHistory = List<VitalsModel>.from(history)
                        ..sort((a, b) => b.date.compareTo(a.date));

                      final current = sortedHistory.first;
                      final previous = sortedHistory.length > 1 ? sortedHistory[1] : null;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // 🎯 A. SMART REPORT CARD
                          SmartVitalsReportCard(current: current, previous: previous),
                          const SizedBox(height: 20),

                          // 🎯 B. TREND CHART (If enough data)
                          if (history.length >= 2) ...[
                            VitalsTrendChart(history: history),
                            const SizedBox(height: 24),
                          ],

                          Text(
                            "History Log",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface), // 🎨 Themed
                          ),
                          const SizedBox(height: 12),

                          // 🎯 C. HISTORY LIST
                          ...sortedHistory.map((record) => _buildClientVitalCard(context, record, theme, colorScheme, isDark)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Custom Header (Integrated inside class)
  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          color: theme.scaffoldBackgroundColor.withOpacity(0.8), // 🎨 Glass effect background
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: theme.cardColor, // 🎨 Themed Button Bg
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]
                        ),
                        child: Icon(Icons.arrow_back, size: 20, color: theme.iconTheme.color)
                    )
                ),
                const SizedBox(width: 16),
                Text("My Progress", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: colorScheme.onSurface)), // 🎨 Themed Text
              ]),

              // 🎯 COMPARE BUTTON
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VitalsComparisonScreen(clientId: clientId))),
                icon: Icon(Icons.compare_arrows, color: colorScheme.primary, size: 28), // 🎨 Themed Icon
                tooltip: "Compare Records",
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientVitalCard(BuildContext context, VitalsModel record, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      // 🎯 NAVIGATE TO DETAIL SCREEN ON TAP
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VitalsDetailScreen(record: record)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor, // 🎨 Themed Card
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)), // 🎨 Themed Border
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5), // 🎨 Themed Icon Bg
                      borderRadius: BorderRadius.circular(10)
                  ),
                  child: Icon(Icons.description_outlined, size: 18, color: colorScheme.primary), // 🎨 Themed Icon
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('dd MMM yyyy').format(record.date), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)), // 🎨 Themed Text
                    // Show 'Tap to view details' hint
                    Text("Tap for full record", style: TextStyle(fontSize: 11, color: theme.hintColor)), // 🎨 Themed Hint
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${record.weightKg} kg", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)), // 🎨 Themed Text
                Icon(Icons.chevron_right, size: 16, color: theme.iconTheme.color?.withOpacity(0.5)), // 🎨 Themed Icon
              ],
            ),
          ],
        ),
      ),
    );
  }
}