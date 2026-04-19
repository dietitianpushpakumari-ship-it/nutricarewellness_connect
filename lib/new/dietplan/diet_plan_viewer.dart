import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:pure_shift/new/models/vitals_model.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class DietPlanViewerSheet extends StatelessWidget {
  final FlatClientDietPlanModel? plan;
  final VitalsModel? vitals;

  const DietPlanViewerSheet({
    super.key,
    required this.plan,
    required this.vitals,
  });

  // 🎨 ELITE PALETTE
  final Color neonGreen = const Color(0xFF00E676);
  final Color alertOrange = const Color(0xFFFF3D00);
  final Color medPink = const Color(0xFFFF4081);
  final Color habitBlue = const Color(0xFF2979FF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceNavy = isDark ? const Color(0xFF121826) : Colors.white;

    return Container(
      // Sets the height to 90% of screen
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 🛠️ BOTTOM SHEET HANDLE & CROSS BUTTON
          _buildSheetHeader(context, theme, surfaceNavy, isDark),

          Expanded(
            child: _buildEliteContent(theme, surfaceNavy, isDark),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. 🚀 SHEET HEADER (Handle + Title + Cross)
  // ===========================================================================
  Widget _buildSheetHeader(BuildContext context, ThemeData theme, Color surfaceColor, bool isDark) {
    return Column(
      children: [
        // Subtle Handle
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DIET PROTOCOL",
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Your personalized clinical plan",
                    style: TextStyle(fontFamily: kBodyFont, fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // ❌ CROSS BUTTON
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, size: 22, color: theme.hintColor),
                splashRadius: 24,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      ],
    );
  }

  // ===========================================================================
  // 2. 🚀 MAIN CONTENT (Preserved Logic)
  // ===========================================================================
  Widget _buildEliteContent(ThemeData theme, Color surfaceColor, bool isDark) {
    if (plan == null) {
      return Center(
        child: Text("No active diet plan found.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w600)),
      );
    }

    final medications = vitals?.medications ?? [];

    List<FlatDietPlanItem> displayItems = [];
    if (plan!.allItems.isNotEmpty) {
      final firstDayId = plan!.allItems.first.dayId;
      displayItems = plan!.allItems.where((i) => i.dayId == firstDayId).toList();
    }

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), // Adjusted bottom padding for sheet
      physics: const BouncingScrollPhysics(),
      children: [
        _buildEliteSectionTitle("DAILY ROUTINE", Icons.restaurant_menu_rounded, theme.colorScheme.primary, theme),
        if (uniqueMealIds.isNotEmpty)
          ...uniqueMealIds.map((mealId) {
            final mealItems = displayItems.where((i) => i.mealId == mealId).toList();
            if (mealItems.isEmpty) return const SizedBox.shrink();
            final mealName = mealItems.first.mealName;
            return _buildEliteMealCard(mealName, mealItems, theme, surfaceColor, isDark);
          })
        else
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 24),
            child: Text("No meals defined.", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: theme.hintColor)),
          ),

        if (medications.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildEliteSectionTitle("PRESCRIBED MEDICATIONS", Icons.medication_rounded, medPink, theme),
          ...medications.map((med) => _buildMedicationCard(med, theme, surfaceColor, isDark)),
        ],
      ],
    );
  }

  // ===========================================================================
  // 3. 🚀 UI COMPONENTS (Preserved logic & your modified font sizes)
  // ===========================================================================

  Widget _buildEliteSectionTitle(String title, IconData icon, Color iconColor, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: kDisplayFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.hintColor,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(dynamic med, ThemeData theme, Color surfaceColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            child: Icon(Icons.vaccines_rounded, color: medPink, size: 14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12, color: theme.colorScheme.onSurface, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text("${med.dosage} • ${med.frequency}", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w700, color: medPink)),
                const SizedBox(height: 4),
                Text(med.instruction, style: TextStyle(fontFamily: kBodyFont, fontSize: 10, height: 1.4, color: theme.hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliteMealCard(String mealName, List<FlatDietPlanItem> itemsInMeal, ThemeData theme, Color surfaceColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_rounded, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                    mealName.toUpperCase(),
                    style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.0, color: theme.colorScheme.onSurface)
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                      _buildFoodLine(
                          name: primary.foodItemName,
                          qty: primary.quantity.toString(),
                          unit: primary.unit,
                          isPrimary: true,
                          theme: theme
                      ),
                      if (bundleChildren.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 14, top: 6),
                          child: Container(
                            padding: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(border: Border(left: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 1.5))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: bundleChildren.map((bc) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _buildFoodLine(
                                    name: bc.foodItemName,
                                    qty: bc.quantity.toString(),
                                    unit: bc.unit,
                                    isPrimary: false,
                                    theme: theme
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      if (alternatives.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 14, top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: alternatives.map<Widget>((alt) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: alertOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                    child: Text("OR", style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, color: alertOrange, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _buildFoodLine(
                                          name: alt.foodItemName,
                                          qty: alt.quantity.toString(),
                                          unit: alt.unit,
                                          isPrimary: false,
                                          isItalic: true,
                                          theme: theme
                                      )
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

  Widget _buildFoodLine({
    required String name,
    required String qty,
    required String unit,
    bool isPrimary = true,
    bool isItalic = false,
    required ThemeData theme
  }) {
    final String cleanName = name.isNotEmpty
        ? name[0].toUpperCase() + name.substring(1).toLowerCase()
        : "";

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: kBodyFont,
          fontSize: 14,
          height: 1.3,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        ),
        children: [
          TextSpan(
            text: cleanName,
            style: TextStyle(
              fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const TextSpan(text: "  "),
          TextSpan(
            text: "$qty $unit",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: theme.hintColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}