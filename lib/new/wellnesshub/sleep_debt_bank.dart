import 'package:flutter/material.dart';

class SleepDebtSheet extends StatefulWidget {
  const SleepDebtSheet({super.key});
  @override
  State<SleepDebtSheet> createState() => _SleepDebtSheetState();
}

class _SleepDebtSheetState extends State<SleepDebtSheet> {
  // 🎯 Medical Defaults
  double _ideal = 8.0;
  double _actual = 6.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🎯 Clinical Logic: Cumulative Weekly Deficit
    final dailyDebt = (_ideal - _actual).clamp(0.0, 12.0);
    final weeklyDebt = dailyDebt * 7;

    // Severity Color Mapping
    Color debtColor = weeklyDebt > 10 ? Colors.redAccent : (weeklyDebt > 5 ? Colors.orangeAccent : Colors.tealAccent);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // 🎯 Header
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CIRCADIAN ANALYSIS", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text("Sleep Debt & Recovery", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 🎯 THE DEBT GAUGE (Glassmorphism Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: debtColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: debtColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text("Weekly Deficit", style: TextStyle(color: debtColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text("${weeklyDebt.toStringAsFixed(1)}", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: debtColor)),
                            const SizedBox(width: 4),
                            Text("HRS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: debtColor.withOpacity(0.5))),
                          ],
                        ),
                        Text(
                          _getMedicalAdvice(weeklyDebt),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: debtColor.withOpacity(0.8), fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 🎯 INPUT SLIDERS
                  _buildMedicalSlider(
                    "Ideal Requirement",
                    "Based on your age & activity",
                    _ideal,
                    Icons.star_rounded,
                        (v) => setState(() => _ideal = v),
                    cs.primary,
                  ),

                  const SizedBox(height: 20),

                  _buildMedicalSlider(
                    "Actual Average",
                    "Last 7 days average",
                    _actual,
                    Icons.bedtime_rounded,
                        (v) => setState(() => _actual = v),
                    Colors.indigoAccent,
                  ),

                  const SizedBox(height: 32),

                  // 🎯 RECOVERY INSIGHT
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Recovery Tip: Repay debt by adding 30-60 mins of extra sleep per night. Avoid oversleeping on weekends as it resets your body clock.",
                            style: TextStyle(fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMedicalAdvice(double debt) {
    if (debt == 0) return "Optimal rest. Your cognitive performance is at its peak.";
    if (debt < 5) return "Mild deficit. Potential impact on focus and mood regulation.";
    if (debt < 10) return "Moderate debt. Elevated cortisol levels and metabolic slowdown.";
    return "Severe deprivation. High risk of microsleeps and immune suppression.";
  }

  Widget _buildMedicalSlider(String label, String sub, double val, IconData icon, Function(double) onChanged, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text("${val.toStringAsFixed(1)} h", style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
          ],
        ),
        Text(sub, style: TextStyle(fontSize: 11, color: theme.hintColor)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: val,
            min: 4, max: 12,
            divisions: 16,
            onChanged: onChanged,
            activeColor: color,
            inactiveColor: theme.dividerColor.withOpacity(0.1),
          ),
        ),
      ],
    );
  }
}