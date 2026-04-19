import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Model Imports
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/flat_diet_plan_model.dart'; // For FlatDietPlanItem
import 'package:pure_shift/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:pure_shift/new/models/vitals_model.dart';

class DietPdfService {
  static Future<Uint8List> generateDietPdf({
    required FlatClientDietPlanModel plan, // 🚀 Uses Client-specific Flat Model
    required ClientModel client,
    required AdminProfileModel? dietitian,
    required VitalsModel? vitals,
    required List<String> guidelineTexts,
  }) async {
    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());

    final PdfColor primaryColor = PdfColor.fromInt(0xFF1A237E);
    final PdfColor lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
        ),
        header: (context) => _buildHeader(dietitian, primaryColor),
        footer: (context) => _buildFooter(context, dietitian),
        build: (context) => [
          _buildPatientHeader(client, vitals, primaryColor),
          pw.SizedBox(height: 10),
          if (vitals != null) _buildClinicalProfile(vitals, lightGrey),
          pw.SizedBox(height: 20),

          // 🎯 GOALS SECTION
          _buildGoalsSection(plan, primaryColor),
          pw.SizedBox(height: 20),

          pw.Text("Diet Routine", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 10),
          _buildMealTable(plan, primaryColor), // 🚀 Hyper-Flat Logic
          pw.SizedBox(height: 20),

          _buildGuidelinesSection(guidelineTexts, vitals?.clinicalNotes, primaryColor),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildMealTable(FlatClientDietPlanModel plan, PdfColor color) {
    if (plan.allItems.isEmpty) return pw.Text("No diet items assigned.");

    // 1. Pick a single day to display (usually the first day of the plan)
    final firstDayId = plan.allItems.first.dayId;
    final dayItems = plan.allItems.where((i) => i.dayId == firstDayId).toList();

    // 2. Identify Unique Meals and Sort by mealOrder
    final mealMap = <String, int>{};
    for (var item in dayItems) {
      mealMap[item.mealName] = item.mealOrder;
    }
    final sortedMealNames = mealMap.keys.toList()
      ..sort((a, b) => mealMap[a]!.compareTo(mealMap[b]!));

    final List<pw.TableRow> rows = [];

    // 3. Process each meal
    for (var mealName in sortedMealNames) {
      final itemsInMeal = dayItems.where((i) => i.mealName == mealName).toList();

      // Get Root Items (Primary items that aren't children of something else)
      final rootItems = itemsInMeal.where((i) => i.itemType == DietItemType.primary).toList();

      List<pw.Widget> mealContentWidgets = [];

      for (var root in rootItems) {
        // A. Primary Food Item
        mealContentWidgets.add(
            pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text("• ${root.foodItemName} (${root.quantity} ${root.unit})",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
            )
        );

        // B. Handle Bundle Children (e.g., items inside a Thali/Combo)
        final children = itemsInMeal.where((i) => i.parentId == root.id && i.itemType == DietItemType.bundleChild).toList();
        for (var child in children) {
          mealContentWidgets.add(
              pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12),
                  child: pw.Text("- ${child.foodItemName} (${child.quantity} ${child.unit})", style: const pw.TextStyle(fontSize: 9))
              )
          );
        }

        // C. Handle Alternatives (OR logic)
        final alternatives = itemsInMeal.where((i) => i.parentId == root.id && i.itemType == DietItemType.alternative).toList();
        for (var alt in alternatives) {
          mealContentWidgets.add(
              pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, top: 2),
                  child: pw.Text("OR: ${alt.foodItemName} (${alt.quantity} ${alt.unit})",
                      style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.blueGrey800))
              )
          );
        }
      }

      rows.add(pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(mealName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: mealContentWidgets)),
          ]
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {0: const pw.FixedColumnWidth(80), 1: const pw.FlexColumnWidth()},
      children: [
        pw.TableRow(
            decoration: pw.BoxDecoration(color: color),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Meal", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Recommended Menu", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
            ]
        ),
        ...rows,
      ],
    );
  }

  static pw.Widget _buildGoalsSection(FlatClientDietPlanModel plan, PdfColor color) {
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
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 0.5), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ]),
    );
  }

  // Support widgets (Patient Header, Footer, Clinical Profile)
  static pw.Widget _buildHeader(AdminProfileModel? dietitian, PdfColor color) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(dietitian?.companyName ?? "NutriCare Wellness", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text("Dietitian: ${dietitian?.firstName ?? ''} ${dietitian?.lastName ?? ''}", style: const pw.TextStyle(fontSize: 11)),
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
            _buildInfoColumn("Age/Sex", "${client.age ?? '-'} / ${client.gender}"),
            _buildInfoColumn("Weight", "${vitals?.weightKg ?? '-'} kg", color: color, isBold: true),
            _buildInfoColumn("BMI", vitals?.bmi.toStringAsFixed(1) ?? "-"),
          ]
      ),
    );
  }

  static pw.Widget _buildInfoColumn(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    ]);
  }

  static pw.Widget _buildClinicalProfile(VitalsModel vitals, PdfColor bg) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Clinical Assessment", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text("Medical History: ${vitals.medicalHistory.values.join(', ')}", style: const pw.TextStyle(fontSize: 9)),
            pw.Text("Complaints: ${vitals.clinicalComplaints?.values.join(', ') ?? 'None'}", style: const pw.TextStyle(fontSize: 9)),
          ]
      ),
    );
  }

  static pw.Widget _buildGuidelinesSection(List<String> guidelines, Map<String,String>? clinicalNotes, PdfColor color) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("General Instructions:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color, fontSize: 11)),
          pw.SizedBox(height: 4),
          ...guidelines.map((g) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text("• $g", style: const pw.TextStyle(fontSize: 9)),
          )),
        ]
    );
  }

  static pw.Widget _buildFooter(pw.Context context, AdminProfileModel? dietitian) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text("Plan: Generated by NutriCare Connect", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text("Page ${context.pageNumber} of ${context.pagesCount}", style: const pw.TextStyle(fontSize: 8)),
      ]),
    ]);
  }
}