import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/programme_feature_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';
import 'package:nutricare_connect/services/client_service.dart';

import 'client_dashboard_main_screen.dart';

class TrackerScreen extends ConsumerWidget {
  final ClientModel client;

  const TrackerScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Live Activity Data (Water/Steps)
    final activityData = ref.watch(activityDataProvider);

    // 2. Latest Vitals Data (For Profile/Medical History)
    final latestVitalsAsync = ref.watch(latestVitalsFutureProvider(client.id));

    // 3. Client Assignments (For Package Status)
    // NOTE: This should be replaced with a proper provider fetching PackageAssignmentModel
    final assignedPackagesAsync = ref.watch(assignedPackageProvider(client.id));

    final weeklyLogsAsync = ref.watch(weeklyLogHistoryProvider(client.id));

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Activity Input Tools',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Divider(),

        // 🎯 1. Water Intake Input (Tap to add standard sizes)
        _buildWaterInputSection(context, ref, activityData),
        const SizedBox(height: 20),

        // 🎯 2. Steps Input (Simplified for quick logging)
        _buildStepInputSection(context, ref, activityData),
        const SizedBox(height: 20),
        // --- 1. CORE TRACKING TOOLS (Water/Steps/Calories) ---
        _buildCoreTrackingSection(context, ref, activityData),
        const SizedBox(height: 20),

        _buildWeeklyLogHistory(context, weeklyLogsAsync, client.id),
        const SizedBox(height: 20),

        // --- 2. CLIENT MEDICAL PROFILE OVERVIEW ---
        latestVitalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) =>
              Center(child: Text('Error loading medical data: $e')),
          data: (vitals) => _buildClientProfileOverview(context, vitals),
        ),
        const SizedBox(height: 20),

        // --- 3. PACKAGE & PAYMENT STATUS ---
        assignedPackagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) =>
              Center(child: Text('Error loading package data: $e')),
          data: (assignedPackage) => _buildPackagePaymentStatus(
            context,
            assignedPackage,
          ), // Reusing meetings data structure as placeholder
        ),
        const SizedBox(height: 20),

        // --- 4. ADD-ON HEALTH FEATURES ---
        _buildAddOnFeatures(context),
      ],
    );
  }

  Widget _buildWaterInputSection(
      BuildContext context,
      WidgetRef ref,
      ActivityData activityData,
      ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Water Intake',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.blue.shade700),
            ),
            Text(
              'Current: ${activityData.waterL.toStringAsFixed(2)} L / ${activityData.goalWaterLiters.toStringAsFixed(1)} L',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const Divider(),

            // Input Buttons (Standard Sizes)
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: standardSizes.map((size) {
                return OutlinedButton.icon(
                  onPressed: () {
                    final newVolume = (activityData.waterL + size.volumeL)
                        .clamp(0.0, 10.0)
                        .toDouble();
                    ref.read(activityDataProvider.notifier).state = activityData
                        .copyWith(waterL: newVolume);
                  },
                  icon: Icon(size.icon, size: 18),
                  label: Text(size.label),
                );
              }).toList(),
            ),

            TextButton(
              onPressed: () {
                ref.read(activityDataProvider.notifier).state = activityData
                    .copyWith(waterL: 0.0);
              },
              child: const Text('Reset Today\'s Water'),
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Step Count Input Section ---
  Widget _buildStepInputSection(
      BuildContext context,
      WidgetRef ref,
      ActivityData activityData,
      ) {
    final stepsController = TextEditingController(
      text: activityData.steps.toString(),
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Steps Count',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.orange.shade700),
            ),
            const Divider(),

            TextFormField(
              controller: stepsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter Today\'s Steps',
                hintText: '${activityData.steps} (Current)',
                suffixText: 'Steps',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                final newSteps =
                    int.tryParse(stepsController.text) ?? activityData.steps;
                ref.read(activityDataProvider.notifier).state = activityData
                    .copyWith(steps: newSteps);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Steps updated!')));
              },
              icon: const Icon(Icons.update),
              label: const Text('Update Steps'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyLogHistory(
      BuildContext context,
      AsyncValue<Map<DateTime, List<ClientLogModel>>> logsAsync,
      String clientId,
      ) {
    return Card(
      elevation: 4,
      child: ExpansionTile(
        leading: const Icon(Icons.history, color: Colors.blueGrey),
        title: const Text(
          'Last 7 Days Log History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: true,

        children: [
          logsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Failed to load logs: $e'),
            ),
            data: (groupedLogs) {
              final sortedDays = groupedLogs.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              if (sortedDays.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No log entries in the last 7 days.'),
                );
              }

              return Column(
                children: sortedDays.map((date) {
                  final logs = groupedLogs[date]!;
                  final mealsLogged = logs
                      .where((l) => l.mealName != 'DAILY_WELLNESS_CHECK')
                      .length;
                  final wellnessComplete = logs.any(
                        (l) => l.mealName == 'DAILY_WELLNESS_CHECK',
                  );
                  final colorScheme = Theme.of(context).colorScheme;

                  return ListTile(
                    onTap: () {
                      // 🎯 LAUNCH DETAILED MODAL on tap
                      _showDailyLogDetailModal(context, logs, date);
                    },
                    leading: Icon(
                      wellnessComplete ? Icons.star : Icons.chevron_right,
                      color: wellnessComplete
                          ? colorScheme.primary
                          : Colors.grey,
                    ),
                    title: Text(DateFormat('EEEE, MMM d').format(date)),
                    subtitle: Text(
                      '${mealsLogged} Meals Logged | ${wellnessComplete ? 'Wellness Check COMPLETE' : 'Wellness Check MISSING'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: mealsLogged > 0 ? Colors.black87 : Colors.red,
                      ),
                    ),
                    trailing: const Icon(Icons.search),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          // Link to Full History
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('View Full History Archive'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to the old ClientLogHistoryScreen if needed
            },
          ),
        ],
      ),
    );
  }

  // 🎯 NEW: DETAILED VIEW MODAL
  void _showDailyLogDetailModal(
      BuildContext context,
      List<ClientLogModel> logs,
      DateTime date,
      ) {
    // 1. Separate logs: meals vs. wellness check
    final mealLogs = logs
        .where((l) => l.mealName != 'DAILY_WELLNESS_CHECK')
        .toList();
    final wellnessLog = logs.firstWhereOrNull(
          (l) => l.mealName == 'DAILY_WELLNESS_CHECK',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return _DailyLogDetailContent(
              controller: controller,
              date: date,
              mealLogs: mealLogs,
              wellnessLog: wellnessLog,
            );
          },
        );
      },
    );
  }

  // --- Core Tracking Tools (Reused from Home Screen) ---
  Widget _buildCoreTrackingSection(
      BuildContext context,
      WidgetRef ref,
      ActivityData activityData,
      ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Key Metrics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),

            // Water Consumption
            ListTile(
              leading: Icon(Icons.opacity, color: Colors.blue.shade600),
              title: const Text('Water Consumption'),
              subtitle: Text(
                '${activityData.waterL.toStringAsFixed(1)} L / 3.0 L Goal',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () {
                  final newWater = (activityData.waterL + 0.5)
                      .clamp(0.0, 3.0)
                      .toDouble();
                  ref.read(activityDataProvider.notifier).state = activityData
                      .copyWith(waterL: newWater);
                },
              ),
            ),

            // Steps & Calories
            ListTile(
              leading: const Icon(Icons.directions_run, color: Colors.orange),
              title: const Text('Steps & Calorie Count'),
              subtitle: Text(
                '${activityData.steps} Steps | ${activityData.calories} KCal Logged',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log activity manually.')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. NEW: CLIENT PROFILE OVERVIEW ---
  Widget _buildClientProfileOverview(
      BuildContext context,
      VitalsModel? vitals,
      ) {
    final hasMedicalData = vitals != null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 4,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.medical_services, color: primaryColor),
        title: const Text(
          'Medical Profile Overview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          hasMedicalData
              ? 'Last Vitals: ${DateFormat.yMMMd().format(vitals.date)}'
              : 'No Vitals History',
        ),

        children: [
          if (hasMedicalData)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileRow(
                    'Food Habit',
                    vitals.foodHabit ?? 'N/A',
                    Icons.dinner_dining,
                    Colors.green,
                  ),
                  _buildProfileRow(
                    'Activity Level',
                    vitals.activityType ?? 'N/A',
                    Icons.fitness_center,
                    Colors.orange,
                  ),
                  _buildProfileRow(
                    'Primary Complaint',
                    vitals.complaints ?? 'N/A',
                    Icons.sick,
                    Colors.red,
                  ),
                  _buildProfileRow(
                    'Med. History',
                    vitals.medicalHistoryDurations ?? 'None',
                    Icons.history_edu,
                    Colors.blueGrey,
                  ),

                  const Divider(height: 20),
                  Text(
                    'Lab/Vitals Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  _buildProfileRow(
                    'Weight',
                    '${vitals.weightKg.toStringAsFixed(1)} kg',
                    Icons.monitor_weight,
                    primaryColor,
                  ),
                  _buildProfileRow(
                    'BMI',
                    vitals.bmi.toStringAsFixed(1),
                    Icons.straighten,
                    primaryColor,
                  ),
                ],
              ),
            ),

          // Link to Full Reports
          ListTile(
            leading: const Icon(Icons.document_scanner),
            title: const Text('View Full Lab Reports & Vitals History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Assuming VitalsHistoryPage handles the display of all records
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LabReportListScreen(client: client),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper for displaying profile rows
  Widget _buildProfileRow(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  // --- 3. NEW: PACKAGE & PAYMENT STATUS ---
  // --- 3. NEW: PACKAGE & PAYMENT STATUS (FIXED IMPLEMENTATION) ---
  // NOTE: This method assumes the surrounding helper methods like _buildProfileRow and _launchUrl are defined.

  // --- 3. NEW: PACKAGE & PAYMENT STATUS (FINAL DYNAMIC IMPLEMENTATION) ---
  Widget _buildPackagePaymentStatus(
      BuildContext context,
      List<PackageAssignmentModel> assignments,
      ) {
    // 1. Identify the primary active assignment
    final activeAssignment = assignments.firstWhereOrNull((a) => a.isActive);

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    );
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    final hasActivePackage = activeAssignment != null;
    final packageId = activeAssignment?.packageId;

    // --- Early Exit for No Package ---
    if (!hasActivePackage || packageId == null) {
      return Card(
        elevation: 4,
        child: ExpansionTile(
          leading: Icon(Icons.card_membership, color: colorScheme.secondary),
          title: const Text(
            'Package & Payment Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('No Active Package'),
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No active packages. Schedule a consultation to book your plan.',
              ),
            ),
          ],
        ),
      );
    }

    // Calculate financial details based on the assignment model
    final double netBooked = activeAssignment!.bookedAmount;
    final double mockCollected =
        activeAssignment.bookedAmount * 0.7; // MOCK: Assume 70% collected
    final double pending = netBooked - mockCollected;

    return FutureBuilder<PackageModel>(
      // 🎯 STEP A: Fetch Package Details (Async)
      future: PackageService().getAllActivePackagesById(packageId),
      builder: (context, snapshot) {
        final PackageModel? packageDetails = snapshot.data;
        final bool isDataLoaded =
            snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData;

        final List<String> featureIds = packageDetails?.programFeatureIds ?? [];

        return Card(
          elevation: 4,
          child: ExpansionTile(
            leading: Icon(Icons.card_membership, color: colorScheme.secondary),
            title: const Text(
              'Package & Payment Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(activeAssignment.packageName),

            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: LinearProgressIndicator(),
                ),

              if (isDataLoaded)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Plan: ${packageDetails!.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const Divider(),

                      // --- Financial Details (Unchanged) ---
                      _buildProfileRow(
                        'Start Date',
                        DateFormat.yMMMd().format(
                          activeAssignment.purchaseDate,
                        ),
                        Icons.event,
                        Colors.blueGrey,
                      ),
                      _buildProfileRow(
                        'Expiry Date',
                        DateFormat.yMMMd().format(activeAssignment.expiryDate),
                        Icons.access_time,
                        Colors.red,
                      ),
                      _buildProfileRow(
                        'Net Booked Amount',
                        currencyFormatter.format(netBooked),
                        Icons.price_change,
                        Colors.black87,
                      ),
                      _buildProfileRow(
                        'Total Collected',
                        currencyFormatter.format(mockCollected),
                        Icons.receipt_long,
                        Colors.green.shade700,
                      ),
                      _buildProfileRow(
                        'Due Balance',
                        currencyFormatter.format(pending > 0 ? pending : 0.0),
                        Icons.money_off,
                        pending > 0
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),

                      const SizedBox(height: 15),

                      // 🎯 STEP B: Nested FutureBuilder to fetch Program Feature Names
                      Text(
                        'Included Features:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      FutureBuilder<List<ProgramFeatureModel>>(
                        future: PackageService().getFeaturesByIds(featureIds),
                        builder: (context, featureSnapshot) {
                          if (featureSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          if (featureSnapshot.hasError) {
                            return const Text(
                              'Failed to load features.',
                              style: TextStyle(color: Colors.red),
                            );
                          }

                          final features = featureSnapshot.data ?? [];

                          return Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: features
                                .map(
                                  (feature) => Chip(
                                label: Text(
                                  feature.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: colorScheme.secondary
                                    .withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: colorScheme.secondary,
                                ),
                              ),
                            )
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 10),
                      ListTile(
                        title: const Text('View Payment Ledger & Features'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Navigating to Payment Ledger...'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              // Fallback for general error state
              if (snapshot.hasError && !isDataLoaded)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Failed to load package details.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- 4. ADD-ON HEALTH FEATURES (Reused from previous step) ---
  Widget _buildAddOnFeatures(BuildContext context) {
    return Column(
      children: [
        _buildHealthFeatureTile(
          context,
          'Breathing Exercises',
          Icons.self_improvement,
          Colors.purple,
        ),
        _buildHealthFeatureTile(
          context,
          'Medication Reminders',
          Icons.medication,
          Colors.red,
        ),
        _buildHealthFeatureTile(
          context,
          'Scan & Find Age',
          Icons.camera_alt,
          Colors.pink,
        ),
      ],
    );
  }

  Widget _buildHealthFeatureTile(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title feature coming soon!'))),
      ),
    );
  }
}

class _DailyLogDetailContent extends StatelessWidget {
  final ScrollController controller;
  final DateTime date;
  final List<ClientLogModel> mealLogs;
  final ClientLogModel? wellnessLog;

  const _DailyLogDetailContent({
    required this.controller,
    required this.date,
    required this.mealLogs,
    this.wellnessLog,
  });

  Widget _buildWellnessMetric(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${DateFormat('EEEE').format(date)} Log Detail'),
        backgroundColor: colorScheme.secondary,
      ),
      body: SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- A. WELLNESS METRICS (The single daily entry) ---
            Text(
              'Daily Wellness Check',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
            ),
            const Divider(),

            if (wellnessLog != null)
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _buildWellnessMetric(
                        'Sleep Quality',
                        (wellnessLog!.sleepQualityRating ?? 'N/A').toString(),
                        Icons.nights_stay,
                        Colors.deepPurple,
                      ),
                      _buildWellnessMetric(
                        'Hydration',
                        '${wellnessLog!.hydrationLiters ?? 'N/A'} L',
                        Icons.opacity,
                        Colors.blue,
                      ),
                      _buildWellnessMetric(
                        'Energy Level',
                        (wellnessLog!.energyLevelRating ?? 'N/A').toString(),
                        Icons.bolt,
                        Colors.orange,
                      ),
                      _buildWellnessMetric(
                        'Mood',
                        (wellnessLog!.moodLevelRating ?? 'N/A').toString(),
                        Icons.sentiment_satisfied_alt,
                        Colors.green,
                      ),
                      if (wellnessLog!.notesAndFeelings?.isNotEmpty == true)
                        ListTile(
                          title: const Text('Notes'),
                          subtitle: Text(wellnessLog!.notesAndFeelings!),
                          leading: const Icon(Icons.edit_note),
                        ),
                    ],
                  ),
                ),
              )
            else
              const Center(
                child: Text('Wellness check was not completed on this day.'),
              ),

            const SizedBox(height: 30),

            // --- B. MEAL LOGS (The multiple meal entries) ---
            Text(
              'Meal Logs',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
            ),
            const Divider(),

            if (mealLogs.isEmpty)
              const Center(child: Text('No meals were logged on this day.'))
            else
              ...mealLogs.map((log) {
                final isDeviation = log.logStatus == LogStatus.deviated;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Icon(
                      isDeviation ? Icons.warning : Icons.restaurant,
                      color: isDeviation ? Colors.red : Colors.green,
                    ),
                    title: Text(
                      log.mealName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(log.logStatus.name.toUpperCase()),
                    children: [
                      _buildMealLogDetailRow(
                        'Food Eaten',
                        log.actualFoodEaten.join(', '),
                      ),
                      _buildMealLogDetailRow('Status', log.logStatus.name),
                      if (isDeviation)
                        _buildMealLogDetailRow(
                          'Deviation Time',
                          DateFormat.jm().format(log.deviationTime!),
                        ),
                      if (log.clientQuery?.isNotEmpty == true)
                        _buildMealLogDetailRow(
                          'Client Query',
                          log.clientQuery!,
                        ),
                      if (log.adminReplied)
                        _buildMealLogDetailRow(
                          'Dietitian Reply',
                          log.adminComment!,
                          color: Colors.green,
                        ),

                      // Photo Preview (Need to implement image loading from URL)
                      if (log.mealPhotoUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Photos Attached: ${log.mealPhotoUrls.length} (Tap to view)',
                          ),
                        ),

                      // Button to launch Edit Dialog (Optional)
                      TextButton(
                        onPressed: () {
                          // You can launch the edit dialog here using the log model
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Tapped to edit log: ${log.mealName}',
                              ),
                            ),
                          );
                        },
                        child: const Text('Edit Log'),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealLogDetailRow(
      String label,
      String value, {
        Color color = Colors.black87,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
