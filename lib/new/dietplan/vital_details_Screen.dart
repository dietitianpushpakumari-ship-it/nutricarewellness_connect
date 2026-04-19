import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';



import 'package:pure_shift/core/vitals_comprasion_screen.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/models/vitals_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class VitalsDetailScreen extends ConsumerWidget {
  final VitalsModel record;
  const VitalsDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final labConfigsAsync = ref.watch(labTestConfigsProvider);
    final historyAsync = ref.watch(vitalsHistoryProvider(record.clientId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildProfessionalAppBar(context, theme),
      // 🚀 THE FIX: Wrap the body in a SafeArea
      body: SafeArea(
        top: false, // The AppBar already handles the top notch
        bottom: true, // 👈 This protects the bottom from the home indicator
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.scale(20), context.scale(10), context.scale(20), context.scale(20)), // Adjusted bottom padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🏷️ CLINICAL ID & DATE HEADER
              _buildReportMeta(context, theme, isDark),
              SizedBox(height: context.scale(16)),

              // 🚀 CLINICAL COMPARISON ACTION
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact(); // 🚀 Maintain premium tactile feel
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true, // 🚀 Required for the 90% height container
                      backgroundColor: Colors.transparent, // 🚀 Ensures the sheet's rounded corners show correctly
                      builder: (context) => VitalsComparisonSheet(clientId: record.clientId),
                    );
                  },  icon: Icon(Icons.compare_arrows_rounded, size: context.scale(18)),
                  label: Text("COMPARE HISTORICAL TRENDS",
                      style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11), fontWeight: FontWeight.w700, letterSpacing: context.scale(1.0))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    foregroundColor: colorScheme.primary,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: context.scale(14)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.scale(12)),
                        side: BorderSide(color: colorScheme.primary.withOpacity(0.3))
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.scale(24)),

              // 🧬 SECTION 1: CORE BIOMETRICS (Grid Layout)
              _buildSectionLabel(context, "CORE BIOMETRICS"),
              _buildBiometricGrid(context, theme, colorScheme, isDark),
              SizedBox(height: context.scale(24)),

              // ❤️ SECTION 2: CARDIOVASCULAR PANEL
              _buildSectionLabel(context, "CARDIOVASCULAR PANEL"),
              _buildCardioPanel(context, theme, isDark),
              SizedBox(height: context.scale(24)),

              // 🔬 SECTION 3: COMPREHENSIVE LAB ANALYSIS
              _buildSectionLabel(context, "LABORATORY INVESTIGATION"),
              if (record.labResults.isNotEmpty)
                labConfigsAsync.when(
                  loading: () => Center(child: Padding(padding: EdgeInsets.all(context.scale(20)), child: const CircularProgressIndicator())),
                  error: (e, s) => Text("Config Error", style: TextStyle(fontSize: context.scale(10), color: theme.colorScheme.error)),
                  data: (configs) {
                    final history = historyAsync.value ?? [];
                    return _buildLabTable(context, configs, history, theme, colorScheme, isDark);
                  },
                )
              else
                _buildEmptyState(context, "No laboratory data recorded for this session.", theme),

              SizedBox(height: context.scale(24)),

              // 📋 SECTION 4: CLINICAL NOTES & IMPRESSIONS
              _buildSectionLabel(context, "CLINICAL IMPRESSIONS"),
              _buildClinicalProfile(context, theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // --- 🛠️ PROFESSIONAL UI COMPONENTS ---

  PreferredSizeWidget _buildProfessionalAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text("DIAGNOSTIC REPORT",
          style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12), fontWeight: FontWeight.w700, letterSpacing: context.scale(2.0))),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.share_outlined, size: context.scale(18)),
          onPressed: () {}, // Future PDF Export
        )
      ],
    );
  }

  Widget _buildReportMeta(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(context.scale(12)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("REPORT ID", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), fontWeight: FontWeight.w700, color: theme.hintColor)),
              Text(record.id.toUpperCase().substring(0, 8), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("COLLECTION DATE", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), fontWeight: FontWeight.w700, color: theme.hintColor)),
              Text(DateFormat('dd MMM yyyy • HH:mm').format(record.date), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.scale(12), left: context.scale(4)),
      child: Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: context.scale(1.5), color: Colors.blueAccent)),
    );
  }

  Widget _buildBiometricGrid(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: context.scale(10),
      crossAxisSpacing: context.scale(10),
      childAspectRatio: 1.2,
      children: [
        _buildMiniMetric(context, "Weight", "${record.weightKg}", "kg", theme),
        _buildMiniMetric(context, "Height", "${record.heightCm}", "cm", theme),
        _buildMiniMetric(context, "BMI", record.bmi.toStringAsFixed(1), "pts", theme,
            color: _getBmiColor(record.bmi, isDark)),
      ],
    );
  }

  Widget _buildCardioPanel(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(context.scale(16)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildExpandedMetric(context, "BP (SYS/DIA)", "${record.bloodPressureSystolic ?? '--'}/${record.bloodPressureDiastolic ?? '--'}", "mmHg", theme, Colors.redAccent),
          Container(width: context.scale(1), height: context.scale(30), color: theme.dividerColor.withOpacity(0.1)),
          _buildExpandedMetric(context, "HEART RATE", "${record.heartRate ?? '--'}", "bpm", theme, Colors.orange),
          Container(width: context.scale(1), height: context.scale(30), color: theme.dividerColor.withOpacity(0.1)),
          _buildExpandedMetric(context, "SpO2", "${record.spO2Percentage ?? '--'}", "%", theme, Colors.teal),
        ],
      ),
    );
  }

  // --- 🔬 THE PROFESSIONAL LAB TABLE ---
  Widget _buildLabTable(BuildContext context, List<dynamic> configs, List<VitalsModel> history, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(context.scale(16)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        children: record.labResults.entries.map((e) {
          final config = configs.cast<dynamic>().firstWhere((c) => c.id.trim().toLowerCase() == e.key.trim().toLowerCase(), orElse: () => null);

          final val = e.value;
          final min = config?.minRange;
          final max = config?.maxRange;
          final isAbnormal = (min != null && val < min) || (max != null && val > max);
          final color = isAbnormal ? Colors.redAccent : colorScheme.primary;

          return Container(
            padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(12)),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)))),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config?.name ?? e.key.toUpperCase(), style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                      Text("Ref: ${min ?? '0'} - ${max ?? 'N/A'} ${config?.unit ?? ''}", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(9), color: theme.hintColor)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1),
                          style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontWeight: FontWeight.w700, color: color)),
                      if (isAbnormal)
                        Text(val < (min ?? 0) ? "▼ LOW" : "▲ HIGH", style: TextStyle(fontSize: context.scale(8), fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- HELPER BUILDERS ---

  Widget _buildMiniMetric(BuildContext context, String label, String val, String unit, ThemeData theme, {Color? color}) {
    return Container(
      padding: EdgeInsets.all(context.scale(10)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(context.scale(12)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), fontWeight: FontWeight.w700, color: theme.hintColor)),
          SizedBox(height: context.scale(4)),
          RichText(text: TextSpan(children: [
            TextSpan(text: val, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(13), fontWeight: FontWeight.w700, color: color ?? theme.colorScheme.onSurface)),
            TextSpan(text: " $unit", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(8), color: theme.hintColor)),
          ])),
        ],
      ),
    );
  }

  Widget _buildExpandedMetric(BuildContext context, String label, String val, String unit, ThemeData theme, Color accent) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), fontWeight: FontWeight.w700, color: theme.hintColor)),
          SizedBox(height: context.scale(4)),
          Text(val, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(13), fontWeight: FontWeight.w700, color: accent)),
          Text(unit, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(8), color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildClinicalProfile(BuildContext context, ThemeData theme, bool isDark) {
    if (record.clinicalNotes == null || record.clinicalNotes!.isEmpty) {
      return _buildEmptyState(context, "No clinical impressions recorded.", theme);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.withOpacity(0.05) : Colors.blue.shade50.withOpacity(0.3),
        borderRadius: BorderRadius.circular(context.scale(16)),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("NOTES", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w700, color: Colors.blueAccent)),
          SizedBox(height: context.scale(8)),
          Text(record.clinicalNotes!.values.join("\n\n"), style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), height: 1.4, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String msg, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: context.scale(20)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(context.scale(12)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(msg, style: TextStyle(fontSize: context.scale(10), fontStyle: FontStyle.italic, color: theme.hintColor)),
      ),
    );
  }

  Color _getBmiColor(double bmi, bool isDark) {
    if (bmi <= 0) return Colors.grey;
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25) return Colors.green;
    return Colors.redAccent;
  }
}