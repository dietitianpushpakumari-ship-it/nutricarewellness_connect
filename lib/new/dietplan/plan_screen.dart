import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/elite_meal_card.dart';
import 'package:pure_shift/image_helper_service.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/dietplan/diet_plan_viewer.dart';
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';

// 🚀 PREMIUM EDITORIAL FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class PlanScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dietPlanNotifierProvider(client.id));
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 2));
    }
    if (state.error != null) {
      return Center(child: Text('Error: ${state.error}', style: TextStyle(color: theme.hintColor)));
    }

    final FlatClientDietPlanModel? activePlan = state.activePlan;
    if (activePlan == null) {
      return Center(child: Text('No active diet plan assigned.', style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor)));
    }

    final vitals = state.clinicalVitals;
    final guidelines = vitals?.clinicalGuidelines ?? {};

    final bool isWeekly = activePlan.allItems.map((e) => e.dayId).toSet().length > 1;
    List<FlatDietPlanItem> itemsForSelectedDay = [];

    if (activePlan.allItems.isNotEmpty) {
      if (isWeekly) {
        final selectedDayName = DateFormat('EEEE').format(state.selectedDate).toLowerCase();
        final selectedDayIndex = "day ${state.selectedDate.weekday}";

        itemsForSelectedDay = activePlan.allItems.where((item) {
          final dbDay = item.dayName.trim().toLowerCase();
          return dbDay == selectedDayName || dbDay == selectedDayIndex;
        }).toList();

        if (itemsForSelectedDay.isEmpty) {
          final firstDayId = activePlan.allItems.first.dayId;
          itemsForSelectedDay = activePlan.allItems.where((i) => i.dayId == firstDayId).toList();
        }
      } else {
        itemsForSelectedDay = activePlan.allItems;
      }
    }

    final dailyRecord = state.dailyRecord;

    // 📅 DATE STRING LOGIC
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(state.selectedDate, now);
    final isYesterday = DateUtils.isSameDay(state.selectedDate, now.subtract(const Duration(days: 1)));
    final String dateString = isToday ? "TODAY" : (isYesterday ? "YESTERDAY" : DateFormat('MMM dd').format(state.selectedDate).toUpperCase());

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. 🚀 PREMIUM EDITORIAL HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(60), context.scale(20), context.scale(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end, // Align to bottom for elegant typography
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            "DAILY LOG",
                            style: TextStyle(
                              fontFamily: kBodyFont,
                              fontSize: context.scale(10),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: colorScheme.primary,
                            )
                        ),
                        SizedBox(height: context.scale(4)),
                        Text(
                            "Nutrition",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: kDisplayFont,
                              fontSize: context.scale(32), // Massive, elegant title
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.0, // Tighter tracking for Space Grotesk
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.0,
                            )
                        ),
                      ],
                    ),
                  ),

                  // 📅 SLEEK CALENDAR PILL
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: state.selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: colorScheme.copyWith(primary: colorScheme.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) notifier.selectDate(picked);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: context.scale(14), vertical: context.scale(10)),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(context.scale(12)),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_rounded, size: context.scale(14), color: isDark ? Colors.white70 : Colors.black54),
                          SizedBox(width: context.scale(8)),
                          Text(
                              dateString,
                              style: TextStyle(
                                fontFamily: kDisplayFont,
                                fontSize: context.scale(12),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.white : Colors.black87,
                              )
                          ),
                          SizedBox(width: context.scale(4)),
                          Icon(Icons.keyboard_arrow_down_rounded, size: context.scale(14), color: theme.hintColor.withOpacity(0.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. TIMELINE SUB-HEADER & PROTOCOL
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(16), context.scale(24), context.scale(24)),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.scale(6)),
                    decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.timeline_rounded, size: context.scale(14), color: colorScheme.primary),
                  ),
                  SizedBox(width: context.scale(12)),
                  Text(
                      "ITINERARY",
                      style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : Colors.black54)
                  ),

                  const Spacer(),

                  if (guidelines.isNotEmpty || activePlan.assignedHabits.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showProtocolSheet(context, guidelines, activePlan.assignedHabits, theme),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: context.scale(12), vertical: context.scale(6)),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(context.scale(20)),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.assignment_turned_in_rounded, size: context.scale(12), color: colorScheme.primary),
                            SizedBox(width: context.scale(6)),
                            Text("PROTOCOL", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w800, letterSpacing: 1.0, color: colorScheme.primary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. MEAL LIST OR LUXURY EMPTY STATE
          if (itemsForSelectedDay.isNotEmpty)
            _buildDailyMealList(context, itemsForSelectedDay, dailyRecord, activePlan, notifier, state.selectedDate)
          else
            SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.scale(40.0)),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.scale(24)),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.self_improvement_rounded, size: context.scale(48), color: theme.hintColor.withOpacity(0.3)),
                        ),
                        SizedBox(height: context.scale(24)),
                        Text("Metabolic Rest", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(24), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                        SizedBox(height: context.scale(8)),
                        Text("No formal meals are scheduled today.\nFocus on hydration and recovery.", textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(14), color: theme.hintColor, height: 1.5)),
                      ],
                    ),
                  ),
                )
            ),

          SliverPadding(padding: EdgeInsets.only(bottom: context.scale(120))),
        ],
      ),
    );
  }

  // ===========================================================================
  // 🚀 DIETITIAN GUIDELINES SHEET (EDITORIAL UPGRADE)
  // ===========================================================================
  void _showProtocolSheet(BuildContext context, Map<String, String> guidelines, List<String> habits, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 🚀 Glassmorphism added
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            padding: EdgeInsets.fromLTRB(ctx.scale(24), ctx.scale(12), ctx.scale(24), ctx.scale(32)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121826).withOpacity(0.95) : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.vertical(top: Radius.circular(ctx.scale(32))),
              border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: ctx.scale(32), height: ctx.scale(4), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(ctx.scale(2))))),
                  SizedBox(height: ctx.scale(32)),

                  // 🚀 EDITORIAL HEADER
                  Text("CLINICAL BRIEF", style: TextStyle(fontFamily: kBodyFont, fontSize: ctx.scale(10), fontWeight: FontWeight.w800, letterSpacing: 2.0, color: colorScheme.primary)),
                  SizedBox(height: ctx.scale(8)),
                  Text("Daily Protocol", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: ctx.scale(32), letterSpacing: -1.0, color: isDark ? Colors.white : Colors.black87)),

                  SizedBox(height: ctx.scale(32)),

                  // 📜 CONTENT AREA
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (habits.isNotEmpty) ...[
                            _buildSectionLabel(ctx, "CORE HABITS", theme),
                            SizedBox(height: ctx.scale(16)),
                            ...habits.map((habit) => Padding(
                              padding: EdgeInsets.only(bottom: ctx.scale(16.0)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      margin: EdgeInsets.only(top: ctx.scale(4)),
                                      width: ctx.scale(6), height: ctx.scale(6),
                                      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)
                                  ),
                                  SizedBox(width: ctx.scale(16)),
                                  Expanded(
                                    child: Text(habit, style: TextStyle(fontFamily: kBodyFont, fontSize: ctx.scale(15), height: 1.5, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87, fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                            )),
                            SizedBox(height: ctx.scale(32)),
                          ],

                          if (guidelines.isNotEmpty) ...[
                            _buildSectionLabel(ctx, "GUIDELINES", theme),
                            SizedBox(height: ctx.scale(16)),
                            ...guidelines.entries.map((e) => Padding(
                              padding: EdgeInsets.only(bottom: ctx.scale(24.0)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.key.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, fontSize: ctx.scale(12), letterSpacing: 1.0, color: isDark ? Colors.white : Colors.black87)),
                                  SizedBox(height: ctx.scale(8)),
                                  Text(e.value, style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, height: 1.6, fontSize: ctx.scale(14))),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11), fontWeight: FontWeight.w800, color: theme.hintColor.withOpacity(0.5), letterSpacing: 2.0)),
        SizedBox(height: context.scale(8)),
        Divider(color: theme.dividerColor.withOpacity(0.5), height: 1),
      ],
    );
  }

  // ===========================================================================
  // 🚀 MEAL LIST BUILDER
  // ===========================================================================
  Widget _buildDailyMealList(BuildContext context, List<FlatDietPlanItem> dayItems, ClientLogModel? dailyRecord, FlatClientDietPlanModel activePlan, DietPlanNotifier notifier, DateTime selectedDate) {
    final uniqueMealIds = dayItems.map((e) => e.mealId).toSet().toList();

    uniqueMealIds.sort((a, b) {
      final orderA = _safeInt(dayItems.firstWhere((i) => i.mealId == a).mealOrder);
      final orderB = _safeInt(dayItems.firstWhere((i) => i.mealId == b).mealOrder);
      return orderA.compareTo(orderB);
    });

    String? focusedMealId;
    if (DateUtils.isSameDay(selectedDate, DateTime.now())) {
      for (final id in uniqueMealIds) {
        final fItem = dayItems.firstWhere((i) => i.mealId == id);
        if (dailyRecord == null || !(dailyRecord.mealLogs.containsKey(fItem.mealName))) {
          focusedMealId = id;
          break;
        }
      }
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.scale(20)), // Slightly tighter for a cleaner list
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final mealId = uniqueMealIds[index];
            final allItemsInThisMeal = dayItems.where((i) => i.mealId == mealId).toList();
            final firstItem = allItemsInThisMeal.firstWhere(
                    (i) => i.itemType != DietItemType.alternative && i.itemType != DietItemType.bundleChild,
                orElse: () => allItemsInThisMeal.first
            );

            final mealName = firstItem.mealName;
            final mealTime = firstItem.mealTime;

            MealEntry? mealLog;
            if (dailyRecord != null && dailyRecord.mealLogs.isNotEmpty) {
              final searchKey = mealName.trim().toLowerCase();
              for (var entry in dailyRecord.mealLogs.entries) {
                if (entry.key.trim().toLowerCase() == searchKey) {
                  mealLog = entry.value;
                  break;
                }
              }
            }
            return Padding(
              padding: EdgeInsets.only(bottom: context.scale(16)), // Replaced generic spacing
              child: EliteMealCard(
                mealName: mealName,
                mealTime: mealTime,
                mealItems: allItemsInThisMeal,
                mealLog: mealLog,
                isFocused: mealId == focusedMealId,
                isOverdue: _isMealOverdue(mealTime, selectedDate),
                notifier: notifier,
                activePlan: activePlan,
                onQuickLog: () => _showImageSourceSelector(context, notifier, mealName),
              ),
            );
          },
          childCount: uniqueMealIds.length,
        ),
      ),
    );
  }

  bool _isMealOverdue(String? timeStr, DateTime selectedDate) { /* Unchanged Logic */
    if (timeStr == null || timeStr.isEmpty) return false;
    final now = DateTime.now();
    if (selectedDate.year < now.year || (selectedDate.year == now.year && selectedDate.month < now.month) || (selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day < now.day)) return true;
    if (!DateUtils.isSameDay(selectedDate, now)) return false;
    try {
      final cleanStr = timeStr.trim().toUpperCase();
      final isPM = cleanStr.contains("PM");
      final timePart = cleanStr.replaceAll("AM", "").replaceAll("PM", "").trim();
      final parts = timePart.split(":");
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      final mealTime = DateTime(now.year, now.month, now.day, hour, minute);
      return now.isAfter(mealTime.add(const Duration(minutes: 30)));
    } catch (e) { return false; }
  }

  int _safeInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  // ===========================================================================
  // 📸 PREMIUM IMAGE SOURCE SELECTOR (FLOATING CARDS)
  // ===========================================================================
  void _showImageSourceSelector(BuildContext context, DietPlanNotifier notifier, String mealName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final neonGreen = const Color(0xFF00E676);

    final Map<String, dynamic> defaultAdherentPayload = {
      'mealLogs': {
        mealName: {
          'status': 'completed',
          'isDeviation': false,
          'loggedAt': DateTime.now().toIso8601String(),
        }
      }
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(ctx.scale(24), ctx.scale(24), ctx.scale(24), ctx.scale(40)),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121826) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(ctx.scale(32))),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("LOG MEAL", style: TextStyle(fontFamily: kBodyFont, fontSize: ctx.scale(10), fontWeight: FontWeight.w800, letterSpacing: 2.0, color: theme.hintColor)),
                SizedBox(height: ctx.scale(8)),
                Text("Select Source", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(24), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                SizedBox(height: ctx.scale(32)),

                // 🚀 BEAUTIFUL TOUCH CARDS INSTEAD OF LIST TILES
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final photo = await ImageHelperService.pickAndCompressToWebP(source: ImageSource.camera);
                          if (photo != null) {
                            notifier.updateDailyRecord(data: defaultAdherentPayload, newPhotos: [photo], mealNameForPhotos: mealName);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: ctx.scale(24)),
                          decoration: BoxDecoration(
                            color: neonGreen.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(ctx.scale(20)),
                            border: Border.all(color: neonGreen.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.camera_alt_rounded, size: ctx.scale(32), color: neonGreen),
                              SizedBox(height: ctx.scale(12)),
                              Text("Camera", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(16), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: ctx.scale(16)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final photo = await ImageHelperService.pickAndCompressToWebP(source: ImageSource.gallery);
                          if (photo != null) {
                            notifier.updateDailyRecord(data: defaultAdherentPayload, newPhotos: [photo], mealNameForPhotos: mealName);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: ctx.scale(24)),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(ctx.scale(20)),
                            border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library_rounded, size: ctx.scale(32), color: colorScheme.primary),
                              SizedBox(height: ctx.scale(12)),
                              Text("Gallery", style: TextStyle(fontFamily: kDisplayFont, fontSize: ctx.scale(16), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}