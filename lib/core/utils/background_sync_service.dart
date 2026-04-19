import 'package:workmanager/workmanager.dart';

void scheduleClinicalSync(String patientId) {
  Workmanager().registerPeriodicTask(
    "pure_shift_step_sync_1", // A unique name for this task
    "clinicalDataSync",
    frequency: const Duration(hours: 6), // Runs 4 times a day
    constraints: Constraints(
      networkType: NetworkType.connected, // Only run if they have internet
      requiresBatteryNotLow: true,        // Be kind to the SM-E066B battery
    ),
    inputData: {
      'patientId': patientId, // Pass the ID to the background isolate
    },
    // Optional: existingWorkPolicy: ExistingWorkPolicy.replace
  );
}