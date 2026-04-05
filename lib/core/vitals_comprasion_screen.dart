import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

// 🔥 Make sure to import your new model and provider
// import 'package:nutricare_connect/new/models/lab_test_config_model.dart';
// import 'package:nutricare_connect/new/provider/lab_config_provider.dart';

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

  void _initRecords(List<VitalsModel> history) {
    if (_isInitialized || history.isEmpty) return;
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

    // 🔥 WATCH YOUR NEW FIRESTORE CONFIGS
    final labConfigsAsync = ref.watch(labTestConfigsProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
              top: -100, right: -80,
              child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.1), blurRadius: 80, spreadRadius: 30)]
                  )
              )
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),

                Expanded(
                  child: vitalsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e", style: TextStyle(color: colorScheme.error))),
                    data: (history) {
                      if (history.length < 2) {
                        return Center(child: Text("Need at least 2 records to compare.", style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)));
                      }

                      if (!_isInitialized) _initRecords(history);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                        child: Column(
                          children: [
                            _buildComparisonSelectors(history, context),
                            const SizedBox(height: 24),

                            if (_baseRecord != null && _compareRecord != null) ...[
                              _buildSectionTitle("Anthropometry (Body)", context),
                              _buildComparisonCard(context, [
                                _buildDiffRow(context, "Weight", _baseRecord!.weightKg, _compareRecord!.weightKg, inverse: true, unit: "kg"),
                                _buildDiffRow(context, "BMI", _baseRecord!.bmi, _compareRecord!.bmi, inverse: true),
                                if (_baseRecord!.bodyFatPercentage > 0 || _compareRecord!.bodyFatPercentage > 0)
                                  _buildDiffRow(context, "Body Fat", _baseRecord!.bodyFatPercentage, _compareRecord!.bodyFatPercentage, inverse: true, unit: "%"),
                                if (_baseRecord!.waistCm != null && _compareRecord!.waistCm != null)
                                  _buildDiffRow(context, "Waist", _baseRecord!.waistCm!, _compareRecord!.waistCm!, inverse: true, unit: "cm"),
                              ]),
                              const SizedBox(height: 20),

                              _buildSectionTitle("Vitals & Heart", context),
                              _buildComparisonCard(context, [
                                _buildDiffRow(context, "BP Systolic", _baseRecord!.bloodPressureSystolic?.toDouble() ?? 0, _compareRecord!.bloodPressureSystolic?.toDouble() ?? 0, inverse: true, unit: "mmHg"),
                                _buildDiffRow(context, "BP Diastolic", _baseRecord!.bloodPressureDiastolic?.toDouble() ?? 0, _compareRecord!.bloodPressureDiastolic?.toDouble() ?? 0, inverse: true, unit: "mmHg"),
                                _buildDiffRow(context, "Heart Rate", _baseRecord!.heartRate?.toDouble() ?? 0, _compareRecord!.heartRate?.toDouble() ?? 0, inverse: true, unit: "bpm"),
                              ]),
                              const SizedBox(height: 20),

                              if (_hasAnyLabs(_baseRecord!, _compareRecord!)) ...[
                                _buildSectionTitle("Key Lab Markers", context),

                                // 🔥 HANDLE LAB CONFIGS LOADING STATE
                                labConfigsAsync.when(
                                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                                  error: (e, s) => Text("Failed to load lab configs", style: TextStyle(color: colorScheme.error)),
                                  data: (configs) {
                                    return _buildComparisonCard(context, _buildLabRows(context, configs));
                                  },
                                )
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

// 🔥 PREMIUM FLOATING HEADER (No App Bar)
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Row(
        children: [
          // Premium Standalone Back Button
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: 2.0), // Visually centers the iOS arrow
                child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Clean, Bold Title
          Text(
            "Progress Comparison",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSelectors(List<VitalsModel> history, BuildContext context) {
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
              items: items.map((v) => DropdownMenuItem(value: v, child: Text(DateFormat('dd MMM yy').format(v.date), overflow: TextOverflow.ellipsis))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCard(BuildContext context, List<Widget> children) {
    if (children.isEmpty) return const SizedBox();
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

// 🔥 UPDATED: Now accepts nullable doubles (double?)
  Widget _buildDiffRow(BuildContext context, String label, double? val1, double? val2, {bool inverse = false, String unit = ""}) {
    if (val1 == null && val2 == null) return const SizedBox();

    final theme = Theme.of(context);

    // Format the strings, converting nulls to "N/A"
    String val1Str = val1 == null ? "N/A" : (val1 % 1 == 0 ? val1.toInt().toString() : val1.toStringAsFixed(1));
    String val2Str = val2 == null ? "N/A" : (val2 % 1 == 0 ? val2.toInt().toString() : val2.toStringAsFixed(1));
    String unitStr = unit.isNotEmpty ? " $unit" : "";

    Widget differenceBadge;

    // If either value is missing, we cannot calculate a difference
    if (val1 == null || val2 == null) {
      differenceBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: const Text("-", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    } else {
      // Normal percentage calculation if both exist
      double diff = val2 - val1;
      double pct = val1 != 0 ? (diff / val1) * 100 : 0;
      bool isImprovement = inverse ? (diff <= 0) : (diff >= 0);

      Color color = diff == 0 ? Colors.grey : (isImprovement ? Colors.green : Colors.red);
      IconData icon = diff > 0 ? Icons.arrow_upward : (diff < 0 ? Icons.arrow_downward : Icons.remove);

      differenceBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text("${diff.abs() % 1 == 0 ? diff.abs().toInt() : diff.abs().toStringAsFixed(1)} (${pct.abs().toStringAsFixed(0)}%)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    children: [
                      const TextSpan(text: "Prev: ", style: TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: val1 == null ? "N/A" : "$val1Str$unitStr"),
                      const TextSpan(text: "  |  ", style: TextStyle(color: Colors.grey)),
                      const TextSpan(text: "Now: ", style: TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: val2 == null ? "N/A" : "$val2Str$unitStr", style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          differenceBadge
        ],
      ),
    );
  }
  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))),
    );
  }

  // 🔥 CHANGED: Now checks if ANY labs exist in either record (Union instead of Intersection)
  bool _hasAnyLabs(VitalsModel a, VitalsModel b) {
    final keysA = a.labResults.keys.toSet();
    final keysB = b.labResults.keys.toSet();
    return keysA.union(keysB).isNotEmpty;
  }

  // 🔥 UPDATED: Dynamically uses Firestore Configs!
// 🔥 UPDATED: Uses Union to show missing data
  List<Widget> _buildLabRows(BuildContext context, List/*<LabTestConfigModel>*/ configs) {
    if (_baseRecord == null || _compareRecord == null) return [];

    List<Widget> rows = [];
    final keysA = _baseRecord!.labResults.keys.toSet();
    final keysB = _compareRecord!.labResults.keys.toSet();

    // 🔥 COMBINE ALL KEYS (If it exists in A, B, or Both)
    final allKeys = keysA.union(keysB);

    if (allKeys.isEmpty) return [const Text("No lab results found for these dates.")];

    for (var key in allKeys) {
      // These might be null now if the test was skipped on one of the dates!
      double? v1 = _baseRecord!.labResults[key];
      double? v2 = _compareRecord!.labResults[key];

      var config;
      try {
        config = configs.firstWhere((test) => test.id.trim().toLowerCase() == key.trim().toLowerCase());
      } catch (e) {
        config = null;
      }

      String label = config != null ? config.name : key.replaceAll('_', ' ').toUpperCase();
      String unit = config?.unit ?? "";

      bool inverse = true;
      if (config != null) {
        inverse = !config.isReverseLogic;
      } else {
        inverse = !['hdl', 'hemoglobin', 'calcium', 'vitamin_d', 'vitamin_b12'].contains(key.trim().toLowerCase());
      }

      rows.add(_buildDiffRow(context, label, v1, v2, inverse: inverse, unit: unit));
    }
    return rows;
  }
}