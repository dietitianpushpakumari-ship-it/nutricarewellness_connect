import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';

import 'clinical_model.dart';
// 🎯 Ensure this import points to where PrescribedMedication is defined

class VitalsDetailScreen extends StatelessWidget {
  final VitalsModel record;

  const VitalsDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          // Ambient Background
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
                    color: Colors.indigo.withOpacity(0.1),
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
                _buildHeader(context),

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
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                            ),
                            child: Text(
                              DateFormat('EEEE, d MMMM yyyy • h:mm a').format(record.date),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION 1: BODY METRICS
                        _buildSectionHeader("Body Metrics", Icons.accessibility_new),
                        _buildDetailCard([
                          _buildRow("Weight", "${record.weightKg} kg", isHighlight: true),
                          _buildRow("Height", "${record.heightCm} cm"),
                          _buildRow("BMI", record.bmi.toStringAsFixed(1), color: _getBmiColor(record.bmi)),
                          _buildRow("Body Fat", "${record.bodyFatPercentage}%"),
                          if (record.waistCm != null) _buildRow("Waist", "${record.waistCm} cm"),
                          if (record.hipCm != null) _buildRow("Hip", "${record.hipCm} cm"),
                          _buildRow("Ideal Weight", "${record.idealBodyWeightKg} kg"),
                        ]),

                        // SECTION 2: HEART & LUNGS
                        _buildSectionHeader("Vitals & Heart", Icons.favorite),
                        _buildDetailCard([
                          _buildRow("Blood Pressure",
                              record.bloodPressureSystolic != null
                                  ? "${record.bloodPressureSystolic}/${record.bloodPressureDiastolic} mmHg"
                                  : "Not recorded",
                              color: Colors.red.shade700
                          ),
                          _buildRow("Heart Rate", "${record.heartRate ?? '-'} bpm"),
                          _buildRow("SpO2", "${record.spO2Percentage ?? '-'} %", color: Colors.teal),
                        ]),

                        // SECTION 3: LAB RESULTS
                        if (record.labResults.isNotEmpty) ...[
                          _buildSectionHeader("Lab Report Data", Icons.science),
                          _buildDetailCard(
                            record.labResults.entries.map((e) {
                              // Format keys (e.g., 'fbs' -> 'FBS')
                              String key = e.key.toUpperCase();
                              return _buildRow(key, e.value);
                            }).toList(),
                          ),
                        ],

                        // SECTION 4: CLINICAL PROFILE
                        _buildSectionHeader("Clinical Profile", Icons.medical_services),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTagGroup("Diagnosis", record.diagnosis, Colors.red),
                              const Divider(height: 24),
                              _buildTagGroup("Medical History", record.medicalHistory, Colors.blueGrey),
                              const Divider(height: 24),
                              _buildTagGroup("Complaints",
                                  record.complaints?.split(',') ?? [],
                                  Colors.orange
                              ),
                              if (record.foodAllergies != null && record.foodAllergies!.isNotEmpty) ...[
                                const Divider(height: 24),
                                _buildTagGroup("Allergies", record.foodAllergies!.split(','), Colors.pink),
                              ]
                            ],
                          ),
                        ),

                        // SECTION 5: MEDICATIONS
                        if (record.prescribedMedications.isNotEmpty || (record.existingMedication != null && record.existingMedication!.isNotEmpty)) ...[
                          _buildSectionHeader("Medications", Icons.medication),
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Structured Meds
                                ...record.prescribedMedications.map((m) {
                                  // 🎯 FIX: Safe Access using ?. and ??
                                  final name = m?.medicineName ?? "Unknown";
                                  final freq = m?.frequency ?? "-";
                                  final time = m?.timing ?? "-";

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text("$freq ($time)", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  );
                                }),
                                // Legacy/Text Meds
                                if (record.existingMedication != null && record.existingMedication!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(record.existingMedication!, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                                  )
                              ],
                            ),
                          ),
                        ],

                        // SECTION 6: LIFESTYLE
                        _buildSectionHeader("Lifestyle", Icons.self_improvement),
                        _buildDetailCard([
                          _buildRow("Food Habit", record.foodHabit ?? "Not set"),
                          _buildRow("Activity Level", record.activityType ?? "Not set"),
                          if (record.otherLifestyleHabits != null)
                            ...record.otherLifestyleHabits!.entries.map((e) => _buildRow(e.key, e.value)),
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
              const Text("Full Health Record", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _toggleMedReminder(BuildContext context, PrescribedMedication med) async {
    if (!med.isReminderEnabled) {
      // Enable: Pick Time
      final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now()
      );
      if (time != null) {
        final timeStr = "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
        _updateMedication(context, med, true, timeStr);
      }
    } else {
      // Disable
      _updateMedication(context, med, false, null);
    }
  }

  Future<void> _updateMedication(BuildContext context, PrescribedMedication oldMed, bool enabled, String? time) async {
    // 1. Update the specific med in the list
    final updatedMed = oldMed.copyWith(isReminderEnabled: enabled, reminderTime: time);

    final newList = record.prescribedMedications.map((m) {
      return m.medicineName == oldMed.medicineName ? updatedMed : m;
    }).toList();

    // 2. Create updated Vitals Record
    // Note: VitalsModel needs a copyWith to do this cleanly.
    // If VitalsModel doesn't have copyWith, we have to reconstruct it manually or add it.
    // Assuming copyWith exists or similar logic:
    /* final updatedRecord = record.copyWith(prescribedMedications: newList);
    await VitalsService().saveVitals(updatedRecord);

    // 3. Schedule Notification
    await LocalReminderService().scheduleMedicationReminders(newList);
    */

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder Updated")));
  }
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value, {bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
              fontSize: isHighlight ? 18 : 15,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGroup(String label, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Text(item.trim(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
            )).toList(),
          ),
      ],
    );
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}