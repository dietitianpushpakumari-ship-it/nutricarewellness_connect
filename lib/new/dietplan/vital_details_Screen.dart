import 'dart:ui';
import 'dart:math'; // 🔥 Required for Sparklines
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/vitals_comprasion_screen.dart';

import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

// 🔥 IMPORT YOUR COMPARISON SCREEN HERE
// import 'package:nutricare_connect/core/vitals_comprasion_screen.dart';

class VitalsDetailScreen extends ConsumerWidget {
  final VitalsModel record;

  const VitalsDetailScreen({super.key, required this.record});

  // 🧠 SMART DATA EXTRACTOR
  List<String> _extractTags(Map<String, String>? data, {String? ignoreKey}) {
    if (data == null || data.isEmpty) return [];
    List<String> tags = [];
    data.forEach((key, value) {
      if (ignoreKey != null && key.trim().toLowerCase() == ignoreKey.toLowerCase()) return;
      final val = value.trim();
      final valLower = val.toLowerCase();
      if (valLower == 'false') return;
      if (valLower == 'true' || valLower == 'not specified' || val.isEmpty || key.trim() == val) {
        tags.add(key.trim());
      } else {
        tags.add("${key.trim()} ($val)");
      }
    });
    return tags;
  }

  // 🧠 LAB ID FORMATTER
  String _formatLabKey(String key) {
    String spaced = key.replaceAll('_', ' ').replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1 $2');
    return spaced.toUpperCase().trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 📡 FETCHERS
    final labConfigsAsync = ref.watch(labTestConfigsProvider);
    final historyAsync = ref.watch(vitalsHistoryProvider(record.clientId));

    // 🏷️ EXTRACTED DATA
    final diagnoses = _extractTags(record.nutritionDiagnoses);
    final complaints = _extractTags(record.clinicalComplaints);
    final history = _extractTags(record.medicalHistory);
    final giDetails = _extractTags(record.giDetails);
    final guidelines = _extractTags(record.clinicalGuidelines);
    final notes = _extractTags(record.clinicalNotes, ignoreKey: 'next review');

    String? nextReview;
    if (record.clinicalNotes != null && record.clinicalNotes!.containsKey('Next Review')) {
      final val = record.clinicalNotes!['Next Review']!.trim();
      if (val.isNotEmpty && val.toLowerCase() != 'not specified') {
        nextReview = val;
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100, right: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05), blurRadius: 80, spreadRadius: 30)]),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, theme, colorScheme, isDark),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 📅 DATE BADGE ---
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: isDark ? colorScheme.surfaceContainerHighest : colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withOpacity(0.2))),
                            child: Text(DateFormat('EEEE, d MMMM yyyy • h:mm a').format(record.date), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? colorScheme.onSurface : colorScheme.primary, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- ⚖️ NEW: QUICK COMPARE BUTTON ---
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigate directly to the comparison screen
                               Navigator.push(context, MaterialPageRoute(builder: (_) => VitalsComparisonScreen(clientId: record.clientId)));
                            },
                            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                            label: const Text("Compare with Past Records", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- 🧍‍♂️ SECTION 1: STANDARD BODY METRICS ---
                        _buildSectionHeader("Body Metrics", Icons.accessibility_new_rounded, colorScheme),
                        _buildDetailCard(theme, isDark, [
                          _buildRow("Weight", "${record.weightKg} kg", theme, colorScheme, isHighlight: true),
                          _buildRow("Height", "${record.heightCm} cm", theme, colorScheme),
                          _buildRow("BMI", record.bmi.toStringAsFixed(1), theme, colorScheme, customColor: _getBmiColor(record.bmi, isDark)),
                          if (record.bodyFatPercentage > 0) _buildRow("Body Fat", "${record.bodyFatPercentage}%", theme, colorScheme),
                          if (record.waistCm != null && record.waistCm! > 0) _buildRow("Waist", "${record.waistCm} cm", theme, colorScheme),
                          if (record.hipCm != null && record.hipCm! > 0) _buildRow("Hip", "${record.hipCm} cm", theme, colorScheme),
                          if (record.idealBodyWeightKg > 0) _buildRow("Ideal Weight", "${record.idealBodyWeightKg} kg", theme, colorScheme),
                        ]),

                        // --- ❤️ SECTION 2: VITALS & HEART ---
                        _buildSectionHeader("Vitals & Heart", Icons.favorite_rounded, colorScheme),
                        _buildDetailCard(theme, isDark, [
                          _buildRow("Blood Pressure", record.bloodPressureSystolic != null ? "${record.bloodPressureSystolic}/${record.bloodPressureDiastolic} mmHg" : "Not recorded", theme, colorScheme, customColor: isDark ? Colors.redAccent : Colors.red.shade700),
                          _buildRow("Heart Rate", record.heartRate != null ? "${record.heartRate} bpm" : "Not recorded", theme, colorScheme),
                          _buildRow("SpO2", record.spO2Percentage != null ? "${record.spO2Percentage} %" : "Not recorded", theme, colorScheme, customColor: isDark ? Colors.tealAccent : Colors.teal),
                        ]),

                        // --- 🔬 SECTION 3: LAB RESULTS WITH TRENDS ---
                        if (record.labResults.isNotEmpty) ...[
                          _buildSectionHeader("Lab Report Data", Icons.science_rounded, colorScheme),

                          labConfigsAsync.when(
                              loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                              error: (e, s) => _buildDetailCard(theme, isDark, [Text("Failed to load lab config data: $e", style: TextStyle(color: colorScheme.error))]),
                              data: (configs) {

                                // Historical records for the sparkline trend
                                List<VitalsModel> pastRecords = [];
                                if (historyAsync.hasValue && historyAsync.value != null) {
                                  pastRecords = historyAsync.value!
                                      .where((h) => h.date.isBefore(record.date) || h.id == record.id)
                                      .toList();
                                  pastRecords.sort((a, b) => a.date.compareTo(b.date));
                                }

                                Map<String, List<MapEntry<String, double>>> groupedLabs = {};
                                for (var entry in record.labResults.entries) {
                                  var config;
                                  try { config = configs.firstWhere((test) => test.id.trim().toLowerCase() == entry.key.trim().toLowerCase()); } catch (_) { config = null; }
                                  String category = (config != null && config.categoryName.isNotEmpty) ? config.categoryName : "Other Tests";
                                  groupedLabs.putIfAbsent(category, () => []).add(entry);
                                }

                                List<Widget> categoryWidgets = [];
                                int index = 0;

                                groupedLabs.forEach((category, entries) {
                                  categoryWidgets.add(
                                      Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), margin: EdgeInsets.only(bottom: 16, top: index == 0 ? 0 : 20),
                                              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: colorScheme.primary.withOpacity(0.1))),
                                              child: Text(category.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.0)),
                                            ),

                                            ...entries.map((e) {
                                              var config;
                                              try { config = configs.firstWhere((test) => test.id.trim().toLowerCase() == e.key.trim().toLowerCase()); } catch (_) {}

                                              List<double> trendData = pastRecords
                                                  .map((r) => r.labResults[e.key])
                                                  .where((val) => val != null)
                                                  .cast<double>()
                                                  .toList();

                                              return _buildLabRow(e.key, e.value, config, trendData, theme, colorScheme, isDark);
                                            }).toList(),
                                          ]
                                      )
                                  );
                                  index++;
                                });

                                return _buildDetailCard(theme, isDark, categoryWidgets);
                              }
                          )
                        ],

                        // --- 📋 SECTION 4: CLINICAL PROFILE ---
                        if (diagnoses.isNotEmpty || history.isNotEmpty || complaints.isNotEmpty || record.foodAllergies.isNotEmpty) ...[
                          _buildSectionHeader("Clinical Profile", Icons.medical_services_rounded, colorScheme),
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10)]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if(diagnoses.isNotEmpty) ...[_buildTagGroup("Diagnosis", diagnoses, isDark ? Colors.redAccent : Colors.red, isDark), Divider(height: 24, color: theme.dividerColor.withOpacity(0.5))],
                                if(history.isNotEmpty) ...[_buildTagGroup("Medical History", history, isDark ? Colors.blueGrey.shade300 : Colors.blueGrey, isDark), Divider(height: 24, color: theme.dividerColor.withOpacity(0.5))],
                                if(complaints.isNotEmpty) ...[_buildTagGroup("Complaints & Symptoms", complaints, isDark ? Colors.orangeAccent : Colors.orange, isDark), Divider(height: 24, color: theme.dividerColor.withOpacity(0.5))],
                                if(record.foodAllergies.isNotEmpty) ...[_buildTagGroup("Allergies", record.foodAllergies, isDark ? Colors.pinkAccent : Colors.pink, isDark)]
                              ],
                            ),
                          ),
                        ],

                        // --- 📝 SECTION 5: CLINICAL NOTES & GUIDELINES ---
                        if (notes.isNotEmpty || guidelines.isNotEmpty) ...[
                          _buildSectionHeader("Dietitian Notes", Icons.edit_note_rounded, colorScheme),
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(color: isDark ? colorScheme.primary.withOpacity(0.1) : colorScheme.primaryContainer.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (notes.isNotEmpty) ...[Text("Clinical Notes:", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 13)), const SizedBox(height: 8), ...notes.map((n) => Text("• $n", style: TextStyle(fontSize: 14, color: colorScheme.onSurface, height: 1.4))), if (guidelines.isNotEmpty) const SizedBox(height: 16)],
                                if (guidelines.isNotEmpty) ...[Text("Action Guidelines:", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 13)), const SizedBox(height: 8), ...guidelines.map((g) => Text("• $g", style: TextStyle(fontSize: 14, color: colorScheme.onSurface, height: 1.4)))],
                              ],
                            ),
                          ),
                        ],

                        // --- 💊 SECTION 6: MEDICATIONS ---
                        if (record.medications.isNotEmpty) ...[
                          _buildSectionHeader("Medications", Icons.medication_rounded, colorScheme),
                          _buildDetailCard(theme, isDark,
                            record.medications.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface)), Text(m.instruction, style: TextStyle(fontSize: 12, color: theme.hintColor, fontStyle: FontStyle.italic))])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(m.frequency, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary)), Text(m.duration, style: TextStyle(fontSize: 11, color: theme.hintColor))]),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],

                        // --- 🧘 SECTION 7: LIFESTYLE & DIET ---
                        _buildSectionHeader("Lifestyle & Digestion", Icons.self_improvement_rounded, colorScheme),
                        _buildDetailCard(theme, isDark, [
                          _buildRow("Food Habit", record.foodHabit ?? "Not set", theme, colorScheme),
                          _buildRow("Activity Level", record.activityType ?? "Not set", theme, colorScheme),
                          if (record.restrictedDiet != null && record.restrictedDiet!.isNotEmpty) _buildRow("Restricted Diet", record.restrictedDiet!, theme, colorScheme, customColor: Colors.orange),
                          if (giDetails.isNotEmpty) ...[const Divider(height: 24), _buildTagGroup("GI / Digestion Details", giDetails, isDark ? Colors.tealAccent : Colors.teal, isDark)],
                          if (record.waterIntake != null && record.waterIntake!.isNotEmpty) ...[const Divider(height: 24), _buildRow("Water Intake", record.waterIntake!.values.first, theme, colorScheme, customColor: Colors.blue)],
                          if (record.caffeineIntake != null && record.caffeineIntake!.isNotEmpty) ...[const Divider(height: 24), _buildRow("Caffeine Intake", record.caffeineIntake!.values.first, theme, colorScheme, customColor: Colors.brown)]
                        ]),

                        // --- 📅 NEXT REVIEW BANNER ---
                        if (nextReview != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: colorScheme.primary.withOpacity(0.3), width: 1.5)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_month_rounded, color: colorScheme.primary, size: 20), const SizedBox(width: 12),
                                Flexible(child: RichText(text: TextSpan(children: [TextSpan(text: "Next Review: ", style: TextStyle(fontSize: 14, color: colorScheme.primary, fontWeight: FontWeight.w600)), TextSpan(text: nextReview, style: TextStyle(fontSize: 15, color: colorScheme.primary, fontWeight: FontWeight.w900))]))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔬 SMART LAB ROW WITH TRENDS
  Widget _buildLabRow(String key, double val, dynamic config, List<double> trendData, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    String label = config != null ? config.name : _formatLabKey(key);
    String unit = config?.unit ?? "";

    double? minLimit = config?.minRange;
    double? maxLimit = config?.maxRange;

    bool isLow = minLimit != null && val < minLimit;
    bool isHigh = maxLimit != null && val > maxLimit;
    bool isAbnormal = isLow || isHigh;

    String rangeText = "";
    if (minLimit != null && maxLimit != null) rangeText = "Range: $minLimit - $maxLimit $unit";
    else if (minLimit != null) rangeText = "Range: > $minLimit $unit";
    else if (maxLimit != null) rangeText = "Range: < $maxLimit $unit";

    Color valueColor = isAbnormal ? (isDark ? Colors.redAccent : Colors.red.shade700) : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: theme.hintColor, fontSize: 14, fontWeight: FontWeight.w600)),
                if (rangeText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(rangeText, style: TextStyle(color: theme.dividerColor.withOpacity(isDark ? 0.8 : 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                ],

                // 📈 THE MINI SPARKLINE TREND
                if (trendData.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 40, height: 16,
                        child: CustomPaint(painter: SparklinePainter(trendData, valueColor.withOpacity(isAbnormal ? 0.8 : 0.4))),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          "Prev: ${trendData[trendData.length - 2] % 1 == 0 ? trendData[trendData.length - 2].toInt() : trendData[trendData.length - 2].toStringAsFixed(1)}",
                          style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w600)
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: valueColor)),
                  if (unit.isNotEmpty) ...[const SizedBox(width: 2), Text(unit, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAbnormal ? valueColor.withOpacity(0.8) : theme.hintColor))]
                ],
              ),
              if (isAbnormal)
                Container(
                  margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: valueColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: valueColor.withOpacity(0.3))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isLow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 10, color: valueColor),
                      const SizedBox(width: 2),
                      Text(isLow ? "LOW" : "HIGH", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: valueColor, letterSpacing: 0.5)),
                    ],
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor.withOpacity(0.8), border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)))),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.iconTheme.color),
                ),
              ),
              const SizedBox(width: 16),
              Text("Full Health Record", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme colorScheme) {
    return Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Row(children: [Icon(icon, size: 18, color: colorScheme.primary), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface))]));
  }

  Widget _buildDetailCard(ThemeData theme, bool isDark, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value, ThemeData theme, ColorScheme colorScheme, {bool isHighlight = false, Color? customColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.hintColor, fontSize: 14, fontWeight: FontWeight.w500))),
          const SizedBox(width: 16),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold, fontSize: isHighlight ? 16 : 14, color: customColor ?? colorScheme.onSurface))),
        ],
      ),
    );
  }

  Widget _buildTagGroup(String label, List<String> items, Color baseColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: baseColor)),
        const SizedBox(height: 10),
        if (items.isEmpty) const Text("-", style: TextStyle(color: Colors.grey))
        else Wrap(
          spacing: 8, runSpacing: 8,
          children: items.map((item) {
            String text = item.trim(); String duration = "";
            if (text.contains('(') && text.endsWith(')')) { final parts = text.split('('); text = parts[0].trim(); duration = parts[1].replaceAll(')', '').trim(); }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: baseColor.withOpacity(isDark ? 0.15 : 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: baseColor.withOpacity(0.3))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: baseColor)),
                  if (duration.isNotEmpty) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: baseColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text(duration, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: baseColor)))]
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getBmiColor(double bmi, bool isDark) {
    if (bmi == 0) return Colors.grey;
    if (bmi < 18.5) return isDark ? Colors.orangeAccent : Colors.orange;
    if (bmi < 25) return isDark ? Colors.greenAccent : Colors.green;
    if (bmi < 30) return isDark ? Colors.orangeAccent : Colors.orange;
    return isDark ? Colors.redAccent : Colors.red;
  }
}

// ==========================================
// 🎨 MINI SPARKLINE PAINTER (FOR LAB TRENDS)
// ==========================================
class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce(max);
    final minVal = data.reduce(min);
    final range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final path = Path();
    final xStep = size.width / (data.length > 1 ? data.length - 1 : 1);

    for(int i = 0; i < data.length; i++) {
      final x = i * xStep;
      // Invert Y axis (canvas draws top to bottom)
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }

    // Draw the Line
    canvas.drawPath(
        path,
        Paint()..color = color..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
    );

    // Draw a prominent dot at the very end to indicate "Current Value"
    final lastX = size.width;
    final lastY = size.height - ((data.last - minVal) / range) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 2.5, Paint()..color = color.withOpacity(1.0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}