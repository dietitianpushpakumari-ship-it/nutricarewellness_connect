import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';

class DietPdfService {
  static Future<Uint8List> generateDietPdf(ClientDietPlanModel plan) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text("Diet Plan: ${plan.name}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),

              // Meal Table
              if (plan.days.isNotEmpty)
                pw.Table.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    <String>['Meal', 'Items'],
                    ...plan.days.first.meals.map((meal) => [
                      meal.mealName,
                      meal.items.map((i) => "${i.foodItemName} (${i.quantity} ${i.unit})").join(", ")
                    ])
                  ],
                ),

              pw.SizedBox(height: 20),
              pw.Text("Notes: ${plan.clinicalNotes}"),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}