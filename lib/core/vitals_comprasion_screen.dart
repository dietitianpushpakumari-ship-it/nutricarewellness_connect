import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';

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
    final sorted = List<VitalsModel>.from(history)..sort((a, b) => a.date.compareTo(b.date));
    _baseRecord = sorted.first;
    _compareRecord = sorted.last;
    _isInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          // 1. Ambient Glow
          Positioned(
              top: -100, right: -80,
              child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 80, spreadRadius: 30)]))),

          SafeArea(
            child: Column(
              children: [
                // 2. Header
                _buildHeader(context),

                // 3. Content
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e")),
                    data: (history) {
                      if (history.length < 2) {
                        return const Center(child: Text("Need at least 2 records to compare."));
                      }
                      _initRecords(history);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                        child: Column(
                          children: [
                            // Selectors
                            _buildComparisonSelectors(history),
                            const SizedBox(height: 24),

                            // Report
                            if (_baseRecord != null && _compareRecord != null) ...[
                              _buildSectionTitle("Anthropometry (Body)"),
                              _buildComparisonCard([
                                _buildDiffRow("Weight (kg)", _baseRecord!.weightKg, _compareRecord!.weightKg, inverse: true),
                                _buildDiffRow("BMI", _baseRecord!.bmi, _compareRecord!.bmi, inverse: true),
                                if (_baseRecord!.bodyFatPercentage > 0 || _compareRecord!.bodyFatPercentage > 0)
                                  _buildDiffRow("Body Fat %", _baseRecord!.bodyFatPercentage, _compareRecord!.bodyFatPercentage, inverse: true),
                                if (_baseRecord!.waistCm != null && _compareRecord!.waistCm != null)
                                  _buildDiffRow("Waist (cm)", _baseRecord!.waistCm!, _compareRecord!.waistCm!, inverse: true),
                              ]),
                              const SizedBox(height: 20),

                              _buildSectionTitle("Vitals & Heart"),
                              _buildComparisonCard([
                                _buildDiffRow("BP Systolic", _baseRecord!.bloodPressureSystolic?.toDouble() ?? 0, _compareRecord!.bloodPressureSystolic?.toDouble() ?? 0, inverse: true),
                                _buildDiffRow("BP Diastolic", _baseRecord!.bloodPressureDiastolic?.toDouble() ?? 0, _compareRecord!.bloodPressureDiastolic?.toDouble() ?? 0, inverse: true),
                                _buildDiffRow("Heart Rate", _baseRecord!.heartRate?.toDouble() ?? 0, _compareRecord!.heartRate?.toDouble() ?? 0, inverse: true),
                              ]),
                              const SizedBox(height: 20),

                              if (_hasCommonLabs(_baseRecord!, _compareRecord!)) ...[
                                _buildSectionTitle("Key Lab Markers"),
                                _buildComparisonCard(_buildLabRows()),
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
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1)))),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87))),
            const SizedBox(width: 16),
            const Text("Progress Comparison", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
          ]),
        ),
      ),
    );
  }

  Widget _buildComparisonSelectors(List<VitalsModel> history) {
    // Sort by date descending for dropdown
    final sorted = List<VitalsModel>.from(history)..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Row(
        children: [
          Expanded(child: _buildDropdown("Baseline", _baseRecord, sorted, (v) => setState(() => _baseRecord = v))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward, color: Colors.indigo, size: 20),
          ),
          Expanded(child: _buildDropdown("Current", _compareRecord, sorted, (v) => setState(() => _compareRecord = v))),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, VitalsModel? value, List<VitalsModel> items, ValueChanged<VitalsModel?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VitalsModel>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16),
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
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

  Widget _buildComparisonCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(children: children),
    );
  }

  Widget _buildDiffRow(String label, double val1, double val2, {bool inverse = false}) {
    if (val1 == 0 && val2 == 0) return const SizedBox();

    double diff = val2 - val1;
    double pct = val1 != 0 ? (diff / val1) * 100 : 0;
    bool isImprovement = inverse ? (diff <= 0) : (diff >= 0); // For weight/BP, lower is usually better (inverse=true)

    Color color = diff == 0 ? Colors.grey : (isImprovement ? Colors.green : Colors.red);
    IconData icon = diff > 0 ? Icons.arrow_upward : (diff < 0 ? Icons.arrow_downward : Icons.remove);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142))),
                Text("${val1.toStringAsFixed(1)} → ${val2.toStringAsFixed(1)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
    );
  }

  bool _hasCommonLabs(VitalsModel a, VitalsModel b) {
    // Check if any keys intersect
    final keysA = a.labResults.keys.toSet();
    final keysB = b.labResults.keys.toSet();
    return keysA.intersection(keysB).isNotEmpty;
  }

  List<Widget> _buildLabRows() {
    if (_baseRecord == null || _compareRecord == null) return [];

    List<Widget> rows = [];
    // Common keys to compare
    final commonKeys = _baseRecord!.labResults.keys.toSet().intersection(_compareRecord!.labResults.keys.toSet());

    for (var key in commonKeys) {
      double? v1 = double.tryParse(_baseRecord!.labResults[key] ?? '');
      double? v2 = double.tryParse(_compareRecord!.labResults[key] ?? '');

      if (v1 != null && v2 != null) {
        // Determine if "inverse" logic applies (usually lower is better for labs like sugar/lipid, but not for HDL/Hemoglobin)
        bool inverse = !['hdl', 'hemoglobin', 'calcium', 'vitamin_d', 'vitamin_b12'].contains(key.toLowerCase());
        rows.add(_buildDiffRow(key.toUpperCase(), v1, v2, inverse: inverse));
      }
    }
    return rows;
  }
}