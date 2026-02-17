import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';

class DietPdfService {

  static Future<Uint8List> generateDietPdf({
    required ClientDietPlanModel plan,
    required ClientModel client,
    required AdminProfileModel? dietitian,
    required VitalsModel? vitals,
    required List<String> guidelineTexts,
  }) async {
    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());

    // Colors
    final PdfColor primaryColor = PdfColor.fromInt(0xFF1A237E);
    final PdfColor accentColor = PdfColor.fromInt(0xFFFFA000);
    final PdfColor lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30)
        ),
        header: (context) => _buildHeader(dietitian, primaryColor),
        footer: (context) => _buildFooter(context, dietitian),
        build: (context) => [
          // 1. PATIENT & CLINICAL HEADER
          _buildPatientHeader(client, vitals, primaryColor),
          pw.SizedBox(height: 10),

          if (vitals != null) _buildClinicalProfile(vitals, lightGrey),
          pw.SizedBox(height: 20),

          // 2. DAILY GOALS
          _buildGoalsSection(plan, primaryColor),
          pw.SizedBox(height: 20),

          // 3. MEAL PLAN TABLE
          pw.Text("Diet Routine", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 10),
          _buildMealTable(plan, primaryColor),
          pw.SizedBox(height: 20),

          // 4. MEDICATIONS & SUPPLEMENTS
          if (vitals?.medications.isNotEmpty ?? false)
            _buildMedsSection(vitals!),
          pw.SizedBox(height: 20),

          // 5. GUIDELINES & NOTES
          _buildGuidelinesSection(guidelineTexts, vitals?.clinicalNotes, primaryColor),
          pw.SizedBox(height: 20),
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
              pw.Text(dietitian?.companyName ?? "NutriCare Wellness", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text("Dietitian: ${dietitian?.firstName ?? ''} ${dietitian?.lastName ?? ''}", style: const pw.TextStyle(fontSize: 11)),
              pw.Text(dietitian?.designation ?? "Clinical Nutritionist", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("Date: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10)),
              pw.Text("Phone: ${dietitian?.mobile ?? ''}", style: const pw.TextStyle(fontSize: 10)),
            ]),
          ],
        ),
        pw.Divider(color: color, thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildPatientHeader(ClientModel client, VitalsModel? vitals, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoColumn("Patient Name", client.name ?? "N/A", isBold: true),
            _buildInfoColumn("ID", client.patientId ?? client.id.substring(0,6)), // Fallback ID
            _buildInfoColumn("Age/Sex", "${client.age ?? '-'} / ${client.gender}"),
            _buildInfoColumn("Weight", "${vitals?.weightKg ?? '-'} kg", color: color, isBold: true),
            _buildInfoColumn("Height", "${vitals?.heightCm ?? '-'} cm"),
            _buildInfoColumn("BMI", vitals?.bmi.toStringAsFixed(1) ?? "-"),
          ]
      ),
    );
  }

  static pw.Widget _buildClinicalProfile(VitalsModel vitals, PdfColor bg) {
    // 🎯 FIX: Extract values from Maps safely
    final diagnoses = vitals.nutritionDiagnoses?.values.join(", ") ?? "";
    final complaints = vitals.clinicalComplaints?.values.join(", ") ?? "";
    final habits = vitals.otherLifestyleHabits ?? {};
    final allergies = vitals.foodAllergies.join(", ");

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
            if (vitals.medicalHistory.isNotEmpty) _buildDetailRow("Medical History:", vitals.medicalHistory.values.join(", ")),
            _buildDetailRow("Complaints:", complaints.isNotEmpty ? complaints : "None"),
            _buildDetailRow("Allergies:", allergies.isNotEmpty ? allergies : "None"),
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
          _buildGoalBadge("Water Goal", "${plan.dailyWaterGoal} L", color),
          _buildGoalBadge("Daily Steps", "${plan.dailyStepGoal}", color),
          _buildGoalBadge("Sleep Goal", "${plan.dailySleepGoal} hrs", color),
        ]
    );
  }

  static pw.Widget _buildGoalBadge(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ]),
    );
  }

  // 🎯 FIXED: MEAL TABLE LOGIC
  static pw.Widget _buildMealTable(ClientDietPlanModel plan, PdfColor color) {
    if (plan.days.isEmpty) return pw.Text("No meals assigned.");

    // We take the first day as the template for the PDF table
    final meals = plan.days.first.meals;

    // Sort meals by order to ensure Breakfast comes before Lunch
    meals.sort((a,b) => a.order.compareTo(b.order));

    final data = meals.map((meal) {
      // Build the rich text content for the meal items
      final itemsText = meal.items.map((i) {
        String text = "• ${i.foodItemName} - ${i.quantity} ${i.unit}";

        // Alternatives
        if (i.alternatives.isNotEmpty) {
          for (var alt in i.alternatives) {
            text += "\n   OR ${alt.foodItemName} (${alt.quantity} ${alt.unit})";
          }
        }
        // Notes
        if (i.notes.isNotEmpty) text += "\n   Note: ${i.notes}";

        return text;
      }).join("\n\n");

      return [meal.mealName, itemsText];
    }).toList();

    return pw.Table.fromTextArray(
      headers: ['Meal', 'Menu / Options'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: pw.BoxDecoration(color: color),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.all(8),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        1: const pw.FlexColumnWidth()
      },
    );
  }

  // 🎯 FIXED: GUIDELINES & NOTES FROM VITALS
  static pw.Widget _buildGuidelinesSection(List<String> guidelines, Map<String,String>? clinicalNotes, PdfColor color) {

    // Convert clinical notes map to a single string if needed, or display as list
    List<String> notesList = clinicalNotes?.values.toList() ?? [];

    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: color, width: 0.5),
            borderRadius: pw.BorderRadius.circular(8)
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Guidelines & Recommendations", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: color)),
              pw.SizedBox(height: 6),

              if (guidelines.isEmpty && notesList.isEmpty)
                pw.Text("No specific guidelines assigned.", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),

              ...guidelines.map((g) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("• ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)),
                        pw.Expanded(child: pw.Text(g, style: const pw.TextStyle(fontSize: 9))),
                      ]
                  )
              )),

              if (notesList.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text("Clinical Notes:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ...notesList.map((note) => pw.Text("• $note", style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic))),
              ]
            ]
        )
    );
  }

  // 🎯 FIXED: MEDICATION SECTION
  static pw.Widget _buildMedsSection(VitalsModel vitals) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("Medications", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 4),

          pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header
                pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Medicine", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Dose/Freq", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Instruction", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    ]
                ),
                // Data
                ...vitals.medications.map((m) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(m.name, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("${m.dosage} - ${m.frequency}", style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(m.instruction, style: const pw.TextStyle(fontSize: 8))),
                    ]
                )).toList()
              ]
          )
        ]
    );
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
        pw.Text("Generated by NutriCare Connect", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text("Page ${context.pageNumber} of ${context.pagesCount}", style: const pw.TextStyle(fontSize: 8)),
      ]),
    ]);
  }
}