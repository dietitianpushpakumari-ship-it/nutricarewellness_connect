import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class LogVitalsScreen extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;

  const LogVitalsScreen({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
  });

  @override
  ConsumerState<LogVitalsScreen> createState() => _LogVitalsScreenState();
}

class _LogVitalsScreenState extends ConsumerState<LogVitalsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers (Mapping directly to the Vitals Map in your new structure)
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final log = widget.dailyLog;
    _controllers = {
      'weightKg': TextEditingController(text: log?.weightKg?.toString() ?? ''),
      'bpSystolic': TextEditingController(text: log?.bloodPressureSystolic?.toString() ?? ''),
      'bpDiastolic': TextEditingController(text: log?.bloodPressureDiastolic?.toString() ?? ''),
      'heartRate': TextEditingController(text: log?.heartRateBpm?.toString() ?? ''),
      'spO2': TextEditingController(text: log?.spO2Percentage?.toString() ?? ''),
      'fbs': TextEditingController(text: log?.fbsMgDl?.toString() ?? ''),
      'ppbs': TextEditingController(text: log?.ppbsMgDl?.toString() ?? ''),
      'waist': TextEditingController(text: log?.waistCm?.toString() ?? ''),
      'hip': TextEditingController(text: log?.hipCm?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveVitals() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final dateId = DateFormat('yyyy-MM-dd').format(widget.notifier.state.selectedDate);

      // 🎯 NEW ATOMIC STRUCTURE: Map directly to specific fields in the master document
      final Map<String, dynamic> vitalsData = {
        'weightKg': double.tryParse(_controllers['weightKg']!.text),
        'bloodPressureSystolic': int.tryParse(_controllers['bpSystolic']!.text),
        'bloodPressureDiastolic': int.tryParse(_controllers['bpDiastolic']!.text),
        'heartRateBpm': int.tryParse(_controllers['heartRate']!.text),
        'spO2Percentage': double.tryParse(_controllers['spO2']!.text),
        'fbsMgDl': double.tryParse(_controllers['fbs']!.text),
        'ppbsMgDl': double.tryParse(_controllers['ppbs']!.text),
        'waistCm': double.tryParse(_controllers['waist']!.text),
        'hipCm': double.tryParse(_controllers['hip']!.text),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // 🎯 Atomic Update: Only updates vitals without touching meals/hydration
   //   await widget.notifier.updateDailyRecord(
     //   dateId: dateId,
       // data: vitalsData,
     // );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Vitals", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            _buildDateBanner(theme),
            const SizedBox(height: 24),

            _buildCategoryCard(
              theme, "Body Composition", Icons.monitor_weight_outlined, colorScheme.primary,
              [
                _buildRowInput("Weight", _controllers['weightKg']!, "kg"),
                _buildDoubleInput("Waist", _controllers['waist']!, "Hip", _controllers['hip']!, "cm"),
              ],
            ),
            const SizedBox(height: 16),

            _buildCategoryCard(
              theme, "Heart Health", Icons.favorite_outline_rounded, Colors.redAccent,
              [
                _buildDoubleInput("Systolic", _controllers['bpSystolic']!, "Diastolic", _controllers['bpDiastolic']!, "mmHg"),
                _buildDoubleInput("Heart Rate", _controllers['heartRate']!, "SpO2", _controllers['spO2']!, "bpm/%"),
              ],
            ),
            const SizedBox(height: 16),

            _buildCategoryCard(
              theme, "Blood Glucose", Icons.bloodtype_outlined, Colors.purple,
              [
                _buildRowInput("Fasting (FBS)", _controllers['fbs']!, "mg/dL"),
                _buildRowInput("Post-Meal (PPBS)", _controllers['ppbs']!, "mg/dL"),
              ],
            ),

            const SizedBox(height: 32),
            _buildSaveButton(colorScheme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER COMPONENTS ---

  Widget _buildDateBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          "Logging for: ${DateFormat('EEEE, MMM d').format(widget.notifier.state.selectedDate)}",
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(ThemeData theme, String title, IconData icon, Color color, List<Widget> children) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 20),
          ...children.expand((w) => [w, const SizedBox(height: 12)]).toList()..removeLast(),
        ],
      ),
    );
  }

  Widget _buildRowInput(String label, TextEditingController controller, String unit) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        _buildField(controller, unit, width: 120),
      ],
    );
  }

  Widget _buildDoubleInput(String l1, TextEditingController c1, String l2, TextEditingController c2, String unit) {
    return Row(
      children: [
        Expanded(child: _buildField(c1, l1, isCompact: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildField(c2, l2, isCompact: true)),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String hint, {double? width, bool isCompact = false}) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.normal),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveVitals,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: _isSaving
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text("Update Health Record", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }
}