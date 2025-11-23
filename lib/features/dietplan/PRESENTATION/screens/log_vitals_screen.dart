import 'package:fl_chart/fl_chart.dart'; // 🎯 ADD THIS for Chart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For sorting
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

// A fixed meal name to identify the daily log entry for wellness/vitals
const String _kDailyWellnessLog = "DAILY_WELLNESS_CHECK";

class LogVitalsScreen extends ConsumerStatefulWidget {
  // 🎯 NEW PATTERN: Receive Notifier, Plan, and Log directly
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

  // "At-Home" Vitals Controllers
  final _weightController = TextEditingController();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();

  // Diabetic Profile Controllers
  final _fbsController = TextEditingController();
  final _ppbsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _fbsController.dispose();
    _ppbsController.dispose();
    super.dispose();
  }

  // Load data from the passed-in dailyLog
  void _loadInitialData() {
    final existingLog = widget.dailyLog;

    if (existingLog != null) {
      // Populate current metrics, safely converting to String
      _weightController.text = existingLog.weightKg?.toString() ?? '';
      _bpSystolicController.text = existingLog.bloodPressureSystolic?.toString() ?? '';
      _bpDiastolicController.text = existingLog.bloodPressureDiastolic?.toString() ?? '';
      _fbsController.text = existingLog.fbsMgDl?.toString() ?? '';
      _ppbsController.text = existingLog.ppbsMgDl?.toString() ?? '';
    }
  }

  Future<void> _onSave() async {
    // Basic validation
    if (_weightController.text.trim().isEmpty &&
        _bpSystolicController.text.trim().isEmpty &&
        _fbsController.text.trim().isEmpty)
    {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter at least one value.'), backgroundColor: Colors.orange));
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; });

    try {
      // Helper parsing
      double? safeParseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
      int? safeParseInt(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim())?.toInt();

      final newWeight = safeParseDouble(_weightController.text);
      final newBPSys = safeParseInt(_bpSystolicController.text);
      final newBPDia = safeParseInt(_bpDiastolicController.text);
      final newFBS = safeParseDouble(_fbsController.text);
      final newPPBS = safeParseDouble(_ppbsController.text);

      final logToSave = widget.dailyLog ?? ClientLogModel(
        id: '', // Empty ID for creation
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK', // Unique identifier
        actualFoodEaten: ['Daily Wellness Data'], // Constant value as a List
        date: widget.notifier.state.selectedDate,
      );

      // 2. Create the updated log by copying all existing fields
      //    and overriding the vital fields.
      final updatedLog = logToSave.copyWith(
        // Ensure the date stamp is correct
        weightKg: newWeight,
        bloodPressureSystolic: newBPSys,
        bloodPressureDiastolic: newBPDia,
        fbsMgDl: newFBS,
        ppbsMgDl: newPPBS,
      );

      // 3. Save using the DietPlanNotifier (handles create or update internally)
      await widget.notifier.createOrUpdateLog(
        log: updatedLog,
        mealPhotoFiles: const [],
      );

      // 🎯 Refresh History Provider so Chart updates immediately
      ref.invalidate(historicalLogProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vitals Saved!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Failed to save vitals: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  // --- UI and Widget Builder methods follow ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Log Daily Vitals'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
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
      body: Form(
        key: _formKey,
        child: _buildDailyVitalsTab(context),
      ),
    );
  }

  Widget _buildDailyVitalsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 🎯 NEW: Weekly Trend Chart (Visualizes ClientLogModel history)
        VitalsLogTrendChart(clientId: widget.activePlan.clientId),
        const SizedBox(height: 24),

        const Text("Body & Pressure Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        _buildWeightCard(context),
        const SizedBox(height: 20),
        _buildBpCard(context),

        const SizedBox(height: 24),
        const Text("Diabetic Profile (Blood Sugar)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildDiabeticMetricCard(
                context,
                title: "FBS",
                icon: Icons.grain,
                color: Colors.red,
                controller: _fbsController,
                unit: "mg/dL",
                helperText: "Fasting Blood Sugar",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDiabeticMetricCard(
                context,
                title: "PPBS",
                icon: Icons.access_time,
                color: Colors.purple,
                controller: _ppbsController,
                unit: "mg/dL",
                helperText: "Post-Prandial",
              ),
            ),
          ],
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildWeightCard(BuildContext context) {
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
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
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
    );
  }

  Widget _buildBpCard(BuildContext context) {
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
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.bloodtype, color: Colors.orange.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("Blood Pressure", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bpSystolicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: "Systolic", labelText: "Systolic", border: OutlineInputBorder()),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _bpDiastolicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: "Diastolic", labelText: "Diastolic", border: OutlineInputBorder()),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              const Text("mmHg", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiabeticMetricCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required MaterialColor color,
        required TextEditingController controller,
        required String unit,
        required String helperText,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Text(helperText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "0.0",
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
}

// =================================================================
// 🎯 NEW WIDGET: VitalsLogTrendChart (Consuming ClientLogModel)
// =================================================================
class VitalsLogTrendChart extends ConsumerStatefulWidget {
  final String clientId;
  const VitalsLogTrendChart({super.key, required this.clientId});

  @override
  ConsumerState<VitalsLogTrendChart> createState() => _VitalsLogTrendChartState();
}

class _VitalsLogTrendChartState extends ConsumerState<VitalsLogTrendChart> {
  String _selectedMetric = "Weight"; // Toggle between Weight, BP, Sugar

  @override
  Widget build(BuildContext context) {
    // 🎯 Consume the provider that fetches ClientLogModel history (Last 7 days)
    final historyAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: 7)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Weekly Trends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _buildToggleBtn("Wt", _selectedMetric == "Weight", () => setState(() => _selectedMetric = "Weight")),
                    _buildToggleBtn("BP", _selectedMetric == "BP", () => setState(() => _selectedMetric = "BP")),
                    _buildToggleBtn("Sug", _selectedMetric == "Sugar", () => setState(() => _selectedMetric = "Sugar")),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 150,
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text("No Data")),
              data: (groupedLogs) {
                // Flatten grouped logs and filter for wellness checks
                final List<ClientLogModel> logs = [];
                groupedLogs.forEach((date, dayLogs) {
                  final wellnessLog = dayLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
                  if (wellnessLog != null) logs.add(wellnessLog);
                });

                if (logs.isEmpty) return const Center(child: Text("Log data to see trends.", style: TextStyle(color: Colors.grey)));

                // Sort by date
                logs.sort((a, b) => a.date.compareTo(b.date));

                // Build Data Spots
                List<LineChartBarData> lines = [];

                if (_selectedMetric == "Weight") {
                  lines.add(_buildLine(logs, (l) => l.weightKg ?? 0.0, Colors.blue));
                } else if (_selectedMetric == "BP") {
                  lines.add(_buildLine(logs, (l) => (l.bloodPressureSystolic ?? 0).toDouble(), Colors.red));
                  lines.add(_buildLine(logs, (l) => (l.bloodPressureDiastolic ?? 0).toDouble(), Colors.orange));
                } else {
                  // Sugar
                  lines.add(_buildLine(logs, (l) => l.fbsMgDl ?? 0.0, Colors.purple));
                  lines.add(_buildLine(logs, (l) => l.ppbsMgDl ?? 0.0, Colors.pink));
                }

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int idx = value.toInt();
                            if (idx < 0 || idx >= logs.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(DateFormat('E').format(logs[idx].date)[0], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            );
                          },
                          interval: 1,
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: lines,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(List<ClientLogModel> logs, double Function(ClientLogModel) valueMapper, Color color) {
    return LineChartBarData(
      spots: logs.asMap().entries.map((e) => FlSpot(e.key.toDouble(), valueMapper(e.value))).toList(),
      isCurved: true, color: color, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)] : [],
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey)),
      ),
    );
  }
}