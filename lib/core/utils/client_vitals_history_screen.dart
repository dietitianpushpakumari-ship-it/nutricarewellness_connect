import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/smart_vitals_card.dart';
import 'package:nutricare_connect/core/utils/vitals_trend_chart.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';

class ClientVitalsHistoryScreen extends ConsumerWidget {
  final String clientId;
  const ClientVitalsHistoryScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the provider to fetch history
    final vitalsAsync = ref.watch(vitalsHistoryProvider(clientId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
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
                    color: Colors.blue.withOpacity(0.1),
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
                _buildHeader(context),

                // 3. Content
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
                    data: (history) {
                      if (history.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.monitor_heart_outlined, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text("No vitals recorded yet.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
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

                          const Text(
                            "History Log",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                          ),
                          const SizedBox(height: 12),

                          // 🎯 C. HISTORY LIST
                          ...sortedHistory.map((record) => _buildClientVitalCard(record)),
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

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                "My Progress",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientVitalCard(VitalsModel record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(record.date),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    "BMI: ${record.bmi.toStringAsFixed(1)}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${record.weightKg} kg",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2D3142)),
              ),
              if (record.bloodPressureSystolic != null)
                Text(
                  "BP: ${record.bloodPressureSystolic}/${record.bloodPressureDiastolic}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }
}