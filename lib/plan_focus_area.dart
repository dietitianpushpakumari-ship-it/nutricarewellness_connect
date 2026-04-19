import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/new/dietplan/diet_plan_viewer.dart';
import 'package:pure_shift/new/dietplan/meal_detail_sheet.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class PlanTimelineScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanTimelineScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dietPlanNotifierProvider(client.id));
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final activePlan = state.activePlan;
    if (state.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (activePlan == null) return const Scaffold(body: Center(child: Text("No Plan Assigned")));

    final vitals = state.clinicalVitals;
    final guidelines = vitals?.clinicalGuidelines ?? {};

    // =========================================================================
    // 🚀 1. EXTRACT UNIQUE MEALS FOR THE DAY
    // =========================================================================
    final String dayName = DateFormat('EEEE').format(state.selectedDate).toLowerCase();
    final String dayIndex = "day ${state.selectedDate.weekday}";
    final dayItems = activePlan.allItems.where((i) => i.dayName.trim().toLowerCase() == dayName || i.dayName.trim().toLowerCase() == dayIndex).toList();

    if (dayItems.isEmpty && activePlan.allItems.isNotEmpty) {
      dayItems.addAll(activePlan.allItems.where((i) => i.dayId == activePlan.allItems.first.dayId));
    }

    final uniqueMealIds = dayItems.map((e) => e.mealId).toSet().toList();
    uniqueMealIds.sort((a, b) => _safeInt(dayItems.firstWhere((i) => i.mealId == a).mealOrder).compareTo(_safeInt(dayItems.firstWhere((i) => i.mealId == b).mealOrder)));

    final dailyRecord = state.dailyRecord;

    // =========================================================================
    // 🚀 2. INBOX ZERO SORTING
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

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(state.selectedDate, now);
    final dateString = isToday ? "TODAY" : (DateUtils.isSameDay(state.selectedDate, now.subtract(const Duration(days: 1))) ? "YESTERDAY" : DateFormat('MMM dd').format(state.selectedDate).toUpperCase());

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
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121826) : theme.scaffoldBackgroundColor,
                border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Text("LOGBOOK", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: colorScheme.onSurface)),
                  const Spacer(),

                  _buildProgressIndicator(uniqueMealIds.length, loggedIds.length, colorScheme),
                  const SizedBox(width: 6),

                  _buildHeaderTool(Icons.calendar_today_rounded, dateString, colorScheme, isDark, theme, () async {
                    HapticFeedback.selectionClick();

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: state.selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: colorScheme.copyWith(
                              primary: const Color(0xFF00E676),    // Selected date circle
                              onPrimary: Colors.black,             // Text on selected date
                              surface: isDark ? const Color(0xFF121826) : Colors.white, // Solid Dialog Bg
                              onSurface: isDark ? Colors.white : Colors.black,          // Text color
                            ),
                            dialogTheme: DialogThemeData(
                              backgroundColor: isDark ? const Color(0xFF121826) : Colors.white,
                              elevation: 24,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                          // 🚀 THE ULTIMATE FIX: Force a solid Material backing
                          child: Material(
                            type: MaterialType.canvas,
                            color: isDark ? const Color(0xFF121826) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            child: child!,
                          ),
                        );
                      },
                    );

                    if (picked != null) notifier.selectDate(picked);
                  }),     const SizedBox(width: 6),

                  if (guidelines.isNotEmpty || activePlan.assignedHabits.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showProtocolSheet(context, guidelines, activePlan.assignedHabits, theme),
                      child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.star_rounded, color: Colors.orangeAccent, size: 14)),
                    ),
                    const SizedBox(width: 6),
                  ],

                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true, // Necessary for the 90% height container
                        backgroundColor: Colors.transparent, // Background handled by the Container
                        builder: (context) => DietPlanViewerSheet(
                          plan: state.activePlan,
                          vitals: state.clinicalVitals,
                        )),
                    child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF9F1239), size: 14)),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ===================================================================
          // 2. PENDING MEALS (Always at the Top for Instant Action)
          // ===================================================================
          if (unloggedIds.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text("PENDING MEALS", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final uId = unloggedIds[index];
                    return _buildPendingCard(context, uId, dayItems, colorScheme, isDark, theme, notifier, activePlan, state.selectedDate);
                  },
                  childCount: unloggedIds.length,
                ),
              ),
            ),
          ] else if (uniqueMealIds.isNotEmpty)
          // ALL DONE STATE (Shown at top if nothing is pending)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 40),
                child: Column(
                  children: [
                    Icon(Icons.verified_rounded, size: 50, color: const Color(0xFF00E676).withOpacity(0.8)),
                    const SizedBox(height: 16),
                    Text("ALL CAUGHT UP", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0, color: colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text("You have verified all meals for this day.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor)),
                  ],
                ),
              ),
            ),

          // ===================================================================
          // 3. THE VAULT / JOURNAL (Builds downwards as you log)
          // ===================================================================
          if (loggedIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _buildLoggedVault(context, loggedIds, dayItems, dailyRecord, colorScheme, isDark, theme, notifier, activePlan),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121826) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? Colors.redAccent.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.black12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            _openLoggingSheet(context, firstItem.mealName, notifier, activePlan, mealItems, null);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                // Minimalist Icon (Pulses if overdue)
                isOverdue
                    ? const _PulsingOverdueIcon()
                    : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.restaurant_rounded, size: 16, color: color.primary),
                ),
                const SizedBox(width: 14),

                // Meal Info
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    // 🚀 Time fades to grey if overdue, otherwise stays primary
                                    color: isOverdue ? Colors.grey.shade500 : color.primary,
                                    letterSpacing: 1.0
                                )
                            ),
                            if (isOverdue) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4)
                                ),
                                child: const Text(
                                    "OVERDUE",
                                    style: TextStyle(
                                        fontFamily: kDisplayFont,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700, // Bumped to w700 for better contrast
                                        color: Colors.redAccent,
                                        letterSpacing: 0.5
                                    )
                                ),
                              ),
                            ],
                          ]
                      ),
                      const SizedBox(height: 2),
                      Text(firstItem.mealName.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w500, color: color.onSurface, letterSpacing: -0.5)),
                    ],
                  ),
                ),

                // Subtle Capture Hint
                Icon(Icons.add_a_photo_rounded, size: 18, color: color.primary.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🚀 WIDGET: THE LOGGED VAULT (Vertical Photo Journal)
  // ===========================================================================
  Widget _buildLoggedVault(BuildContext context, List<String> loggedIds, List<FlatDietPlanItem> dayItems, ClientLogModel? dailyRecord, ColorScheme color, bool isDark, ThemeData theme, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text("TODAY'S JOURNAL", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: const Color(0xFF00E676))),
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

    // Determine Adherence Status
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
        margin: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
        height: 120, // Tighter height so it doesn't eat the whole screen
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2232) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // FULL BLEED PHOTO
              if (coverImage != null && !isSkipped)
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CachedNetworkImage(imageUrl: coverImage, fit: BoxFit.cover),
                )
              else
                Center(child: Icon(Icons.restaurant_rounded, size: 40, color: theme.dividerColor.withOpacity(0.5))),

              // DARK GRADIENT FOR READABILITY
              if (coverImage != null && !isSkipped)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),

              // STATUS PILL (Top Left)
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 10, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(statusText, style: const TextStyle(fontFamily: kDisplayFont, fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),

              // MULTI-PHOTO BADGE (Top Right)
              if (photos.length > 1)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                        const SizedBox(width: 4),
                        Text("+${photos.length - 1}", style: const TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

              // MEAL INFO (Bottom)
              Positioned(
                bottom: 12, left: 16, right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              _formatTimeAMPM(firstItem.mealTime),
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: coverImage != null ? Colors.white70 : color.primary, letterSpacing: 1.0)
                          ),
                          const SizedBox(height: 2),
                          Text(
                            firstItem.mealName.toUpperCase(),
                            style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, color: coverImage != null ? Colors.white : color.onSurface, letterSpacing: -0.5),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_rounded, size: 14, color: coverImage != null ? Colors.white54 : theme.hintColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🚀 LOGIC: OPEN YOUR CUSTOM MEAL DETAIL SHEET
  // ===========================================================================
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

  // ===========================================================================
  // 🚀 TIME & OVERDUE HELPERS
  // ===========================================================================
  String _formatTimeAMPM(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return "--:--";
    try {
      if (timeStr.toUpperCase().contains("AM") || timeStr.toUpperCase().contains("PM")) {
        return timeStr.toUpperCase();
      }
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

    if (selectedDate.year < now.year || (selectedDate.year == now.year && selectedDate.month < now.month) || (selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day < now.day)) {
      return true;
    }
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
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 🚀 UI HELPERS
  // ===========================================================================
  Widget _buildHeaderTool(IconData icon, String label, ColorScheme color, bool isDark, ThemeData theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color.onSurface),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: color.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int total, int completed, ColorScheme color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(value: total > 0 ? (completed / total) : 0, strokeWidth: 2, backgroundColor: color.primary.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(color.primary))
          ),
          const SizedBox(width: 8),
          Text("$completed/$total", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: color.primary)),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), // Removed bottom padding since we use SafeArea
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121826) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🛠️ DRAG HANDLE
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 🚀 COMPACT HEADER
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user_rounded, color: colorScheme.primary, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DAILY PROTOCOL",
                            style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.5, color: colorScheme.onSurface),
                          ),
                          Text(
                            "Core principles for success",
                            style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, size: 20, color: theme.hintColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 📜 CONTENT AREA
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    // Increased bottom padding here so text doesn't touch the screen edge
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (habits.isNotEmpty) ...[
                          _buildSectionLabel("CORE HABITS", theme),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: habits.map((habit) => Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(padding: const EdgeInsets.only(top: 2.0), child: Icon(Icons.star_rounded, size: 14, color: colorScheme.primary)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        habit,
                                        style: TextStyle(fontFamily: kBodyFont, fontSize: 11, height: 1.4, color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (guidelines.isNotEmpty) ...[
                          _buildSectionLabel("CLINICAL GUIDELINES", theme),
                          const SizedBox(height: 12),
                          ...guidelines.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(padding: const EdgeInsets.only(top: 2.0), child: Icon(Icons.medical_information_rounded, size: 14, color: Colors.blueAccent.shade200)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, height: 1.5, fontSize: 11),
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
// Helper for labels to keep things tidy
  Widget _buildSectionLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: kDisplayFont,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: theme.hintColor.withOpacity(0.6),
        letterSpacing: 1.2,
      ),
    );
  }
}

// ===========================================================================
// 🚀 SUBTLE BREATHING ANIMATION FOR OVERDUE MEALS
// ===========================================================================
class _PulsingOverdueIcon extends StatefulWidget {
  const _PulsingOverdueIcon({Key? key}) : super(key: key);

  @override
  State<_PulsingOverdueIcon> createState() => _PulsingOverdueIconState();
}

class _PulsingOverdueIconState extends State<_PulsingOverdueIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.05, end: 0.25).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.restaurant_rounded, size: 16, color: Colors.redAccent),
        );
      },
    );
  }
}