import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/core/lab_vitals_data.dart'; // 🎯 Using your lab data file

class LogVitalsScreen extends ConsumerStatefulWidget {
  final String clientId;
  final VitalsModel? baseVitals; // The most recent vitals record

  const LogVitalsScreen({
    super.key,
    required this.clientId,
    this.baseVitals,
  });

  @override
  ConsumerState<LogVitalsScreen> createState() => _LogVitalsScreenState();
}

class _LogVitalsScreenState extends ConsumerState<LogVitalsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // "At-Home" Vitals
  final _weightController = TextEditingController();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _heartRateController = TextEditingController();

  // "Lab Results" Vitals - One controller for every possible lab test
  late Map<String, TextEditingController> _labControllers;

  // State to track which "question" groups are expanded
  late Map<String, bool> _groupExpandedState;

  @override
  void initState() {
    super.initState();

    // Initialize controllers for all lab tests
    _labControllers = {
      for (var key in LabVitalsData.allLabTests.keys)
        key: TextEditingController(),
    };

    // Initialize all lab groups to be collapsed
    _groupExpandedState = {
      for (var groupName in LabVitalsData.labTestGroups.keys)
        groupName: false,
    };

    // Pre-fill fields from the *most recent* vitals record
    if (widget.baseVitals != null) {
      final vitals = widget.baseVitals!;
      // Pre-fill at-home vitals
      _weightController.text = vitals.weightKg > 0 ? vitals.weightKg.toString() : '';
      _bpSystolicController.text = vitals.bloodPressureSystolic?.toString() ?? '';
      _bpDiastolicController.text = vitals.bloodPressureDiastolic?.toString() ?? '';
      _heartRateController.text = vitals.heartRate?.toString() ?? '';

      // Pre-fill lab results
      vitals.labResults.forEach((key, value) {
        if (_labControllers.containsKey(key)) {
          _labControllers[key]!.text = value;
        }
      });
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    for (var controller in _labControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; });

    try {
      final base = widget.baseVitals;

      // 1. Create a new map of lab results, preserving old ones
      final Map<String, String> newLabResults = Map.from(base?.labResults ?? {});

      // 2. Update map with values from *all* controllers
      _labControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          newLabResults[key] = controller.text.trim();
        }
      });

      // 3. Parse new "at-home" values
      final newWeight = double.tryParse(_weightController.text);
      final newSystolic = int.tryParse(_bpSystolicController.text);
      final newDiastolic = int.tryParse(_bpDiastolicController.text);
      final newHeartRate = int.tryParse(_heartRateController.text);

      // 4. Create a *new* VitalsModel
      // This creates a new historical record
      final newVitalsRecord = VitalsModel(
        id: '', // Set ID to empty to create a NEW record
        clientId: widget.clientId,
        date: DateTime.now(), // Set to today
        isFirstConsultation: false,

        // Overwrite with new data IF provided, otherwise use base data
        weightKg: newWeight ?? base?.weightKg ?? 0,
        bloodPressureSystolic: newSystolic ?? base?.bloodPressureSystolic,
        bloodPressureDiastolic: newDiastolic ?? base?.bloodPressureDiastolic,
        heartRate: newHeartRate ?? base?.heartRate,

        // Overwrite lab results
        labResults: newLabResults,

        // Copy all other non-loggable fields from base
        heightCm: base?.heightCm ?? 0,
        bmi: base?.bmi ?? 0,
        idealBodyWeightKg: base?.idealBodyWeightKg ?? 0,
        bodyFatPercentage: base?.bodyFatPercentage ?? 0,
        measurements: base?.measurements ?? {},
        notes: base?.notes,
        labReportUrls: base?.labReportUrls ?? [],
        assignedDietPlanIds: base?.assignedDietPlanIds ?? [],
        foodHabit: base?.foodHabit,
        activityType: base?.activityType,
        complaints: base?.complaints,
        existingMedication: base?.existingMedication,
        foodAllergies: base?.foodAllergies,
        restrictedDiet: base?.restrictedDiet,
        medicalHistoryDurations: base?.medicalHistoryDurations,
        otherLifestyleHabits: base?.otherLifestyleHabits,
      );

      // 5. Save the new record
      final vitalsService = ref.read(vitalsServiceProvider);
      await vitalsService.addVitals(newVitalsRecord);

      // 6. Refresh all providers that depend on vitals
      ref.invalidate(latestVitalsFutureProvider(widget.clientId));
      ref.invalidate(vitalsHistoryProvider(widget.clientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vitals Saved Successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving vitals: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log New Vitals'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _isSaving
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : IconButton(
              icon: const Icon(Icons.save),
              onPressed: _onSave,
              tooltip: 'Save Vitals',
            ),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- SECTION 1: AT-HOME VITALS ---
            _buildSectionHeader(context, 'At-Home Vitals', Icons.home_filled),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildVitalsField(_weightController, 'Current Weight (kg)'),
                    _buildVitalsField(_bpSystolicController, 'Blood Pressure (Systolic)', isInt: true),
                    _buildVitalsField(_bpDiastolicController, 'Blood Pressure (Diastolic)', isInt: true),
                    _buildVitalsField(_heartRateController, 'Heart Rate (BPM)', isInt: true),
                  ],
                ),
              ),
            ),

            // --- SECTION 2: LAB RESULTS ---
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Lab Results', Icons.science),

            // Dynamically build "question cards" from lab_vitals_data.dart
            ...LabVitalsData.labTestGroups.entries.map((groupEntry) {
              final String groupName = groupEntry.key;
              final List<String> testKeys = groupEntry.value;
              final IconData icon = LabVitalsData.groupIcons[groupName] ?? Icons.science;

              return _buildLabGroupCard(groupName, testKeys, icon);
            }).toList(),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabGroupCard(String groupName, List<String> testKeys, IconData icon) {
    final bool isExpanded = _groupExpandedState[groupName] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        key: PageStorageKey(groupName), // Maintain expanded state on scroll
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: SwitchListTile(
          value: isExpanded,
          onChanged: (bool newValue) {
            setState(() {
              _groupExpandedState[groupName] = newValue;
            });
          },
          title: Text(
            'Do you have a new $groupName report?',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          activeColor: Theme.of(context).colorScheme.secondary,
          contentPadding: EdgeInsets.zero,
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (bool expanding) {
          setState(() {
            _groupExpandedState[groupName] = expanding;
          });
        },
        children: [
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0).copyWith(top: 0),
              child: Column(
                children: testKeys.map((key) {
                  final testInfo = LabVitalsData.getTest(key);
                  if (testInfo == null) return const SizedBox.shrink();

                  return _buildVitalsField(
                    _labControllers[key]!,
                    testInfo.displayName,
                    unit: testInfo.unit,
                    hint: 'Ref: ${testInfo.referenceRange}',
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVitalsField(TextEditingController controller, String label, {bool isInt = false, String? unit, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
        inputFormatters: isInt
            ? [FilteringTextInputFormatter.digitsOnly]
            : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}