import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
// 🚀 Ensure this import matches your VitalsModel location
import 'package:pure_shift/new/models/vitals_model.dart';
import 'package:pure_shift/new/dietplan/vital_details_Screen.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class ClientVitalsHistorySheet extends ConsumerWidget {
  final String clientId;
  const ClientVitalsHistorySheet({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final vitalsAsync = ref.watch(vitalsHistoryProvider(clientId));

    return Container(
      // 🚀 THE FIX: Constraints and background color
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F131D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        // 🚀 THE FIX: Ensures content doesn't go under system bars
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2)
                )
            ),
            const SizedBox(height: 16),

            // Header - added horizontal padding here
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSheetHeader(context, theme, colorScheme),
            ),
            const SizedBox(height: 20),

            Flexible(
              child: vitalsAsync.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(strokeWidth: 2)
                ),
                error: (e, s) => _buildErrorState(colorScheme),
                data: (history) {
                  if (history.isEmpty) return _buildEmptyState(theme);

                  final sortedHistory = List<VitalsModel>.from(history)
                    ..sort((a, b) => b.date.compareTo(a.date));

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    // 🚀 THE FIX: Added significant bottom padding for the list
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: sortedHistory.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.dividerColor.withOpacity(0.05)
                    ),
                    itemBuilder: (context, index) => _buildClinicalRow(
                        context,
                        sortedHistory[index],
                        theme,
                        colorScheme
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("LAB REPORTS",
                style: TextStyle(
                    fontFamily: kDisplayFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: theme.hintColor.withOpacity(0.6)
                )
            ),
            Text("Clinical Records",
                style: TextStyle(
                    fontFamily: kDisplayFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface
                )
            ),
          ],
        ),
        IconButton(
          // 🚀 THE FIX: Clean Navigator pop
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 20),
          style: IconButton.styleFrom(
              backgroundColor: theme.dividerColor.withOpacity(0.05)
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalRow(BuildContext context, VitalsModel record, ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VitalsDetailScreen(record: record))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Clinical Date Block
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Text(DateFormat('dd').format(record.date), style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.primary)),
                  Text(DateFormat('MMM').format(record.date).toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: 8, fontWeight: FontWeight.w700, color: colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Stats Snapshot based on your specific VitalsModel fields
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Clinical Assessment", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildMiniBadge("${record.weightKg}kg", Icons.monitor_weight_rounded, Colors.orange, theme),
                      if (record.bloodPressureSystolic != null)
                        _buildMiniBadge("${record.bloodPressureSystolic}/${record.bloodPressureDiastolic}", Icons.favorite_rounded, Colors.redAccent, theme),
                      if (record.heartRate != null)
                        _buildMiniBadge("${record.heartRate} bpm", Icons.monitor_heart_rounded, Colors.pinkAccent, theme),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: theme.hintColor.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontFamily: kBodyFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.biotech_rounded, size: 40, color: theme.dividerColor.withOpacity(0.1)),
          const SizedBox(height: 12),
          Text("No clinical records found", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Text("Error fetching report history", style: TextStyle(fontSize: 11, color: colorScheme.error)),
    );
  }
}