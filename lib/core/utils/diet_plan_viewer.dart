import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/diet_pdf_service.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:printing/printing.dart';

class DietPlanViewerScreen extends ConsumerWidget {
  final ClientDietPlanModel plan;
  final ClientModel client;

  const DietPlanViewerScreen({
    super.key,
    required this.plan,
    required this.client,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch Dietitian Profile
    final dietitianAsync = ref.watch(dietitianProfileProvider);

    // 2. Fetch Latest Vitals (Contains the Guidelines & Meds linked to this plan context)
    final vitalsAsync = ref.watch(latestVitalsFutureProvider(client.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Diet Plan Document"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: dietitianAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error loading profile: $e")),
        data: (dietitianProfile) {

          return vitalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error loading vitals: $e")),
            data: (vitals) {

              // 🎯 PREPARE DATA FOR PDF
              // Since guidelines are now in VitalsModel as a Map<String, String>,
              // we convert them to a List<String> for the PDF Service.
              List<String> formattedGuidelines = [];

              if (vitals != null && vitals.clinicalGuidelines != null) {
                formattedGuidelines = vitals.clinicalGuidelines!.entries
                    .map((e) => "${e.key}: ${e.value}")
                    .toList();
              }

              // 🎯 GENERATE PDF
              return PdfPreview(
                build: (format) => DietPdfService.generateDietPdf(
                  plan: plan,
                  client: client,
                  dietitian: dietitianProfile, // Nullable handling inside Service
                  vitals: vitals, // Pass full vitals for Meds/Stats
                  guidelineTexts: formattedGuidelines, // 🎯 Fixed: Passed from Vitals
                ),
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                // Sanitize filename
                pdfFileName: "${client.name?.replaceAll(' ', '_') ?? 'Client'}_Diet_Plan.pdf",
              );
            },
          );
        },
      ),
    );
  }
}