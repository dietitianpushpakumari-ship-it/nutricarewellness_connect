import 'package:flutter/material.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';

class DietPlanViewerScreen extends StatelessWidget {
  final ClientDietPlanModel? plan;
  final VitalsModel? vitals;

  const DietPlanViewerScreen({
    super.key,
    required this.plan,
    required this.vitals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(context, theme),
            Expanded(
              child: _buildModernContent(theme, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 MODERN CUSTOM HEADER
  Widget _buildModernHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: theme.iconTheme.color,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "Diet & Guidelines",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 MAIN CONTENT AREA
// 🎯 MAIN CONTENT AREA
  Widget _buildModernContent(ThemeData theme, ColorScheme colorScheme) {
    if (plan == null) {
      return Center(
        child: Text(
          "No active diet plan found.",
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor),
        ),
      );
    }

    // 🎯 Clean, safe fallback maps to prevent null errors
    final guidelines = vitals?.clinicalGuidelines ?? {};
    final medications = vitals?.medications ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. GUIDELINES SECTION
        if (guidelines.isNotEmpty) ...[
          _buildSectionTitle("Clinical Guidelines", theme),
          ...guidelines.entries.map((e) => _buildGuidelineCard(e.key, e.value, theme, colorScheme)),
          const SizedBox(height: 24),
        ],

        // 2. DIET ROUTINE SECTION
        _buildSectionTitle("Daily Diet Routine", theme),
        if (plan!.days.isNotEmpty)
          ...plan!.days.first.meals.map((meal) => _buildMealCard(meal, theme, colorScheme))
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("No meals defined in the current plan.", style: theme.textTheme.bodyMedium),
          ),

        const SizedBox(height: 24),

        // 3. MEDICATIONS SECTION
        if (medications.isNotEmpty) ...[
          _buildSectionTitle("Prescribed Medications", theme),
          ...medications.map((med) => _buildMedicationCard(med, theme, colorScheme)),
        ],
      ],
    );
  }

  // 🎯 REUSABLE UI COMPONENTS
  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildGuidelineCard(String title, String description, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          child: Icon(Icons.verified_user_rounded, color: colorScheme.primary),
        ),
        title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(description, style: theme.textTheme.bodySmall),
        ),
      ),
    );
  }
// 🎯 MEAL CARD (Now includes Alternative Foods)
  Widget _buildMealCard(dynamic meal, ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal Header
            Row(
              children: [
                Icon(Icons.restaurant_menu_rounded, color: colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  meal.mealName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1),
            ),

            // Food Items & Alternatives
            ...meal.items.map<Widget>((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Item
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 10),
                        child: CircleAvatar(radius: 3, backgroundColor: colorScheme.primary),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: "${item.foodItemName} ",
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text: "(${item.quantity} ${item.unit})",
                                style: TextStyle(color: theme.textTheme.bodySmall?.color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 🎯 Alternative Items Logic
                  if (item.alternatives != null && item.alternatives.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: item.alternatives.map<Widget>((alt) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(
                                    "OR",
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: isDark ? Colors.orangeAccent : Colors.orange.shade800,
                                        fontWeight: FontWeight.w900
                                    )
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${alt.foodItemName} (${alt.quantity} ${alt.unit})",
                                  style: TextStyle(fontSize: 13, color: theme.hintColor),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  Widget _buildMedicationCard(dynamic med, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.medication_rounded, color: colorScheme.error),
        ),
        title: Text(med.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "${med.dosage} • ${med.frequency}\n${med.instruction}",
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}