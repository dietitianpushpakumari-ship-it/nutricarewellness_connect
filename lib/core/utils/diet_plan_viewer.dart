import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/diet_pdf_service.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:printing/printing.dart';

class DietPlanViewerScreen extends ConsumerWidget {
  final ClientDietPlanModel plan;
  final ClientModel client; // Passed from previous screen

  const DietPlanViewerScreen({
    super.key,
    required this.plan,
    required this.client,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch Dietitian Profile
    final dietitianAsync = ref.watch(dietitianProfileProvider);

    // 2. Fetch Guidelines (Convert IDs to Text)
    final guidelinesAsync = ref.watch(guidelineProvider(plan.guidelineIds));

    // 3. Fetch Latest Vitals
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

          return guidelinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
              data: (guidelines) {

                return vitalsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                    data: (vitals) {

                      // 🎯 GENERATE PDF with all data
                      return PdfPreview(
                        build: (format) => DietPdfService.generateDietPdf(
                          plan: plan,
                          client: client,
                          dietitian: dietitianProfile,
                          vitals: vitals,
                          guidelineTexts: guidelines.map((g) => g.enTitle).toList(),
                        ),
                        canChangeOrientation: false,
                        canDebug: false,
                        allowPrinting: true,
                        allowSharing: true,
                        pdfFileName: "${client.name?.replaceAll(' ', '_') ?? 'Client'}_Diet_Plan.pdf",
                      );
                    }
                );
              }
          );
        },
      ),
    );
  }
}