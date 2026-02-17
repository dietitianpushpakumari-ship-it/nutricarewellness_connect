import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

class VitalsComparisonScreen extends ConsumerStatefulWidget {
  final String clientId;
  const VitalsComparisonScreen({super.key, required this.clientId});

  @override
  ConsumerState<VitalsComparisonScreen> createState() => _VitalsComparisonScreenState();
}

class _VitalsComparisonScreenState extends ConsumerState<VitalsComparisonScreen> {
  VitalsModel? _baseRecord;
  VitalsModel? _compareRecord;
  bool _isInitialized = false;

  // Initialize with First (Oldest) and Last (Newest) records
  void _initRecords(List<VitalsModel> history) {
    if (_isInitialized || history.isEmpty) return;
    // Sort by date: Oldest first
    final sorted = List<VitalsModel>.from(history)..sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _baseRecord = sorted.first;
      _compareRecord = sorted.last;
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Theme Aware
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
                        BoxShadow(color: colorScheme.primary.withOpacity(0.1), blurRadius: 80, spreadRadius: 30)
                      ]
                  )
              )
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. Header
                _buildHeader(context),

                // 3. Content
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e", style: TextStyle(color: colorScheme.error))),
                    data: (history) {
                      if (history.length < 2) {
                        return Center(
                            child: Text(
                                "Need at least 2 records to compare.",
                                style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)
                            )
                        );
                      }

                      // Initialize selection once
                      if (!_isInitialized) _initRecords(history);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                        child: Column(
                          children: [
                            // Selectors
                            _buildComparisonSelectors(history, context),
                            const SizedBox(height: 24),

                            // Report
                            if (_baseRecord != null && _compareRecord != null) ...[
                              _buildSectionTitle("Anthropometry (Body)", context),
                              _buildComparisonCard(context, [
                                _buildDiffRow(context, "Weight (kg)", _baseRecord!.weightKg, _compareRecord!.weightKg, inverse: true),
                                _buildDiffRow(context, "BMI", _baseRecord!.bmi, _compareRecord!.bmi, inverse: true),
                                if (_baseRecord!.bodyFatPercentage > 0 || _compareRecord!.bodyFatPercentage > 0)
                                  _buildDiffRow(context, "Body Fat %", _baseRecord!.bodyFatPercentage, _compareRecord!.bodyFatPercentage, inverse: true),
                                if (_baseRecord!.waistCm != null && _compareRecord!.waistCm != null)
                                  _buildDiffRow(context, "Waist (cm)", _baseRecord!.waistCm!, _compareRecord!.waistCm!, inverse: true),
                              ]),
                              const SizedBox(height: 20),

                              _buildSectionTitle("Vitals & Heart", context),
                              _buildComparisonCard(context, [
                                _buildDiffRow(context, "BP Systolic", _baseRecord!.bloodPressureSystolic?.toDouble() ?? 0, _compareRecord!.bloodPressureSystolic?.toDouble() ?? 0, inverse: true),
                                _buildDiffRow(context, "BP Diastolic", _baseRecord!.bloodPressureDiastolic?.toDouble() ?? 0, _compareRecord!.bloodPressureDiastolic?.toDouble() ?? 0, inverse: true),
                                _buildDiffRow(context, "Heart Rate", _baseRecord!.heartRate?.toDouble() ?? 0, _compareRecord!.heartRate?.toDouble() ?? 0, inverse: true),
                              ]),
                              const SizedBox(height: 20),

                              if (_hasCommonLabs(_baseRecord!, _compareRecord!)) ...[
                                _buildSectionTitle("Key Lab Markers", context),
                                _buildComparisonCard(context, _buildLabRows(context)),
                              ]
                            ]
                          ],
                        ),
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

  // --- WIDGETS ---

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.8),
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)))
          ),
          child: Row(children: [
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                    ),
                    child: Icon(Icons.arrow_back, size: 20, color: colorScheme.onSurface)
                )
            ),
            const SizedBox(width: 16),
            Text(
                "Progress Comparison",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface)
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildComparisonSelectors(List<VitalsModel> history, BuildContext context) {
    // Sort by date descending for dropdown (Newest first)
    final sorted = List<VitalsModel>.from(history)..sort((a, b) => b.date.compareTo(a.date));
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: Row(
        children: [
          Expanded(child: _buildDropdown(context, "Baseline", _baseRecord, sorted, (v) => setState(() => _baseRecord = v))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward, color: theme.colorScheme.primary, size: 20),
          ),
          Expanded(child: _buildDropdown(context, "Current", _compareRecord, sorted, (v) => setState(() => _compareRecord = v))),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, String label, VitalsModel? value, List<VitalsModel> items, ValueChanged<VitalsModel?> onChanged) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2))
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VitalsModel>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: theme.colorScheme.onSurface),
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
              onChanged: onChanged,
              items: items.map((v) => DropdownMenuItem(
                value: v,
                child: Text(DateFormat('dd MMM yy').format(v.date), overflow: TextOverflow.ellipsis),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDiffRow(BuildContext context, String label, double val1, double val2, {bool inverse = false}) {
    if (val1 == 0 && val2 == 0) return const SizedBox();

    double diff = val2 - val1;
    double pct = val1 != 0 ? (diff / val1) * 100 : 0;

    // Logic:
    // Inverse (Weight, BP, Sugar) -> Diff < 0 is Good (Green)
    // Normal (Muscle, HDL)        -> Diff > 0 is Good (Green)
    bool isImprovement = inverse ? (diff <= 0) : (diff >= 0);

    Color color = diff == 0 ? Colors.grey : (isImprovement ? Colors.green : Colors.red);
    IconData icon = diff > 0 ? Icons.arrow_upward : (diff < 0 ? Icons.arrow_downward : Icons.remove);

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                Text("${val1.toStringAsFixed(1)} → ${val2.toStringAsFixed(1)}", style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text("${diff.abs().toStringAsFixed(1)} (${pct.abs().toStringAsFixed(0)}%)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- HELPER LOGIC ---

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
          )
      ),
    );
  }

  bool _hasCommonLabs(VitalsModel a, VitalsModel b) {
    final keysA = a.labResults.keys.toSet();
    final keysB = b.labResults.keys.toSet();
    return keysA.intersection(keysB).isNotEmpty;
  }

  List<Widget> _buildLabRows(BuildContext context) {
    if (_baseRecord == null || _compareRecord == null) return [];

    List<Widget> rows = [];
    final keysA = _baseRecord!.labResults.keys.toSet();
    final keysB = _compareRecord!.labResults.keys.toSet();
    final commonKeys = keysA.intersection(keysB);

    if (commonKeys.isEmpty) return [const Text("No common lab results found between these dates.")];

    for (var key in commonKeys) {
      // 🎯 FIX: Access values directly as doubles
      double? v1 = _baseRecord!.labResults[key];
      double? v2 = _compareRecord!.labResults[key];

      if (v1 != null && v2 != null) {
        // Determine "inverse" logic: Lower is better for most (Sugar, LDL, Triglycerides)
        // False (Higher is better) for: HDL, Hemoglobin, Vitamins
        bool inverse = !['hdl', 'hemoglobin', 'calcium', 'vitamin_d', 'vitamin_b12', 'hdl_cholesterol'].contains(key.toLowerCase());

        // Format Label (e.g. "fbs" -> "FBS", "total_cholesterol" -> "Total Cholesterol")
        String label = key.replaceAll('_', ' ').toUpperCase();

        rows.add(_buildDiffRow(context, label, v1, v2, inverse: inverse));
      }
    }
    return rows;
  }
}