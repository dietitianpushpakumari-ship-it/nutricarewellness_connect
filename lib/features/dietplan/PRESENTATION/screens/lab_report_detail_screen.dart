import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/core/lab_vitals_data.dart';
import 'package:pure_shift/new/models/vitals_model.dart';

class LabReportDetailScreen extends StatelessWidget {
  final VitalsModel record;

  // Access static data directly
  final Map<String, LabTest> allLabTests = LabVitalsData.allLabTests;
  final Map<String, List<String>> labTestGroups = LabVitalsData.labTestGroups;

  LabReportDetailScreen({super.key, required this.record});

  // --- Color Coding Logic (Fixed to accept Double) ---
  Color _getLabValueColor(double resultValue, String referenceRange, {bool isMale = true}) {
    if (referenceRange.isEmpty) {
      return Colors.black87;
    }

    try {
      final numValue = resultValue; // No parsing needed, it's already a double

      // 1. Clean the reference range string
      String reference = referenceRange;
      if (reference.contains('(M)') || reference.contains('(F)')) {
        reference = reference.split(isMale ? '(M)' : '(F)').first.trim();
      }
      // Remove any text in parentheses (e.g. units or comments)
      reference = reference.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

      // 2. Range Logic: X - Y (e.g., "70 - 100")
      if (reference.contains('-')) {
        final parts = reference.split('-').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          final min = num.tryParse(parts[0]);
          final max = num.tryParse(parts[1]);
          if (min != null && max != null) {
            if (numValue < min || numValue > max) {
              return Colors.red.shade700; // Out of range
            } else {
              return Colors.green.shade700; // In range
            }
          }
        }
      }
      // 3. Max Limit: < X
      else if (reference.startsWith('<')) {
        final maxStr = reference.substring(1).trim();
        final max = num.tryParse(maxStr);
        if (max != null) {
          return (numValue >= max) ? Colors.red.shade700 : Colors.green.shade700;
        }
      }
      // 4. Min Limit: > Y
      else if (reference.startsWith('>')) {
        final minStr = reference.substring(1).trim();
        final min = num.tryParse(minStr);
        if (min != null) {
          return (numValue <= min) ? Colors.red.shade700 : Colors.green.shade700;
        }
      }

      return Colors.black87; // Could not parse logic
    } catch (e) {
      return Colors.black87;
    }
  }

  // --- UI Builder ---
  Widget _buildLabTestTable(BuildContext context) {
    // Note: Assuming Gender is handled elsewhere or default to Male for reference logic
    const bool isMale = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labTestGroups.entries.map((entry) {
        final category = entry.key;
        final testKeys = entry.value;

        // 🎯 FIX 1: Removed .isNotEmpty check on double value
        final testsWithResults = testKeys.where((key) {
          return record.labResults.containsKey(key) && record.labResults[key] != null;
        }).toList();

        if (testsWithResults.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Divider(thickness: 2),

              // Data Table
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2.5),
                },
                border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: [
                      _buildTableCell('Test Name', isHeader: true),
                      _buildTableCell('Result', isHeader: true),
                      _buildTableCell('Ref. Range', isHeader: true),
                    ],
                  ),
                  // Rows
                  ...testsWithResults.map((key) {
                    // Safety check: key might be in group but not in allLabTests definition
                    if (!allLabTests.containsKey(key)) return const TableRow(children: [SizedBox(), SizedBox(), SizedBox()]);

                    final test = allLabTests[key]!;

                    // 🎯 FIX 2: Value is double, no casting needed
                    final double resultValue = record.labResults[key]!;

                    // 🎯 FIX 3: Pass double directly to helper
                    final color = _getLabValueColor(resultValue, test.referenceRange, isMale: isMale);

                    return TableRow(
                      children: [
                        _buildTableCell(test.displayName),
                        _buildTableCell('$resultValue ${test.unit}', color: color, isBold: true),
                        _buildTableCell(test.referenceRange, color: Colors.grey.shade600),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.black : color,
        ),
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lab Report - ${DateFormat('dd MMM yyyy').format(record.date)}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Metrics Card ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
              ),
              child: Column(
                children: [
                  _buildMetricRow(context, 'Height', '${record.heightCm} cm'),
                  _buildMetricRow(context, 'Weight', '${record.weightKg} kg'),
                  _buildMetricRow(context, 'BMI', record.bmi.toStringAsFixed(1)),
                  if(record.bodyFatPercentage > 0)
                    _buildMetricRow(context, 'Body Fat', '${record.bodyFatPercentage}%'),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- Lab Results ---
            Text('Clinical Analysis', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            if (record.labResults.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Text('No lab data available for this date.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            else
              _buildLabTestTable(context),

            // --- Notes ---
            if (record.clinicalNotes != null && record.clinicalNotes!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Doctor\'s Notes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade100)),
                child: Text(record.clinicalNotes as String, style: TextStyle(color: Colors.brown.shade800)),
              )
            ]
          ],
        ),
      ),
    );
  }
}