import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/lab_vitals_data.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';

class LabReportDetailScreen extends StatelessWidget {
  final VitalsModel record;

  final Map<String, LabTest> allLabTests = LabVitalsData.allLabTests;
  final Map<String, List<String>> labTestGroups = LabVitalsData.labTestGroups;

  LabReportDetailScreen({super.key, required this.record});

  // --- Color Coding Logic (Adapted from Admin App for Client View) ---
  Color _getLabValueColor(
    String key,
    String resultValue, {
    required String value,
    required bool isMale,
  }) {
    final test = allLabTests[key];
    if (test == null || value.isEmpty || test.referenceRange.isEmpty) {
      return Colors.black87;
    }

    try {
      final numValue = num.tryParse(value);
      if (numValue == null) return Colors.black87;

      // 1. Clean and parse the reference range string
      String reference = test.referenceRange;
      if (reference.contains('(M)') || reference.contains('(F)')) {
        reference = reference.split(isMale ? '(M)' : '(F)').first.trim();
      }
      reference = reference.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

      // 2. Check and compare based on the cleaned reference string format

      // Standard Range: X - Y (e.g., "70 - 100")
      if (reference.contains('-')) {
        final parts = reference.split('-').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          final min = num.tryParse(parts[0]);
          final max = num.tryParse(parts[1]);
          if (min != null &&
              max != null &&
              (numValue < min || numValue > max)) {
            return Colors.red.shade700; // Out of range
          }
        }
      }
      // Maximum Limit: < X
      else if (reference.trim().startsWith('<')) {
        final maxStr = reference.substring(reference.indexOf('<') + 1).trim();
        final max = num.tryParse(maxStr);
        if (max != null && numValue >= max) {
          return Colors.red.shade700; // Too high
        }
      }
      // Minimum Limit: > Y
      else if (reference.trim().startsWith('>')) {
        final minStr = reference.substring(reference.indexOf('>') + 1).trim();
        final min = num.tryParse(minStr);
        if (min != null && numValue <= min) {
          return Colors.red.shade700; // Too low
        }
      }

      return Colors.green.shade700; // In range
    } catch (e) {
      return Colors.black87; // Parsing error
    }
  }

  // --- UI Builders ---
  Widget _buildLabTestTable() {
    // Determine gender for reference range check
    // NOTE: ClientModel is not available here, so we assume a default gender or simplify the check.
    const bool isMale = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labTestGroups.entries.map((entry) {
        final category = entry.key;
        final testKeys = entry.value;

        final testsWithResults = testKeys
            .where(
              (key) =>
                  record.labResults.containsKey(key) &&
                  record.labResults[key]!.isNotEmpty,
            )
            .toList();

        if (testsWithResults.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
              const Divider(thickness: 2),

              // Table Rows
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(2.5),
                },
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade200),
                    children: [
                      _buildTableCell('Test Name', isHeader: true),
                      _buildTableCell('Result', isHeader: true),
                      _buildTableCell('Reference Range', isHeader: true),
                    ],
                  ),
                  // Data Rows
                  ...testsWithResults.map((key) {
                    final test = allLabTests[key]!;
                    final resultValue = record.labResults[key]!;
                    final color = _getLabValueColor(
                      key,
                      resultValue,
                      value: test.referenceRange,
                      isMale: isMale,
                    );

                    return TableRow(
                      children: [
                        _buildTableCell(test.displayName, isHeader: false),
                        _buildTableCell(
                          '$resultValue ${test.unit}',
                          color: color,
                        ),
                        _buildTableCell(test.referenceRange, isReference: true),
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

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isReference = false,
    Color color = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.w800 : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vitals Report - ${DateFormat.yMMMd().format(record.date)}',
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Section 1: Core Metrics ---
            Text(
              'Client Metrics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),
            _buildMetricRow(
              'Height',
              '${record.heightCm.toStringAsFixed(1)} cm',
            ),
            _buildMetricRow(
              'Weight',
              '${record.weightKg.toStringAsFixed(1)} kg',
            ),
            _buildMetricRow('BMI', record.bmi.toStringAsFixed(1)),
            _buildMetricRow(
              'Body Fat %',
              '${record.bodyFatPercentage.toStringAsFixed(1)} %',
            ),

            const SizedBox(height: 30),

            // --- Section 2: Lab Results ---
            Text(
              'Lab Results (${record.labResults.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),

            if (record.labResults.isEmpty)
              const Text(
                'No lab results recorded for this entry.',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              _buildLabTestTable(),

            const SizedBox(height: 30),

            // --- Section 3: Notes and Documents ---
            Text(
              'Clinical Notes',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(),
            Text(
              record.notes ?? 'No notes provided.',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            if (record.labReportUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Lab Report Files: ${record.labReportUrls.length} attached.',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
