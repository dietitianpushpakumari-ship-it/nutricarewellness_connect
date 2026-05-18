import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/new/dietplan/diet_plan_viewer.dart';
import 'package:pure_shift/new/dietplan/meal_detail_sheet.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

// 🚀 1. INDEPENDENT DATE STATE JUST FOR THIS SCREEN
final planDateProvider = StateProvider.autoDispose<DateTime>((ref) => DateTime.now());

class PlanTimelineScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanTimelineScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 2. READ THE INDEPENDENT DATE
    final localDate = ref.watch(planDateProvider);

    final state = ref.watch(dietPlanNotifierProvider(client.id));
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (state.isLoading || !DateUtils.isSameDay(localDate, state.selectedDate)) {
      return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(child: CircularProgressIndicator(color: colorScheme.primary))
      );
    }

    final activePlan = state.activePlan;
    if (state.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (activePlan == null) return const Scaffold(body: Center(child: Text("No Plan Assigned")));

    final vitals = state.clinicalVitals;
    final guidelines = vitals?.clinicalGuidelines ?? {};

    // =========================================================================
    // 🚀 3. EXTRACT UNIQUE MEALS (USING LOCAL DATE)
    // =========================================================================
    final String dayName = DateFormat('EEEE').format(localDate).toLowerCase();
    final String dayIndex = "day ${localDate.weekday}";
    final dayItems = activePlan.allItems.where((i) => i.dayName.trim().toLowerCase() == dayName || i.dayName.trim().toLowerCase() == dayIndex).toList();

    if (dayItems.isEmpty && activePlan.allItems.isNotEmpty) {
      dayItems.addAll(activePlan.allItems.where((i) => i.dayId == activePlan.allItems.first.dayId));
    }

    final uniqueMealIds = dayItems.map((e) => e.mealId).toSet().toList();
    uniqueMealIds.sort((a, b) => _safeInt(dayItems.firstWhere((i) => i.mealId == a).mealOrder).compareTo(_safeInt(dayItems.firstWhere((i) => i.mealId == b).mealOrder)));

    final dailyRecord = state.dailyRecord;

    // =========================================================================
    // 🚀 4. INBOX ZERO SORTING
    // =========================================================================
    List<String> loggedIds = [];
    List<String> unloggedIds = [];

    for (String mId in uniqueMealIds) {
      final fItem = dayItems.firstWhere((i) => i.mealId == mId);
      final mealLog = dailyRecord?.mealLogs[fItem.mealName.trim().toLowerCase()] ?? dailyRecord?.mealLogs[fItem.mealName.trim()];

      if (mealLog != null) {
        loggedIds.add(mId);
      } else {
        unloggedIds.add(mId);
      }
    }

    // 🚀 5. DATE STRING (USING LOCAL DATE)
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(localDate, now);
    final isYesterday = DateUtils.isSameDay(localDate, now.subtract(const Duration(days: 1)));
    final dateString = isToday ? "TODAY" : (isYesterday ? "YESTERDAY" : DateFormat('MMM dd').format(localDate).toUpperCase());

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ===================================================================
          // 1. SINGLE LINE NANO HEADER
          // ===================================================================
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(context.scale(20), context.scale(50), context.scale(20), context.scale(16)),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121826) : theme.scaffoldBackgroundColor,
                border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // 🚀 TITLE PUSHED TO TOP
                  Text(
                  "LOGBOOK",
                  style: TextStyle(
                      fontFamily: kDisplayFont,
                      fontSize: context.scale(14).clamp(12.0, 16.0),
                      fontWeight: FontWeight.w800, // Slightly bolder
                      letterSpacing: 2.5, // Increased tracking for a premium feel
                      color: colorScheme.onSurface.withOpacity(0.6) // Slightly muted
                  )
              ),

              SizedBox(height: context.scale(16)),Row(
                children: [
               //

                  _buildProgressIndicator(context, uniqueMealIds.length, loggedIds.length, colorScheme),
                  SizedBox(width: context.scale(6)),

                  _buildHeaderTool(context, Icons.calendar_today_rounded, dateString, colorScheme, isDark, theme, () async {
                    HapticFeedback.selectionClick();

                    // 🚀 6. CALCULATE 5-DAY GRACE PERIOD
                    final firstAllowedDate = now.subtract(const Duration(days: 5));
                    final safeInitialDate = localDate.isBefore(firstAllowedDate) ? firstAllowedDate : localDate;

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: safeInitialDate,
                      firstDate: firstAllowedDate, // 🚀 Blocks past 5 days
                      lastDate: now,               // 🚀 Blocks future dates
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: colorScheme.copyWith(
                              primary: const Color(0xFF00E676),
                              onPrimary: Colors.black,
                              surface: isDark ? const Color(0xFF121826) : Colors.white,
                              onSurface: isDark ? Colors.white : Colors.black,
                            ),
                            dialogTheme: DialogThemeData(
                              backgroundColor: isDark ? const Color(0xFF121826) : Colors.white,
                              elevation: 24,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                          child: Material(
                            type: MaterialType.canvas,
                            color: isDark ? const Color(0xFF121826) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            child: child!,
                          ),
                        );
                      },
                    );

                    if (picked != null) {
                      // 🚀 7. UPDATE LOCAL DATE & FETCH
                      ref.read(planDateProvider.notifier).state = picked;
                      notifier.selectDate(picked); // Make sure this fetches without altering Home!
                    }
                  }),
                  SizedBox(width: context.scale(6)),

                  if (guidelines.isNotEmpty || activePlan.assignedHabits.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showProtocolSheet(context, guidelines, activePlan.assignedHabits, theme),
                      child: Container(padding: EdgeInsets.all(context.scale(7)), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.star_rounded, color: Colors.orangeAccent, size: context.scale(16).clamp(14.0, 18.0))),
                    ),
                    SizedBox(width: context.scale(6)),
                  ],

                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => DietPlanViewerSheet(
                          plan: state.activePlan,
                          vitals: state.clinicalVitals,
                        )),
                    child: Container(padding: EdgeInsets.all(context.scale(7)), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.picture_as_pdf_rounded, color: const Color(0xFF9F1239), size: context.scale(16).clamp(14.0, 18.0))),
                  ),
                ],
              ),]),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: context.scale(16))),

          // ===================================================================
          // 2. PENDING MEALS
          // ===================================================================
          if (unloggedIds.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(context.scale(20), 0, context.scale(20), context.scale(12)),
                child: Text("PENDING MEALS", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12).clamp(11.0, 14.0), fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor)),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: context.scale(20)),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final uId = unloggedIds[index];
                    // 🚀 Pass localDate for overdue calculation
                    return _buildPendingCard(context, uId, dayItems, colorScheme, isDark, theme, notifier, activePlan, localDate);
                  },
                  childCount: unloggedIds.length,
                ),
              ),
            ),
          ] else if (uniqueMealIds.isNotEmpty)
          // ALL DONE STATE
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: context.scale(20), bottom: context.scale(40)),
                child: Column(
                  children: [
                    Icon(Icons.verified_rounded, size: context.scale(50).clamp(40.0, 60.0), color: const Color(0xFF00E676).withOpacity(0.8)),
                    SizedBox(height: context.scale(16)),
                    Text("ALL CAUGHT UP", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14).clamp(12.0, 16.0), fontWeight: FontWeight.w700, letterSpacing: 2.0, color: colorScheme.onSurface)),
                    SizedBox(height: context.scale(4)),
                    Text("You have verified all meals for this day.", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(14).clamp(12.0, 16.0), color: theme.hintColor)),
                  ],
                ),
              ),
            ),

          // ===================================================================
          // 3. THE VAULT / JOURNAL
          // ===================================================================
          if (loggedIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: context.scale(24)),
                child: _buildLoggedVault(context, loggedIds, dayItems, dailyRecord, colorScheme, isDark, theme, notifier, activePlan),
              ),
            ),

          SliverPadding(padding: EdgeInsets.only(bottom: context.scale(120))),
        ],
      ),
    );
  }

  // ===========================================================================
  // 🚀 WIDGET: ULTRA-COMPACT PENDING MEAL CARD
  // ===========================================================================
  Widget _buildPendingCard(BuildContext context, String mealId, List<FlatDietPlanItem> dayItems, ColorScheme color, bool isDark, ThemeData theme, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan, DateTime selectedDate) {
    final mealItems = dayItems.where((i) => i.mealId == mealId).toList();
    final firstItem = mealItems.first;

    final String formattedTime = _formatTimeAMPM(firstItem.mealTime);
    final bool isOverdue = _isMealOverdue(firstItem.mealTime, selectedDate);

    // 🚀 PREMIUM OVERDUE COLOR (Terracotta/Warm Coral instead of harsh red)
    final Color premiumOverdueColor = isDark ? const Color(0xFFE57373) : const Color(0xFFD97757);

    return Container(
      margin: EdgeInsets.only(bottom: context.scale(10)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121826) : Colors.white,
        borderRadius: BorderRadius.circular(context.scale(12)),
        // Subtle border instead of bright red
        border: Border.all(color: isOverdue ? premiumOverdueColor.withOpacity(0.4) : (isDark ? Colors.white10 : Colors.black12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(context.scale(12)),
          onTap: () {
            HapticFeedback.selectionClick();
            _openLoggingSheet(context, firstItem.mealName, notifier, activePlan, mealItems, null);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.scale(12), horizontal: context.scale(16)),
            child: Row(
              children: [
                isOverdue
                    ? _PulsingOverdueIcon(context: context, pulseColor: premiumOverdueColor) // Pass the color down
                    : Container(
                  padding: EdgeInsets.all(context.scale(8)),
                  decoration: BoxDecoration(color: color.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.restaurant_rounded, size: context.scale(16).clamp(14.0, 18.0), color: color.primary),
                ),
                SizedBox(width: context.scale(14)),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          children: [
                            Text(
                                formattedTime,
                                style: TextStyle(
                                    fontFamily: kDisplayFont,
                                    fontSize: context.scale(11).clamp(10.0, 12.0),
                                    fontWeight: FontWeight.w700,
                                    color: isOverdue ? theme.hintColor.withOpacity(0.6) : color.primary,
                                    letterSpacing: 1.0
                                )
                            ),
                            if (isOverdue) ...[
                              SizedBox(width: context.scale(6)),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: context.scale(6), vertical: context.scale(2)),
                                decoration: BoxDecoration(
                                    color: premiumOverdueColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(context.scale(4)),
                                    border: Border.all(color: premiumOverdueColor.withOpacity(0.2)) // Added a tiny border for crispness
                                ),
                                child: Text(
                                    "PENDING", // Changed from "OVERDUE" to feel less aggressive
                                    style: TextStyle(
                                        fontFamily: kDisplayFont,
                                        fontSize: context.scale(9).clamp(8.0, 10.0),
                                        fontWeight: FontWeight.w800,
                                        color: premiumOverdueColor,
                                        letterSpacing: 0.5
                                    )
                                ),
                              ),
                            ],
                          ]
                      ),
                      SizedBox(height: context.scale(4)),
                      Text(
                          firstItem.mealName.toUpperCase(),
                          style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14).clamp(13.0, 16.0), fontWeight: FontWeight.w700, color: color.onSurface, letterSpacing: -0.5)
                      ),
                    ],
                  ),
                ),

                Icon(Icons.add_a_photo_rounded, size: context.scale(20).clamp(18.0, 24.0), color: color.primary.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ===========================================================================
  // 🚀 WIDGET: THE LOGGED VAULT
  // ===========================================================================
  Widget _buildLoggedVault(BuildContext context, List<String> loggedIds, List<FlatDietPlanItem> dayItems, ClientLogModel? dailyRecord, ColorScheme color, bool isDark, ThemeData theme, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(context.scale(20), 0, context.scale(20), context.scale(16)),
          child: Text("TODAY'S JOURNAL", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12).clamp(11.0, 14.0), fontWeight: FontWeight.w700, letterSpacing: 1.5, color: const Color(0xFF00E676))),
        ),

        ...loggedIds.map((mId) {
          final mealItems = dayItems.where((i) => i.mealId == mId).toList();
          final firstItem = mealItems.first;
          final mealLog = dailyRecord?.mealLogs[firstItem.mealName.trim().toLowerCase()] ?? dailyRecord?.mealLogs[firstItem.mealName.trim()];

          return _buildJournalCard(context, firstItem, mealItems, mealLog, color, isDark, theme, notifier, activePlan);
        }).toList(),
      ],
    );
  }

  // ===========================================================================
  // 📸 WIDGET: PREMIUM FULL-BLEED JOURNAL CARD
  // ===========================================================================
  Widget _buildJournalCard(BuildContext context, FlatDietPlanItem firstItem, List<FlatDietPlanItem> mealItems, MealEntry? mealLog, ColorScheme color, bool isDark, ThemeData theme, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan) {
    final List<dynamic> rawPhotos = mealLog?.mealPhotoUrls ?? mealLog?.mealPhotoUrls ?? [];
    final List<String> photos = rawPhotos.map((e) => e.toString()).toList();
    final String? coverImage = photos.isNotEmpty ? photos.last : null;

    final String statusStr = mealLog?.status.name ?? 'followed';
    final bool isSkipped = statusStr == 'skipped';
    final bool isDeviated = statusStr == 'deviated';

    Color statusColor = const Color(0xFF00E676);
    String statusText = "VERIFIED";
    IconData statusIcon = Icons.verified_rounded;

    if (isSkipped) {
      statusColor = Colors.grey.shade600;
      statusText = "SKIPPED";
      statusIcon = Icons.block_rounded;
    } else if (isDeviated) {
      statusColor = Colors.orange.shade700;
      statusText = "DEVIATED";
      statusIcon = Icons.error_outline_rounded;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _openLoggingSheet(context, firstItem.mealName, notifier, activePlan, mealItems, mealLog);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: context.scale(16), left: context.scale(20), right: context.scale(20)),
        height: context.scale(130),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2232) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(context.scale(16)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.scale(16)),
          child: Stack(
            children: [
              if (coverImage != null && !isSkipped)
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CachedNetworkImage(imageUrl: coverImage, fit: BoxFit.cover),
                )
              else
                Center(child: Icon(Icons.restaurant_rounded, size: context.scale(40).clamp(32.0, 48.0), color: theme.dividerColor.withOpacity(0.5))),

              if (coverImage != null && !isSkipped)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),

              // STATUS PILL
              Positioned(
                top: context.scale(12), left: context.scale(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(4)),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.9), borderRadius: BorderRadius.circular(context.scale(8))),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: context.scale(12).clamp(10.0, 14.0), color: Colors.white),
                      SizedBox(width: context.scale(4)),
                      Text(statusText, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10).clamp(9.0, 11.0), fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),

              // MULTI-PHOTO BADGE
              if (photos.length > 1)
                Positioned(
                  top: context.scale(12), right: context.scale(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(4)),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(context.scale(8)),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.photo_library_rounded, size: context.scale(12).clamp(10.0, 14.0), color: Colors.white),
                        SizedBox(width: context.scale(4)),
                        Text("+${photos.length - 1}", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10).clamp(9.0, 11.0), fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

              // MEAL INFO
              Positioned(
                bottom: context.scale(12), left: context.scale(16), right: context.scale(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              _formatTimeAMPM(firstItem.mealTime),
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11).clamp(10.0, 12.0), fontWeight: FontWeight.w700, color: coverImage != null ? Colors.white70 : color.primary, letterSpacing: 1.0)
                          ),
                          SizedBox(height: context.scale(2)),
                          Text(
                            firstItem.mealName.toUpperCase(),
                            style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14).clamp(13.0, 16.0), fontWeight: FontWeight.w700, color: coverImage != null ? Colors.white : color.onSurface, letterSpacing: -0.5),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_rounded, size: context.scale(16).clamp(14.0, 18.0), color: coverImage != null ? Colors.white54 : theme.hintColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLoggingSheet(BuildContext context, String mealName, DietPlanNotifier notifier, FlatClientDietPlanModel plan, List<FlatDietPlanItem> items, MealEntry? log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealDetailSheet(
        notifier: notifier,
        mealName: mealName,
        activePlan: plan,
        plannedItems: items,
        logToEdit: log,
      ),
    );
  }

  String _formatTimeAMPM(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return "--:--";
    try {
      if (timeStr.toUpperCase().contains("AM") || timeStr.toUpperCase().contains("PM")) return timeStr.toUpperCase();
      final parts = timeStr.split(":");
      int h = int.parse(parts[0].trim());
      int m = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
      final dt = DateTime(2022, 1, 1, h, m);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  bool _isMealOverdue(String? timeStr, DateTime selectedDate) {
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

  Widget _buildHeaderTool(BuildContext context, IconData icon, String label, ColorScheme color, bool isDark, ThemeData theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.scale(10), vertical: context.scale(6)),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(context.scale(6))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.scale(12).clamp(10.0, 14.0), color: color.onSurface),
            SizedBox(width: context.scale(6)),
            Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11).clamp(10.0, 12.0), fontWeight: FontWeight.w700, color: color.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, int total, int completed, ColorScheme color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.scale(10), vertical: context.scale(6)),
      decoration: BoxDecoration(color: color.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(context.scale(6))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: context.scale(14), height: context.scale(14),
              child: CircularProgressIndicator(value: total > 0 ? (completed / total) : 0, strokeWidth: 2, backgroundColor: color.primary.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(color.primary))
          ),
          SizedBox(width: context.scale(8)),
          Text("$completed/$total", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12).clamp(11.0, 14.0), fontWeight: FontWeight.w700, color: color.primary)),
        ],
      ),
    );
  }

  int _safeInt(dynamic val) => val is int ? val : (int.tryParse(val?.toString() ?? '0') ?? 0);

  // ===========================================================================
  // 🚀 GUIDELINES SHEET
  // ===========================================================================
  void _showProtocolSheet(BuildContext context, Map<String, String> guidelines, List<String> habits, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: EdgeInsets.fromLTRB(context.scale(20), context.scale(12), context.scale(20), 0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121826) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(24))),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: context.scale(32), height: context.scale(4), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(context.scale(2))))),
                SizedBox(height: context.scale(20)),

                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.scale(8)),
                      decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.verified_user_rounded, color: colorScheme.primary, size: context.scale(20).clamp(18.0, 24.0)),
                    ),
                    SizedBox(width: context.scale(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("DAILY PROTOCOL", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: context.scale(14).clamp(13.0, 16.0), letterSpacing: 1.5, color: colorScheme.onSurface)),
                          Text("Core principles for success", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(13).clamp(12.0, 14.0), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, size: context.scale(24).clamp(20.0, 28.0), color: theme.hintColor)),
                  ],
                ),
                SizedBox(height: context.scale(24)),

                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: context.scale(40)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (habits.isNotEmpty) ...[
                          _buildSectionLabel(context, "CORE HABITS", theme),
                          SizedBox(height: context.scale(12)),
                          Container(
                            padding: EdgeInsets.all(context.scale(16)),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(context.scale(16)),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: habits.map((habit) => Padding(
                                padding: EdgeInsets.only(bottom: context.scale(12.0)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(padding: EdgeInsets.only(top: context.scale(2.0)), child: Icon(Icons.star_rounded, size: context.scale(16).clamp(14.0, 18.0), color: colorScheme.primary)),
                                    SizedBox(width: context.scale(12)),
                                    Expanded(
                                      child: Text(habit, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(16).clamp(15.0, 18.0), height: 1.4, color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                          SizedBox(height: context.scale(24)),
                        ],

                        if (guidelines.isNotEmpty) ...[
                          _buildSectionLabel(context, "CLINICAL GUIDELINES", theme),
                          SizedBox(height: context.scale(12)),
                          ...guidelines.entries.map((e) => Padding(
                            padding: EdgeInsets.only(bottom: context.scale(12.0)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(padding: EdgeInsets.only(top: context.scale(2.0)), child: Icon(Icons.medical_information_rounded, size: context.scale(16).clamp(14.0, 18.0), color: Colors.blueAccent.shade200)),
                                SizedBox(width: context.scale(12)),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, height: 1.5, fontSize: context.scale(16).clamp(15.0, 18.0)),
                                      children: [
                                        TextSpan(text: "${e.key}: ", style: const TextStyle(fontWeight: FontWeight.w700)),
                                        TextSpan(text: e.value, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
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
        );
      },
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12).clamp(11.0, 14.0), fontWeight: FontWeight.w700, color: theme.hintColor.withOpacity(0.6), letterSpacing: 1.2),
    );
  }
}


// ===========================================================================
// 🚀 SUBTLE BREATHING ANIMATION FOR PENDING MEALS
// ===========================================================================
class _PulsingOverdueIcon extends StatefulWidget {
  final BuildContext context;
  final Color pulseColor; // 🚀 Added to accept the premium color
  const _PulsingOverdueIcon({Key? key, required this.context, required this.pulseColor}) : super(key: key);

  @override
  State<_PulsingOverdueIcon> createState() => _PulsingOverdueIconState();
}

class _PulsingOverdueIconState extends State<_PulsingOverdueIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 🚀 Slowed down to 3 seconds for a luxurious, calm "breathing" effect
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    // 🚀 Narrowed the opacity range so it doesn't flash too bright
    _animation = Tween<double>(begin: 0.05, end: 0.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(widget.context.scale(8)),
          decoration: BoxDecoration(
            color: widget.pulseColor.withOpacity(_animation.value),
            shape: BoxShape.circle,
            border: Border.all(color: widget.pulseColor.withOpacity(0.2)), // Crisp subtle edge
          ),
          child: Icon(Icons.restaurant_rounded, size: widget.context.scale(16).clamp(14.0, 18.0), color: widget.pulseColor),
        );
      },
    );
  }
}