import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/smart_dialogs.dart';
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

  // --- Controllers ---
  final _weightController = TextEditingController();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _fbsController = TextEditingController();
  final _ppbsController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.dailyLog != null) {
      final log = widget.dailyLog!;
      if ((log.weightKg ?? 0) > 0) _weightController.text = log.weightKg.toString();
      if (log.bloodPressureSystolic != null) _bpSystolicController.text = log.bloodPressureSystolic.toString();
      if (log.bloodPressureDiastolic != null) _bpDiastolicController.text = log.bloodPressureDiastolic.toString();
      if (log.heartRateBpm != null) _heartRateController.text = log.heartRateBpm.toString();
      if (log.spO2Percentage != null) _spo2Controller.text = log.spO2Percentage.toString();
      if ((log.fbsMgDl ?? 0) > 0) _fbsController.text = log.fbsMgDl.toString();
      if ((log.ppbsMgDl ?? 0) > 0) _ppbsController.text = log.ppbsMgDl.toString();
      if (log.waistCm != null) _waistController.text = log.waistCm.toString();
      if (log.hipCm != null) _hipController.text = log.hipCm.toString();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _spo2Controller.dispose();
    _fbsController.dispose();
    _ppbsController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  Future<void> _saveVitals() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // 🎯 CRITICAL FIX: Use selectedDate instead of DateTime.now()
      final targetDate = widget.notifier.state.selectedDate;

      final logToSave = widget.dailyLog ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: targetDate, // 🎯 FIX APPLIED HERE
      );

      final updatedLog = logToSave.copyWith(
        weightKg: double.tryParse(_weightController.text),
        bloodPressureSystolic: int.tryParse(_bpSystolicController.text),
        bloodPressureDiastolic: int.tryParse(_bpDiastolicController.text),
        heartRateBpm: int.tryParse(_heartRateController.text),
        spO2Percentage: double.tryParse(_spo2Controller.text),
        fbsMgDl: double.tryParse(_fbsController.text),
        ppbsMgDl: double.tryParse(_ppbsController.text),
        waistCm: double.tryParse(_waistController.text),
        hipCm: double.tryParse(_hipController.text),
      );

      await widget.notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        Navigator.pop(context);
        showContextualSuccessDialog(context, 'vitals');
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Log Vitals", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Daily Bio-Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
              Text("Logging for: ${widget.notifier.state.selectedDate.toString().split(' ')[0]}", style: const TextStyle(fontSize: 14, color: Colors.indigo, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              _buildPremiumInputCard(
                title: "Body Composition",
                icon: Icons.accessibility_new,
                color: Colors.blue,
                child: Column(
                  children: [
                    _buildLabeledInput("Weight", _weightController, "kg"),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildSingleInput(_waistController, "cm (Waist)")),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSingleInput(_hipController, "cm (Hip)")),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildPremiumInputCard(
                title: "Heart & Oxygen",
                icon: Icons.favorite,
                color: Colors.red,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildSingleInput(_bpSystolicController, "SYS", hint: "120")),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSingleInput(_bpDiastolicController, "DIA", hint: "80")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildSingleInput(_heartRateController, "BPM", hint: "72")),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSingleInput(_spo2Controller, "% SpO2", hint: "98")),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildPremiumInputCard(
                title: "Blood Glucose",
                icon: Icons.water_drop,
                color: Colors.purple,
                child: Column(
                  children: [
                    _buildLabeledInput("Fasting (FBS)", _fbsController, "mg/dL"),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildLabeledInput("Post-Prandial", _ppbsController, "mg/dL"),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveVitals,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Update Vitals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumInputCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSingleInput(TextEditingController controller, String suffix, {String hint = "0"}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade300), border: InputBorder.none, isDense: true),
            ),
          ),
          Text(suffix, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildLabeledInput(String label, TextEditingController controller, String suffix) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
        const SizedBox(width: 16),
        SizedBox(width: 180, child: _buildSingleInput(controller, suffix)),
      ],
    );
  }
}