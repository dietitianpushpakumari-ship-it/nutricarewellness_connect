import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/new/models/vitals_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

// 🔥 Make sure to import your new model and provider
// import 'package:pure_shift/new/models/lab_test_config_model.dart';
// import 'package:pure_shift/new/provider/lab_config_provider.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class VitalsComparisonSheet extends ConsumerStatefulWidget {
  final String clientId;
  const VitalsComparisonSheet({super.key, required this.clientId});

  @override
  ConsumerState<VitalsComparisonSheet> createState() => _VitalsComparisonSheetState();
}

class _VitalsComparisonSheetState extends ConsumerState<VitalsComparisonSheet> {
  VitalsModel? _baseRecord;
  VitalsModel? _compareRecord;
  bool _isInitialized = false;

  void _initRecords(List<VitalsModel> history) {
    if (_isInitialized || history.isEmpty) return;
    final sorted = List<VitalsModel>.from(history)..sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _baseRecord = sorted.first;
      // 🚀 FIX: If there is only 1 record, baseline and current will default to the same record.
      _compareRecord = sorted.last;
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));
    final labConfigsAsync = ref.watch(labTestConfigsProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

            // 🚀 PREMIUM HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("CLINICAL HISTORY", style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Progress Comparison", style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      }
                  )
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

            Expanded(
              child: vitalsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text("Error: $e", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: colorScheme.error))),
                data: (history) {
                  // 🚀 FIX: Removed the < 2 restriction. Now works even with 1 record.
                  if (history.isEmpty) {
                    return Center(child: Text("No records available.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor)));
                  }

                  if (!_isInitialized) _initRecords(history);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
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
                            if (_baseRecord!.waistCm != null || _compareRecord!.waistCm != null)
                              _buildDiffRow(context, "Waist", _baseRecord!.waistCm, _compareRecord!.waistCm, inverse: true, unit: "cm"),
                          ]),
                          const SizedBox(height: 24),

                          _buildSectionTitle("Vitals & Heart", context),
                          _buildComparisonCard(context, [
                            _buildDiffRow(context, "BP Systolic", _baseRecord!.bloodPressureSystolic?.toDouble(), _compareRecord!.bloodPressureSystolic?.toDouble(), inverse: true, unit: "mmHg"),
                            _buildDiffRow(context, "BP Diastolic", _baseRecord!.bloodPressureDiastolic?.toDouble(), _compareRecord!.bloodPressureDiastolic?.toDouble(), inverse: true, unit: "mmHg"),
                            _buildDiffRow(context, "Heart Rate", _baseRecord!.heartRate?.toDouble(), _compareRecord!.heartRate?.toDouble(), inverse: true, unit: "bpm"),
                          ]),
                          const SizedBox(height: 24),

                          if (_hasAnyLabs(_baseRecord!, _compareRecord!)) ...[
                            _buildSectionTitle("Key Lab Markers", context),

                            labConfigsAsync.when(
                              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                              error: (e, s) => Text("Failed to load lab configs", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: colorScheme.error)),
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
    );
  }

  // --- WIDGETS ---

  Widget _buildComparisonSelectors(List<VitalsModel> history, BuildContext context) {
    final sorted = List<VitalsModel>.from(history)..sort((a, b) => b.date.compareTo(a.date));
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildDropdown(context, "Baseline", _baseRecord, sorted, (v) {
                HapticFeedback.selectionClick();
                setState(() => _baseRecord = v);
              })
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary, size: 16),
          ),
          Expanded(
              child: _buildDropdown(context, "Current", _compareRecord, sorted, (v) {
                HapticFeedback.selectionClick();
                setState(() => _compareRecord = v);
              })
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, String label, VitalsModel? value, List<VitalsModel> items, ValueChanged<VitalsModel?> onChanged) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 10, fontWeight: FontWeight.w700, color: theme.hintColor)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1))
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VitalsModel>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: theme.colorScheme.onSurface),
              style: TextStyle(fontFamily: kDisplayFont, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 11),
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
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDiffRow(BuildContext context, String label, double? val1, double? val2, {bool inverse = false, String unit = ""}) {
    if (val1 == null && val2 == null) return const SizedBox();

    final theme = Theme.of(context);

    String val1Str = val1 == null ? "N/A" : (val1 % 1 == 0 ? val1.toInt().toString() : val1.toStringAsFixed(1));
    String val2Str = val2 == null ? "N/A" : (val2 % 1 == 0 ? val2.toInt().toString() : val2.toStringAsFixed(1));
    String unitStr = unit.isNotEmpty ? " $unit" : "";

    Widget differenceBadge;

    if (val1 == null || val2 == null) {
      differenceBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text("-", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: theme.hintColor)),
      );
    } else {
      double diff = val2 - val1;
      double pct = val1 != 0 ? (diff / val1) * 100 : 0;
      bool isImprovement = inverse ? (diff <= 0) : (diff >= 0);

      Color color = diff == 0 ? theme.hintColor : (isImprovement ? Colors.green : Colors.redAccent);
      IconData icon = diff > 0 ? Icons.arrow_upward_rounded : (diff < 0 ? Icons.arrow_downward_rounded : Icons.remove_rounded);

      differenceBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text("${diff.abs() % 1 == 0 ? diff.abs().toInt() : diff.abs().toStringAsFixed(1)} (${pct.abs().toStringAsFixed(0)}%)", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: color)),
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
                Text(label, style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 12, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, color: theme.hintColor),
                    children: [
                      const TextSpan(text: "Prev: ", style: TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(text: val1 == null ? "N/A" : "$val1Str$unitStr", style: TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: "  |  ", style: TextStyle(color: Colors.grey)),
                      const TextSpan(text: "Now: ", style: TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(text: val2 == null ? "N/A" : "$val2Str$unitStr", style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700)),
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
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Theme.of(context).colorScheme.primary))
      ),
    );
  }

  bool _hasAnyLabs(VitalsModel a, VitalsModel b) {
    final keysA = a.labResults.keys.toSet();
    final keysB = b.labResults.keys.toSet();
    return keysA.union(keysB).isNotEmpty;
  }

  List<Widget> _buildLabRows(BuildContext context, List/*<LabTestConfigModel>*/ configs) {
    if (_baseRecord == null || _compareRecord == null) return [];

    List<Widget> rows = [];
    final keysA = _baseRecord!.labResults.keys.toSet();
    final keysB = _compareRecord!.labResults.keys.toSet();

    final allKeys = keysA.union(keysB);

    if (allKeys.isEmpty) {
      return [Text("No lab results found for these dates.", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: Theme.of(context).hintColor))];
    }

    for (var key in allKeys) {
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