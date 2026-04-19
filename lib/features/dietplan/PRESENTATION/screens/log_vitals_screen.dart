import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';



import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

import '../../../../elite_nudge_hub.dart';

class LogVitalsSheet extends StatefulWidget {
  final DietPlanNotifier notifier;
  final FlatClientDietPlanModel activePlan;
  final ClientLogModel? dailyLog;

  const LogVitalsSheet({
    super.key,
    required this.notifier,
    required this.activePlan,
    required this.dailyLog,
  });

  @override
  State<LogVitalsSheet> createState() => _LogVitalsSheetState();
}

class _LogVitalsSheetState extends State<LogVitalsSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    // 🎯 PRE-LOAD: This fills the form with existing data immediately
    _initControllers(widget.dailyLog);
  }

  void _initControllers(ClientLogModel? log) {
    _controllers = {
      'weightKg': TextEditingController(text: _formatVal(log?.weightKg)),
      'bpSystolic': TextEditingController(text: _formatVal(log?.bloodPressureSystolic)),
      'bpDiastolic': TextEditingController(text: _formatVal(log?.bloodPressureDiastolic)),
      'heartRate': TextEditingController(text: _formatVal(log?.heartRateBpm)),
      'fbs': TextEditingController(text: _formatVal(log?.fbsMgDl)),
      'ppbs': TextEditingController(text: _formatVal(log?.ppbsMgDl)),
    };
  }

  // Clean formatting: prevents "0.0" or "null" appearing in fields
  String _formatVal(dynamic val) {
    if (val == null || val == 0) return '';
    if (val is double && val % 1 == 0) return val.toInt().toString();
    return val.toString();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _saveVitals() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> vitalsData = {
        'weightKg': double.tryParse(_controllers['weightKg']!.text),
        'bloodPressureSystolic': int.tryParse(_controllers['bpSystolic']!.text),
        'bloodPressureDiastolic': int.tryParse(_controllers['bpDiastolic']!.text),
        'heartRateBpm': int.tryParse(_controllers['heartRate']!.text),
        'fbsMgDl': double.tryParse(_controllers['fbs']!.text),
        'ppbsMgDl': double.tryParse(_controllers['ppbs']!.text),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await widget.notifier.updateDailyRecord(data: vitalsData);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121826) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(24))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact Header
            _buildHeader(context, theme),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(context.scale(20), 0, context.scale(20), context.scale(24)),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildSectionHeader(context, "BODY COMPOSITION", Icons.monitor_weight_rounded, Colors.orange),
                      _buildInputRow(context, "Weight", _controllers['weightKg']!, "kg"),

                      SizedBox(height: context.scale(20)),
                      _buildSectionHeader(context, "HEART HEALTH", Icons.favorite_rounded, Colors.redAccent, trailing: "mmHg"), // 🚀 Added Unit here
                      Row(
                        children: [
                          // Removed the individual "mmHg" units to save space
                          Expanded(child: _buildInputRow(context, "SYS", _controllers['bpSystolic']!, "")),
                          SizedBox(width: context.scale(10)),
                          Expanded(child: _buildInputRow(context, "DIA", _controllers['bpDiastolic']!, "")),
                        ],
                      ),
                      // 🚀 FIXED: Removed the duplicated Heart Rate input row
                      _buildInputRow(context, "Heart Rate", _controllers['heartRate']!, "bpm"),
                      SizedBox(height: context.scale(20)),
                      _buildSectionHeader(context, "BLOOD GLUCOSE", Icons.bloodtype_rounded, Colors.purpleAccent),
                      _buildInputRow(context, "Fasting (FBS)", _controllers['fbs']!, "mg/dL"),
                      _buildInputRow(context, "Post-Meal (PPBS)", _controllers['ppbs']!, "mg/dL"),

                      SizedBox(height: context.scale(32)),
                      _buildSaveButton(context, colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.scale(16), horizontal: context.scale(20)),
      child: Column(
        children: [
          Container(width: context.scale(32), height: context.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(context.scale(2)))),
          SizedBox(height: context.scale(16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DAILY LOG", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12), fontWeight: FontWeight.w900, letterSpacing: context.scale(1.5))),
                  Text(DateFormat('EEEE, MMM dd').format(widget.notifier.state.selectedDate), style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(10), color: theme.hintColor)),
                ],
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, size: context.scale(20))),
            ],
          ),
          Divider(height: context.scale(24)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color, {String? trailing}) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.scale(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: context.scale(14)),
              SizedBox(width: context.scale(8)),
              Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w900, color: color, letterSpacing: context.scale(1.0))),
            ],
          ),
          if (trailing != null)
            Text(trailing, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w700, color: Theme.of(context).hintColor.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildInputRow(BuildContext context, String label, TextEditingController controller, String unit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: context.scale(8)),
      padding: EdgeInsets.symmetric(horizontal: context.scale(10), vertical: context.scale(8)),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(context.scale(12)),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Text(
              label,
              style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), fontWeight: FontWeight.w600)
          ),
          SizedBox(width: context.scale(4)), // Small gap
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, fontSize: context.scale(11)),
              decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: "-", // Minimalist hint
                  hintStyle: TextStyle(color: Theme.of(context).hintColor.withOpacity(0.2))
              ),
            ),
          ),
          if (unit.isNotEmpty)
            Padding(
                padding: EdgeInsets.only(left: context.scale(4)),
                child: Text(unit, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), fontWeight: FontWeight.w700, color: Theme.of(context).hintColor))
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity, height: context.scale(48),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveVitals,
        style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(12))), elevation: 0),
        child: _isSaving
            ? SizedBox(width: context.scale(20), height: context.scale(20), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text("SAVE CHANGES", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(11), letterSpacing: context.scale(1.0))),
      ),
    );
  }
}