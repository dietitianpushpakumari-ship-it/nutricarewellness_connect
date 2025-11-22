import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/lab_vitals_data.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';

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

class _LogVitalsScreenState extends ConsumerState<LogVitalsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isSaving = false;
  bool _isLoadingData = false; // 🎯 NEW: Loading state for fetching

  DateTime _selectedDate = DateTime.now();
  String? _existingRecordId; // 🎯 NEW: Track ID to enable updates

  // "At-Home" Vitals
  final _weightController = TextEditingController();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _heartRateController = TextEditingController();

  // "Lab Results"
  late Map<String, TextEditingController> _labControllers;
  late Map<String, bool> _groupSwitchState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _labControllers = {
      for (var key in LabVitalsData.allLabTests.keys) key: TextEditingController(),
    };

    _groupSwitchState = {
      for (var groupName in LabVitalsData.labTestGroups.keys) groupName: false,
    };

    // 🎯 FIX: Don't just use baseVitals. Check if there is already a log for TODAY.
    // If not, then fall back to baseVitals (pre-fill).
    _loadDataForDate(_selectedDate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weightController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    for (var c in _labControllers.values) c.dispose();
    super.dispose();
  }

  // 🎯 NEW: Fetch data when date changes
  Future<void> _loadDataForDate(DateTime date) async {
    setState(() => _isLoadingData = true);

    try {
      final service = ref.read(vitalsServiceProvider);
      final existingLog = await service.getDailyVitals(widget.clientId, date);

      if (existingLog != null) {
        // ✅ FOUND EXISTING: Populate fields with SAVED data
        _existingRecordId = existingLog.id;
        _weightController.text = existingLog.weightKg > 0 ? existingLog.weightKg.toString() : '';
        _bpSystolicController.text = existingLog.bloodPressureSystolic?.toString() ?? '';
        _bpDiastolicController.text = existingLog.bloodPressureDiastolic?.toString() ?? '';
        _heartRateController.text = existingLog.heartRate?.toString() ?? '';

        // Populate Labs
        existingLog.labResults.forEach((key, value) {
          if (_labControllers.containsKey(key)) {
            _labControllers[key]!.text = value;
          }
        });

        // Expand groups that have data
        // (Optional logic to auto-expand groups with values)

      } else {
        // ❌ NO RECORD: This is a new entry.
        _existingRecordId = null; // Clear ID so we create a new doc

        // Pre-fill WEIGHT from base (previous record) for convenience
        if (widget.baseVitals != null) {
          _weightController.text = widget.baseVitals!.weightKg > 0 ? widget.baseVitals!.weightKg.toString() : '';
        } else {
          _weightController.clear();
        }

        // Clear daily fluctuating metrics (BP/HR) - don't copy these forward
        _bpSystolicController.clear();
        _bpDiastolicController.clear();
        _heartRateController.clear();

        // Clear Lab fields
        for (var c in _labControllers.values) c.clear();
      }
    } catch (e) {
      print("Error loading date: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      // 🎯 FIX: Fetch data for the new date
      await _loadDataForDate(picked);
    }
  }

  Future<void> _onSave() async {
    if (_weightController.text.trim().isEmpty && _existingRecordId == null && widget.baseVitals == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter at least a Weight value.'), backgroundColor: Colors.orange));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; });

    try {
      // Prepare Maps
      final Map<String, String> finalLabResults = {};
      _labControllers.forEach((key, controller) {
        if (controller.text.trim().isNotEmpty) {
          finalLabResults[key] = controller.text.trim();
        }
      });

      // Helper parsing
      double? safeParseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
      int? safeParseInt(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim())?.toInt();

      final newWeight = safeParseDouble(_weightController.text);

      // Use Base as fallback for static profile data
      final base = widget.baseVitals;

      final vitalsRecord = VitalsModel(
        // 🎯 FIX: Use existing ID if updating, else empty string
        id: _existingRecordId ?? '',

        clientId: widget.clientId,
        date: _selectedDate, // Keep the selected date (don't overwrite with Now)
        isFirstConsultation: false,

        weightKg: newWeight ?? base?.weightKg ?? 0,
        bloodPressureSystolic: safeParseInt(_bpSystolicController.text),
        bloodPressureDiastolic: safeParseInt(_bpDiastolicController.text),
        heartRate: safeParseInt(_heartRateController.text),
        labResults: finalLabResults,

        // Carry forward static data
        heightCm: base?.heightCm ?? 0,
        bmi: base?.bmi ?? 0,
        idealBodyWeightKg: base?.idealBodyWeightKg ?? 0,
        bodyFatPercentage: base?.bodyFatPercentage ?? 0,
        measurements: base?.measurements ?? {},
        notes: base?.notes, // Or null if you want fresh notes
        labReportUrls: base?.labReportUrls ?? [], // Or handle new uploads
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

      final vitalsService = ref.read(vitalsServiceProvider);

      if (_existingRecordId != null && _existingRecordId!.isNotEmpty) {
        // 🎯 UPDATE Existing
        await vitalsService.updateVitals(vitalsRecord);
      } else {
        // 🎯 CREATE New
        await vitalsService.addVitals(vitalsRecord);
      }

      // Refresh
      ref.invalidate(latestVitalsFutureProvider(widget.clientId));
      ref.invalidate(vitalsHistoryProvider(widget.clientId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vitals Saved!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Log Health Data'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: "Daily Vitals", icon: Icon(Icons.monitor_heart_outlined)),
            Tab(text: "Lab Reports", icon: Icon(Icons.science_outlined)),
          ],
        ),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            TextButton(
              onPressed: _onSave,
              child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
            )
        ],
      ),
      // 🎯 Show loading indicator while fetching data
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDailyVitalsTab(context),
            _buildLabReportsTab(context),
          ],
        ),
      ),
    );
  }

  // ... (Keep _buildDailyVitalsTab, _buildLabReportsTab, and other helper widgets as they were) ...
  // Make sure to paste the helper widgets here if you are replacing the whole file.
  // For brevity, I assume you have them from the previous step. If not, let me know!

  // --- TAB 1: DAILY VITALS ---
  Widget _buildDailyVitalsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Date Selector
        _buildDateCard(context),
        const SizedBox(height: 24),

        const Text("Body Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Weight Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.monitor_weight, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  const Text("Weight", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "0.0",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const Text("kg", style: TextStyle(fontSize: 20, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Heart & BP Row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: "Heart Rate",
                icon: Icons.favorite,
                color: Colors.red,
                controller: _heartRateController,
                unit: "bpm",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                          child: Icon(Icons.bloodtype, color: Colors.orange.shade700, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Text("BP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bpSystolicController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: "Sys", border: InputBorder.none),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Text("/", style: TextStyle(fontSize: 20, color: Colors.grey)),
                        Expanded(
                          child: TextFormField(
                            controller: _bpDiastolicController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: "Dia", border: InputBorder.none),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const Text("mmHg", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 2: LAB REPORTS ---
  Widget _buildLabReportsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildDateCard(context),
        const SizedBox(height: 20),
        const Text("Enter Report Values", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text("Select a category to expand and enter values.", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        // Dynamic Lab Groups
        ...LabVitalsData.labTestGroups.entries.map((groupEntry) {
          final String groupName = groupEntry.key;
          final List<String> testKeys = groupEntry.value;
          final IconData icon = LabVitalsData.groupIcons[groupName] ?? Icons.science;

          return _buildLabGroupCard(groupName, testKeys, icon);
        }).toList(),

        const SizedBox(height: 40),
      ],
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildDateCard(BuildContext context) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Date of Record", style: TextStyle(fontWeight: FontWeight.w600)),
            Row(
              children: [
                Text(DateFormat.yMMMd().format(_selectedDate), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {required String title, required IconData icon, required MaterialColor color, required TextEditingController controller, required String unit}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle),
                child: Icon(icon, color: color.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "--",
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabGroupCard(String groupName, List<String> testKeys, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isExpanded = _groupSwitchState[groupName] ?? false;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: testKeys.map((key) {
            final testInfo = LabVitalsData.getTest(key);
            if (testInfo == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextFormField(
                controller: _labControllers[key],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: testInfo.displayName,
                  suffixText: testInfo.unit,
                  helperText: "Ref: ${testInfo.referenceRange}",
                  helperStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}