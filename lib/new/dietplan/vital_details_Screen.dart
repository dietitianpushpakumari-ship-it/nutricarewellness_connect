import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/models/prescription_model.dart';

class VitalsDetailScreen extends StatelessWidget {
  final VitalsModel record;

  const VitalsDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 🎨 Themed Background
      body: Stack(
        children: [
          // Ambient Background Glow
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
                // 1. Custom Header
                _buildHeader(context, theme, colorScheme, isDark),

                // 2. Scrollable Detail Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? colorScheme.surfaceContainerHighest : colorScheme.primaryContainer.withOpacity(0.3), // 🎨 Themed Bg
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                            ),
                            child: Text(
                              DateFormat('EEEE, d MMMM yyyy • h:mm a').format(record.date),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? colorScheme.onSurface : colorScheme.primary, // 🎨 Themed Text
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION 1: BODY METRICS
                        _buildSectionHeader("Body Metrics", Icons.accessibility_new_rounded, colorScheme),
                        _buildDetailCard(theme, isDark, [
                          _buildRow("Weight", "${record.weightKg} kg", theme, colorScheme, isHighlight: true),
                          _buildRow("Height", "${record.heightCm} cm", theme, colorScheme),
                          _buildRow("BMI", record.bmi.toStringAsFixed(1), theme, colorScheme, customColor: _getBmiColor(record.bmi, isDark)),
                          _buildRow("Body Fat", "${record.bodyFatPercentage}%", theme, colorScheme),
                          if (record.waistCm != null) _buildRow("Waist", "${record.waistCm} cm", theme, colorScheme),
                          if (record.hipCm != null) _buildRow("Hip", "${record.hipCm} cm", theme, colorScheme),
                          _buildRow("Ideal Weight", "${record.idealBodyWeightKg} kg", theme, colorScheme),
                        ]),

                        // SECTION 2: HEART & LUNGS
                        _buildSectionHeader("Vitals & Heart", Icons.favorite_rounded, colorScheme),
                        _buildDetailCard(theme, isDark, [
                          _buildRow(
                              "Blood Pressure",
                              record.bloodPressureSystolic != null
                                  ? "${record.bloodPressureSystolic}/${record.bloodPressureDiastolic} mmHg"
                                  : "Not recorded",
                              theme, colorScheme,
                              customColor: isDark ? Colors.redAccent : Colors.red.shade700
                          ),
                          _buildRow("Heart Rate", "${record.heartRate ?? '-'} bpm", theme, colorScheme),
                          _buildRow("SpO2", "${record.spO2Percentage ?? '-'} %", theme, colorScheme, customColor: isDark ? Colors.tealAccent : Colors.teal),
                        ]),

                        // SECTION 3: LAB RESULTS
                        if (record.labResults.isNotEmpty) ...[
                          _buildSectionHeader("Lab Report Data", Icons.science_rounded, colorScheme),
                          _buildDetailCard(theme, isDark,
                            record.labResults.entries.map((e) {
                              String key = e.key.toUpperCase();
                              return _buildRow(key, e.value.toString(), theme, colorScheme);
                            }).toList(),
                          ),
                        ],

                        // SECTION 4: CLINICAL PROFILE
                        _buildSectionHeader("Clinical Profile", Icons.medical_services_rounded, colorScheme),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: theme.cardColor, // 🎨 Themed Card
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Diagnose
                              if(record.nutritionDiagnoses != null && record.nutritionDiagnoses!.isNotEmpty)
                                _buildTagGroup("Diagnosis", record.nutritionDiagnoses!.values.toList(), isDark ? Colors.redAccent : Colors.red, isDark),
                              if(record.nutritionDiagnoses != null && record.nutritionDiagnoses!.isNotEmpty)
                                Divider(height: 24, color: theme.dividerColor.withOpacity(0.5)),

                              // Medical History
                              _buildTagGroup("Medical History", record.medicalHistory.values.toList(), isDark ? Colors.blueGrey.shade300 : Colors.blueGrey, isDark),

                              if(record.clinicalComplaints != null && record.clinicalComplaints!.isNotEmpty) ...[
                                Divider(height: 24, color: theme.dividerColor.withOpacity(0.5)),
                                _buildTagGroup("Complaints", record.clinicalComplaints!.values.toList(), isDark ? Colors.orangeAccent : Colors.orange, isDark),
                              ],

                              // Allergies
                              if (record.foodAllergies.isNotEmpty) ...[
                                Divider(height: 24, color: theme.dividerColor.withOpacity(0.5)),
                                _buildTagGroup("Allergies", record.foodAllergies, isDark ? Colors.pinkAccent : Colors.pink, isDark),
                              ]
                            ],
                          ),
                        ),

                        // SECTION 5: MEDICATIONS
                        if (record.medications.isNotEmpty) ...[
                          _buildSectionHeader("Medications", Icons.medication_rounded, colorScheme),
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: theme.cardColor, // 🎨 Themed Card
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...record.medications.map((m) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(m.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface)), // 🎨 Themed Text
                                              Text(m.instruction, style: TextStyle(fontSize: 12, color: theme.hintColor, fontStyle: FontStyle.italic)), // 🎨 Themed Hint
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(m.frequency, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary)), // 🎨 Themed Accent
                                            Text(m.duration, style: TextStyle(fontSize: 11, color: theme.hintColor)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        // SECTION 6: LIFESTYLE
                        _buildSectionHeader("Lifestyle", Icons.self_improvement_rounded, colorScheme),
                        _buildDetailCard(theme, isDark, [
                          _buildRow("Food Habit", record.foodHabit ?? "Not set", theme, colorScheme),
                          _buildRow("Activity Level", record.activityType ?? "Not set", theme, colorScheme),
                          if (record.otherLifestyleHabits != null)
                            ...record.otherLifestyleHabits!.entries.map((e) => _buildRow(e.key, e.value, theme, colorScheme)),
                        ]),

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

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.8), // 🎨 Themed Glass
            border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.cardColor, // 🎨 Themed Card
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)],
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.iconTheme.color),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                  "Full Health Record",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface) // 🎨 Themed Text
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary), // 🎨 Themed Icon
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)), // 🎨 Themed Text
        ],
      ),
    );
  }

  Widget _buildDetailCard(ThemeData theme, bool isDark, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor, // 🎨 Themed Card
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value, ThemeData theme, ColorScheme colorScheme, {bool isHighlight = false, Color? customColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor, fontSize: 14, fontWeight: FontWeight.w500)), // 🎨 Themed Hint
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
              fontSize: isHighlight ? 18 : 15,
              color: customColor ?? colorScheme.onSurface, // 🎨 Themed Data Text
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGroup(String label, List<String> items, Color baseColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: baseColor)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text("-", style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(isDark ? 0.2 : 0.1), // 🎨 Adaptive Tag Bg
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: baseColor.withOpacity(0.3)),
              ),
              child: Text(item.trim(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: baseColor)),
            )).toList(),
          ),
      ],
    );
  }

  Color _getBmiColor(double bmi, bool isDark) {
    if (bmi < 18.5) return isDark ? Colors.orangeAccent : Colors.orange;
    if (bmi < 25) return isDark ? Colors.greenAccent : Colors.green;
    if (bmi < 30) return isDark ? Colors.orangeAccent : Colors.orange;
    return isDark ? Colors.redAccent : Colors.red;
  }
}