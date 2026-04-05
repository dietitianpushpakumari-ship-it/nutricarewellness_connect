import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/flat_diet_plan_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';

class DietPlanViewerScreen extends StatelessWidget {
  final FlatClientDietPlanModel? plan;
  final VitalsModel? vitals;

  const DietPlanViewerScreen({
    super.key,
    required this.plan,
    required this.vitals,
  });

  // 🎨 ELITE PALETTE
  final Color neonGreen = const Color(0xFF00E676);
  final Color alertOrange = const Color(0xFFFF3D00);
  final Color medPink = const Color(0xFFFF4081);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgObsidian = isDark ? const Color(0xFF0B0F19) : theme.scaffoldBackgroundColor;
    final surfaceNavy = isDark ? const Color(0xFF121826) : Colors.white;

    return Scaffold(
      backgroundColor: bgObsidian,
      body: SafeArea(
        child: Column(
          children: [
            _buildEliteHeader(context, theme, surfaceNavy, isDark),
            Expanded(
              child: _buildEliteContent(theme, surfaceNavy, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. 🚀 ELITE HEADER
  // ===========================================================================
  Widget _buildEliteHeader(BuildContext context, ThemeData theme, Color surfaceColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "DIET PROTOCOL",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                "Your personalized clinical plan",
                style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. 🚀 MAIN CONTENT
  // ===========================================================================
  Widget _buildEliteContent(ThemeData theme, Color surfaceColor, bool isDark) {
    if (plan == null) {
      return Center(
        child: Text("No active diet plan found.", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600)),
      );
    }

    final guidelines = vitals?.clinicalGuidelines ?? {};
    final medications = vitals?.medications ?? [];

    // 1. Filter for a single day (usually Day 1)
    List<FlatDietPlanItem> displayItems = [];
    if (plan!.allItems.isNotEmpty) {
      final firstDayId = plan!.allItems.first.dayId;
      displayItems = plan!.allItems.where((i) => i.dayId == firstDayId).toList();
    }

    // 2. Identify Unique Meals
    final uniqueMealIds = displayItems
        .where((i) => i.itemType == DietItemType.primary)
        .map((e) => e.mealId)
        .toSet()
        .toList();

    uniqueMealIds.sort((a, b) {
      final orderA = displayItems.firstWhere((i) => i.mealId == a).mealOrder;
      final orderB = displayItems.firstWhere((i) => i.mealId == b).mealOrder;
      return orderA.compareTo(orderB);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        if (guidelines.isNotEmpty) ...[
          _buildEliteSectionTitle("CLINICAL GUIDELINES", Icons.verified_user_rounded, theme),
          ...guidelines.entries.map((e) => _buildGuidelineCard(e.key, e.value, theme, surfaceColor, isDark)),
          const SizedBox(height: 32),
        ],

        _buildEliteSectionTitle("DAILY ROUTINE", Icons.restaurant_menu_rounded, theme),
        if (uniqueMealIds.isNotEmpty)
          ...uniqueMealIds.map((mealId) {
            final mealItems = displayItems.where((i) => i.mealId == mealId).toList();
            if (mealItems.isEmpty) return const SizedBox.shrink();
            final mealName = mealItems.first.mealName;
            return _buildEliteMealCard(mealName, mealItems, theme, surfaceColor, isDark);
          })
        else
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("No meals defined.", style: TextStyle(color: theme.hintColor)),
          ),

        if (medications.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildEliteSectionTitle("PRESCRIBED MEDICATIONS", Icons.medication_rounded, theme),
          ...medications.map((med) => _buildMedicationCard(med, theme, surfaceColor, isDark)),
        ],
      ],
    );
  }

  // ===========================================================================
  // 3. 🚀 ELITE UI COMPONENTS
  // ===========================================================================

  Widget _buildEliteSectionTitle(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: neonGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: theme.hintColor,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineCard(String title, String description, ThemeData theme, Color surfaceColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: neonGreen.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.info_outline_rounded, color: neonGreen, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, height: 1.4, color: theme.hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(dynamic med, ThemeData theme, Color surfaceColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: medPink.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.vaccines_rounded, color: medPink, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: theme.colorScheme.onSurface, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text("${med.dosage} • ${med.frequency}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: medPink)),
                const SizedBox(height: 4),
                Text(med.instruction, style: TextStyle(fontSize: 12, height: 1.4, color: theme.hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliteMealCard(String mealName, List<FlatDietPlanItem> itemsInMeal, ThemeData theme, Color surfaceColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_rounded, size: 16, color: neonGreen),
                const SizedBox(width: 10),
                Text(
                    mealName.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0, color: theme.colorScheme.onSurface)
                ),
              ],
            ),
          ),

          // Meal Items
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: itemsInMeal.where((i) => i.itemType == DietItemType.primary).map<Widget>((primary) {

                final bundleChildren = itemsInMeal.where((i) => i.parentId == primary.id && i.itemType == DietItemType.bundleChild).toList();
                final alternatives = itemsInMeal.where((i) => i.parentId == primary.id && i.itemType == DietItemType.alternative).toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🍲 PRIMARY ITEM
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 12),
                            height: 6, width: 6,
                            decoration: BoxDecoration(color: neonGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: neonGreen.withOpacity(0.5), blurRadius: 4)]),
                          ),
                          Expanded(
                              child: Text(
                                  "${primary.foodItemName} (${primary.quantity} ${primary.unit})",
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: theme.colorScheme.onSurface)
                              )
                          ),
                        ],
                      ),

                      // 🍱 BUNDLE CHILDREN
                      if (bundleChildren.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 18, top: 8),
                          child: Container(
                            padding: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(border: Border(left: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 2))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: bundleChildren.map((bc) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text("${bc.foodItemName} (${bc.quantity} ${bc.unit})", style: TextStyle(fontSize: 13, color: theme.hintColor, fontWeight: FontWeight.w500)),
                              )).toList(),
                            ),
                          ),
                        ),

                      // 🎯 ALTERNATIVES (OR Logic)
                      if (alternatives.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 18, top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: alternatives.map<Widget>((alt) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: alertOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text("OR", style: TextStyle(fontSize: 9, color: alertOrange, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text("${alt.foodItemName} (${alt.quantity} ${alt.unit})", style: TextStyle(fontSize: 13, color: theme.hintColor, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600))
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}