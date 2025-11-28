import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';

class DietPdfService {

  static Future<Uint8List> generateDietPdf({
    required ClientDietPlanModel plan,
    required ClientModel client,
    required AdminProfileModel? dietitian,
    required VitalsModel? vitals,
    required List<String> guidelineTexts, // 🎯 Make sure this list is NOT empty in the caller
  }) async {
    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());

    // Colors
    final PdfColor primaryColor = PdfColor.fromInt(0xFF1A237E);
    final PdfColor accentColor = PdfColor.fromInt(0xFFFFA000);
    final PdfColor lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(theme: theme, pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(30)),
        header: (context) => _buildHeader(dietitian, primaryColor),
        footer: (context) => _buildFooter(context, dietitian),
        build: (context) => [
          // 1. PATIENT & CLINICAL
          _buildPatientHeader(client, vitals, primaryColor),
          pw.SizedBox(height: 10),
          if (vitals != null) _buildClinicalProfile(vitals, plan, lightGrey),
          pw.SizedBox(height: 20),

          // 2. DAILY GOALS
          _buildGoalsSection(plan, accentColor),
          pw.SizedBox(height: 20),

          // 3. MEAL PLAN TABLE
          pw.Text("Diet Routine", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 10),
          _buildMealTable(plan, primaryColor),
          pw.SizedBox(height: 20),

          // 4. SUPPLEMENTS
          if (plan.suplimentIds.isNotEmpty || (vitals?.existingMedication?.isNotEmpty ?? false))
            _buildMedsSection(plan, vitals),
          pw.SizedBox(height: 20),

          // 5. GUIDELINES
          _buildGuidelinesSection(guidelineTexts, plan.clinicalNotes, primaryColor),
          pw.SizedBox(height: 20),

          // 6. FOLLOW UP
          if (plan.followUpDays != null && plan.followUpDays! > 0)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: primaryColor), borderRadius: pw.BorderRadius.circular(12)),
                  child: pw.Text("Follow Up: ${plan.followUpDays} Days", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor))
              ),
            ),
        ],
      ),
    );
    return pdf.save();
  }

  // --- WIDGETS ---

  static pw.Widget _buildHeader(AdminProfileModel? dietitian, PdfColor color) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(dietitian?.companyName ?? "NutriCare Wellness", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text("${dietitian?.firstName} ${dietitian?.lastName}", style: const pw.TextStyle(fontSize: 12)),
              pw.Text(dietitian?.designation ?? "Clinical Nutritionist", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("Date: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10)),
              pw.Text("Phone: ${dietitian?.mobile ?? ''}", style: const pw.TextStyle(fontSize: 10)),
            ]),
          ],
        ),
        pw.Divider(color: color, thickness: 1.5),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildPatientHeader(ClientModel client, VitalsModel? vitals, PdfColor color) {
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoColumn("Patient", client.name ?? "N/A", isBold: true),
          _buildInfoColumn("ID", client.patientId),
          _buildInfoColumn("Age/Sex", "${client.age ?? '-'} / ${client.gender}"),
          _buildInfoColumn("Weight", "${vitals?.weightKg ?? '-'} kg", color: color, isBold: true),
          _buildInfoColumn("Height", "${vitals?.heightCm ?? '-'} cm"),
          _buildInfoColumn("BMI", vitals?.bmi.toStringAsFixed(1) ?? "-"),
        ]
    );
  }

  static pw.Widget _buildClinicalProfile(VitalsModel vitals, ClientDietPlanModel plan, PdfColor bg) {
    // Combine Plan Diagnosis + Vitals Diagnosis
    final diagnoses = {...plan.diagnosisIds, ...vitals.diagnosis}.join(", ");
    final habits = vitals.otherLifestyleHabits ?? {};

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Clinical & Lifestyle Profile", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 5),

            if (diagnoses.isNotEmpty) _buildDetailRow("Diagnosis:", diagnoses),
            if (vitals.medicalHistory.isNotEmpty) _buildDetailRow("Medical History:", vitals.medicalHistory.join(", ")),
            _buildDetailRow("Complaints:", vitals.complaints ?? "None"),
            _buildDetailRow("Allergies:", vitals.foodAllergies ?? "None"),
            _buildDetailRow("Food Habit:", vitals.foodHabit ?? "-"),

            if (habits.isNotEmpty)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text("Habits: ${habits.entries.map((e) => "${e.key}: ${e.value}").join(' | ')}", style: const pw.TextStyle(fontSize: 9))
              ),
          ]
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 80, child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800))),
              pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            ]
        )
    );
  }

  static pw.Widget _buildGoalsSection(ClientDietPlanModel plan, PdfColor color) {
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _buildGoalBadge("Water", "${plan.dailyWaterGoal} L", color),
          _buildGoalBadge("Steps", "${plan.dailyStepGoal}", color),
          _buildGoalBadge("Sleep", "${plan.dailySleepGoal} hrs", color),
        ]
    );
  }

  static pw.Widget _buildGoalBadge(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ]),
    );
  }

  // 🎯 FIXED: MEAL TABLE (Showing Alternatives)
  static pw.Widget _buildMealTable(ClientDietPlanModel plan, PdfColor color) {
    if (plan.days.isEmpty) return pw.Text("No meals assigned.");

    // Use 'Spanning' strings for rich text feel
    final data = plan.days.first.meals.map((meal) {
      final items = meal.items.map((i) {
        // Primary Item
        String text = "• ${i.foodItemName} (${i.quantity} ${i.unit})";

        // 🎯 ALTERNATIVES (Explicitly Added)
        if (i.alternatives.isNotEmpty) {
          for (var alt in i.alternatives) {
            text += "\n   OR ${alt.foodItemName} (${alt.quantity} ${alt.unit})";
          }
        }
        if (i.notes.isNotEmpty) text += "\n   Note: ${i.notes}";

        return text;
      }).join("\n\n");

      return [meal.mealName, items];
    }).toList();

    return pw.Table.fromTextArray(
      headers: ['Meal Time', 'Menu Options'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: pw.BoxDecoration(color: color),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.all(8),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {0: const pw.FixedColumnWidth(90), 1: const pw.FlexColumnWidth()},
    );
  }

  // 🎯 FIXED: GUIDELINES (Ensuring visibility)
  static pw.Widget _buildGuidelinesSection(List<String> guidelines, String notes, PdfColor color) {
    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 0.5), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("General Guidelines", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: color)),
              pw.SizedBox(height: 6),
              if (guidelines.isEmpty)
                pw.Text("No specific guidelines assigned.", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),

              ...guidelines.map((g) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("• ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)),
                        pw.Expanded(child: pw.Text(g, style: const pw.TextStyle(fontSize: 10))),
                      ]
                  )
              )),

              if (notes.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text("Special Note: $notes", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
              ]
            ]
        )
    );
  }

  static pw.Widget _buildMedsSection(ClientDietPlanModel plan, VitalsModel? vitals) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text("Medication & Supplements", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      pw.SizedBox(height: 4),
      if (plan.suplimentIds.isNotEmpty)
        pw.Text("Supplements: ${plan.suplimentIds.join(', ')}", style: const pw.TextStyle(fontSize: 10)),
      if (vitals?.existingMedication?.isNotEmpty ?? false)
        pw.Text("Current Meds: ${vitals!.existingMedication}", style: const pw.TextStyle(fontSize: 10)),
    ]);
  }

  static pw.Widget _buildInfoColumn(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    ]);
  }

  static pw.Widget _buildFooter(pw.Context context, AdminProfileModel? dietitian) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text("NutriCare Wellness - Personalized Care Plan", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text("Page ${context.pageNumber}/${context.pagesCount}", style: const pw.TextStyle(fontSize: 8)),
      ]),
    ]);
  }
}