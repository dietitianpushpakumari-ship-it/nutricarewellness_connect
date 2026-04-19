import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/new/dietplan/meal_detail_sheet.dart';

class EliteMealCard extends StatefulWidget {
  final String mealName;
  final String? mealTime;
  final List<FlatDietPlanItem> mealItems;
  final MealEntry? mealLog;
  final bool isFocused;
  final bool isOverdue;
  final DietPlanNotifier notifier; // 🚀 Added to allow editing
  final FlatClientDietPlanModel activePlan; // 🚀 Added to allow editing
  final VoidCallback onQuickLog;

  const EliteMealCard({
    super.key,
    required this.mealName,
    this.mealTime,
    required this.mealItems,
    this.mealLog,
    this.isFocused = false,
    this.isOverdue = false,
    required this.notifier,
    required this.activePlan,
    required this.onQuickLog,
  });

  @override
  State<EliteMealCard> createState() => _EliteMealCardState();
}

class _EliteMealCardState extends State<EliteMealCard> with SingleTickerProviderStateMixin {
  late bool _isExpanded;

  // 🎨 THE PREMIUM PALETTE
  final Color bgObsidian = const Color(0xFF0B0F19);
  final Color surfaceNavy = const Color(0xFF121826);
  final Color neonGreen = const Color(0xFF00E676);
  final Color alertOrange = const Color(0xFFFF3D00);

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isFocused;
  }

  @override
  Widget build(BuildContext context) {
    final bool isLogged = widget.mealLog != null;
    final bool isSkipped = widget.mealLog?.status == LogStatus.skipped;

    // Determine the dominant color state
    Color statusColor = Colors.grey.shade600;
    if (isLogged) {
      statusColor = isSkipped ? Colors.grey.shade500 : neonGreen;
    } else if (widget.isFocused) {
      statusColor = neonGreen;
    } else if (widget.isOverdue) {
      statusColor = alertOrange;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: surfaceNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isFocused && !isLogged
              ? neonGreen.withOpacity(0.6)
              : statusColor.withOpacity(isLogged ? 0.2 : 0.05),
          width: widget.isFocused && !isLogged ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (widget.isFocused && !isLogged)
            BoxShadow(color: neonGreen.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
          if (!widget.isFocused)
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ELITE HEADER (NOW CONTAINS THE BUTTON)
            _buildHeader(statusColor, isLogged, isSkipped),

            // 2. 🚀 THE HERO ACTION (Only shows on the focused meal)
            if (widget.isFocused && !isLogged)
              _buildFrictionlessCameraAction(),

            // 3. COLLAPSIBLE MENU
            _buildSmartMenu(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER WIDGET (WITH GUARANTEED VISIBLE BUTTON)
  // ===========================================================================
  Widget _buildHeader(Color statusColor, bool isLogged, bool isSkipped) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isFocused && !isLogged
            ? statusColor.withOpacity(0.08)
            : Colors.white.withOpacity(0.02),
      ),
      child: Row(
        children: [
          // Dynamic Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(
              isLogged ? (isSkipped ? Icons.next_plan_rounded : Icons.check_circle_rounded) : (widget.isOverdue ? Icons.alarm_off_rounded : Icons.restaurant_rounded),
              size: 20, color: statusColor,
            ),
          ),
          const SizedBox(width: 16),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mealName.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2, color: Colors.white, decoration: isSkipped ? TextDecoration.lineThrough : null),
                ),
                const SizedBox(height: 4),
                if (widget.mealTime != null)
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: statusColor.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(widget.mealTime!, style: TextStyle(fontSize: 12, color: statusColor.withOpacity(0.9), fontWeight: FontWeight.w600)),
                      if (widget.isOverdue && !isLogged) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: alertOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: Text("LATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: alertOrange)),
                        )
                      ]
                    ],
                  ),
              ],
            ),
          ),

          // 🚀 THE ALWAYS-VISIBLE EDIT/LOG BUTTON
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              if (isLogged) {
                // OPEN EDIT SHEET
                showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => MealDetailSheet(
                        notifier: widget.notifier,
                        mealName: widget.mealName,
                        activePlan: widget.activePlan,
                        logToEdit: widget.mealLog,
                        plannedItems: widget.mealItems
                    )
                );
              } else {
                // TRIGGER FAST CAMERA/GALLERY
                HapticFeedback.lightImpact();
                widget.onQuickLog();
              }
            },
            icon: Icon(isLogged ? Icons.edit_rounded : Icons.camera_alt_rounded, size: 14),
            label: Text(isLogged ? "EDIT" : "LOG", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              // Hardcoded high-contrast colors so it cannot hide!
              backgroundColor: isLogged ? Colors.grey.shade700 : Colors.blueAccent.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. 🚀 FRICTIONLESS CAMERA ACTION (HERO BANNER)
  // ===========================================================================
  Widget _buildFrictionlessCameraAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            widget.onQuickLog();
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [neonGreen.withOpacity(0.15), neonGreen.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: neonGreen.withOpacity(0.3), style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, color: neonGreen, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TAP TO LOG", style: TextStyle(color: neonGreen, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
                    Text("Keep your streak alive", style: TextStyle(color: neonGreen.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. COLLAPSIBLE MENU
  // ===========================================================================
  Widget _buildSmartMenu() {
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text("${widget.mealItems.length} items planned", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                const Spacer(),
                Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),

        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.mealItems
                  .where((i) => i.itemType != DietItemType.bundleChild && i.itemType != DietItemType.alternative)
                  .map((item) {

                final bundleChildren = widget.mealItems.where((c) => c.parentId == item.id && c.itemType == DietItemType.bundleChild).toList();
                final alternatives = widget.mealItems.where((a) => a.parentId == item.id && a.itemType == DietItemType.alternative).toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: neonGreen.withOpacity(0.8))),
                          const SizedBox(width: 10),
                          Expanded(child: Text("${item.foodItemName} (${item.quantity} ${item.unit})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                        ],
                      ),
                      if (bundleChildren.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Column(
                            children: bundleChildren.map((bc) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Text("- ", style: TextStyle(color: Colors.grey.shade600)),
                                  Expanded(child: Text("${bc.foodItemName} (${bc.quantity} ${bc.unit})", style: TextStyle(fontSize: 13, color: Colors.grey.shade400))),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      if (alternatives.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: alternatives.map<Widget>((alt) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text("OR", style: TextStyle(fontSize: 9, color: Colors.orangeAccent.shade400, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text("${alt.foodItemName} (${alt.quantity} ${alt.unit})", style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic))),
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
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}