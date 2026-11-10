import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

final planDateProvider = StateProvider.autoDispose<DateTime>((ref) => DateTime.now());

// 🚀 NEW: Tracks deleted logs so they vanish instantly from the UI before Firebase syncs
final hiddenLogsProvider = StateProvider.autoDispose<Set<String>>((ref) => {});


class PlanTimelineScreen extends ConsumerWidget {
  final ClientModel client;
  const PlanTimelineScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final dailyRecord = state.dailyRecord;



    // 🚀 Watch the hidden logs
    final hiddenLogs = ref.watch(hiddenLogsProvider);

    // Extract ALL logged entries, filter out deleted ones, and sort them chronologically
    List<MapEntry<String, MealEntry>> sortedLogs = [];
    if (dailyRecord != null && dailyRecord.mealLogs.isNotEmpty) {
      sortedLogs = dailyRecord.mealLogs.entries
          .where((entry) => !hiddenLogs.contains(entry.key)) // 🚀 INSTANTLY hide swiped items
          .toList();

      sortedLogs.sort((a, b) {
        final dtA = a.value.loggedAt?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = b.value.loggedAt?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtA.compareTo(dtB);
      });
    }

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(localDate, now);
    final isYesterday = DateUtils.isSameDay(localDate, now.subtract(const Duration(days: 1)));
    final dateString = isToday ? "TODAY" : (isYesterday ? "YESTERDAY" : DateFormat('MMM dd').format(localDate).toUpperCase());

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. HEADER
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
                        Text(
                            "LOGBOOK",
                            style: TextStyle(
                                fontFamily: kDisplayFont,
                                fontSize: context.scale(14).clamp(12.0, 16.0),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                                color: colorScheme.onSurface.withOpacity(0.6)
                            )
                        ),
                        SizedBox(height: context.scale(16)),Row(
                          children: [
                            // Showing log count
                            _buildHeaderTool(context, Icons.photo_library_rounded, "${sortedLogs.length} LOGS", colorScheme, isDark, theme, () {}),
                            SizedBox(width: context.scale(6)),

                            _buildHeaderTool(context, Icons.calendar_today_rounded, dateString, colorScheme, isDark, theme, () async {
                              HapticFeedback.selectionClick();
                              final firstAllowedDate = now.subtract(const Duration(days: 5));
                              final safeInitialDate = localDate.isBefore(firstAllowedDate) ? firstAllowedDate : localDate;

                              final picked = await showDatePicker(
                                context: context,
                                initialDate: safeInitialDate,
                                firstDate: firstAllowedDate,
                                lastDate: now,
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
                                ref.read(planDateProvider.notifier).state = picked;
                                notifier.selectDate(picked);
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

              // 2. THE CHRONOLOGICAL JOURNAL
              if (sortedLogs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: context.scale(24)),
                    child: _buildChronologicalVault(context, ref,sortedLogs, colorScheme, isDark, theme, notifier, activePlan),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: context.scale(80)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera_back_rounded, size: context.scale(48).clamp(40.0, 60.0), color: theme.dividerColor.withOpacity(0.3)),
                        SizedBox(height: context.scale(16)),
                        Text(
                            "NO MEALS LOGGED YET",
                            style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14).clamp(12.0, 16.0), fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.5))
                        ),
                        SizedBox(height: context.scale(8)),
                        Text(
                            "Tap the camera button anytime to start your journal.",
                            style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(13).clamp(12.0, 14.0), color: theme.hintColor.withOpacity(0.5))
                        ),
                      ],
                    ),
                  ),
                ),

              SliverPadding(padding: EdgeInsets.only(bottom: context.scale(220))),
            ],
          ),

          // 🚀 GUARANTEED FLOATING CAPTURE BUTTON
          if (isToday)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.extended(
                  elevation: 8,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(30))),
                  icon: Icon(Icons.camera_alt_rounded, size: context.scale(20)),
                  label: Text(
                    "SNAP MEAL",
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: context.scale(13).clamp(12.0, 14.0),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();

                    // 🚀 Pure flexibility: Generate a completely unique key for the database
                    String uniqueKey = "Log ~${DateTime.now().millisecondsSinceEpoch}";
                    _openLoggingSheet(context, uniqueKey, notifier, activePlan, null);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChronologicalVault(BuildContext context,WidgetRef ref, List<MapEntry<String, MealEntry>> sortedLogs, ColorScheme color, bool isDark, ThemeData theme, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(context.scale(24), 0, context.scale(24), context.scale(24)),
          child: Text("TODAY'S JOURNAL", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12).clamp(11.0, 14.0), fontWeight: FontWeight.w700, letterSpacing: 2.0, color: theme.hintColor.withOpacity(0.5))),
        ),

        // 🚀 TIMELINE BUILDER
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
          child: Column(
            children: List.generate(sortedLogs.length, (index) {
              final entry = sortedLogs[index];
              final isLast = index == sortedLogs.length - 1;
              return _buildLuxuryTimelineNode(
                  context: context,
                  ref: ref,
                  mealName: entry.key,
                  mealLog: entry.value,
                  color: color,
                  isDark: isDark,
                  theme: theme,
                  notifier: notifier,
                  activePlan: activePlan,
                  isLast: isLast
              );
            }),
          ),
        ),
      ],
    );
  }

  // 💎 LUXURY TIMELINE NODE
  Widget _buildLuxuryTimelineNode({
    required BuildContext context,
    required WidgetRef ref,
    required String mealName,
    required MealEntry mealLog,
    required ColorScheme color,
    required bool isDark,
    required ThemeData theme,
    required DietPlanNotifier notifier,
    required FlatClientDietPlanModel activePlan,
    required bool isLast,
  }) {
    final List<dynamic> rawPhotos = mealLog.mealPhotoUrls;
    final List<String> photos = rawPhotos.map((e) => e.toString()).toList();
    final String? coverImage = photos.isNotEmpty ? photos.last : null;

    DateTime logTime = mealLog.loggedAt?.toLocal() ?? DateTime.now();
    final String timeString = DateFormat('hh:mm a').format(logTime);
    final String dateSubtext = DateFormat('MMM dd').format(logTime);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 1. LEFT SIDE: Elegant Typography Time
          SizedBox(
            width: context.scale(65), // 🚀 Increased width so it doesn't choke on 5 digits
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(height: context.scale(8)),

                // 🚀 FITTED BOX GUARANTEE: It will never cut off the text again.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    timeString.split(' ')[0], // "12:15"
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      fontSize: context.scale(16),
                      fontWeight: FontWeight.w800,
                      color: color.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                // 🚀 AM / PM stacked cleanly underneath
                Text(
                  timeString.split(' ')[1],
                  style: TextStyle(
                    fontFamily: kDisplayFont,
                    fontSize: context.scale(10),
                    fontWeight: FontWeight.w800,
                    color: color.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: context.scale(16)),

          // 2. MIDDLE: The Timeline Track (Dot + Line)
          Column(
            children: [
              SizedBox(height: context.scale(12)),
              Container(
                width: context.scale(12),
                height: context.scale(12),
                decoration: BoxDecoration(
                  color: color.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                  boxShadow: [BoxShadow(color: color.primary.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: EdgeInsets.only(top: context.scale(8), bottom: context.scale(8)),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()), // Keeps layout intact if last item
            ],
          ),

          SizedBox(width: context.scale(16)),

          // 3. RIGHT SIDE: The Sleek Media Card
          // 3. RIGHT SIDE: The Sleek Media Card (SWIPE TO DELETE)
          // 3. RIGHT SIDE: The Sleek Media Card (SWIPE TO DELETE)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : context.scale(32)),
              child: Dismissible(
                key: Key(mealName),
                direction: DismissDirection.endToStart,

                // 🚀 FIXED: Wrapped the background Column in a FittedBox with MainAxisSize.min
                background: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(context.scale(20)),
                  ),
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown, // 🚀 Prevents overflow when shrinking!
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // 🚀 Tells the column not to take infinite height
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.white, size: context.scale(28)),
                        SizedBox(height: context.scale(4)),
                        Text("DELETE", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),

                // 1. Ask for confirmation FIRST
                confirmDismiss: (direction) async {
                  HapticFeedback.heavyImpact();
                  return await _showDeleteDialog(context); // See updated dialog below
                },

                // 2. ONLY if confirmed, trigger the deletion after the card slides away
                onDismissed: (direction) {
                  // 🚀 Hide it locally INSTANTLY so Flutter's tree doesn't crash
                  ref.read(hiddenLogsProvider.notifier).update((state) {
                    final newState = Set<String>.from(state);
                    newState.add(mealName);
                    return newState;
                  });

                  // 🚀 Tell Firebase to delete it in the background
                  notifier.updateDailyRecord(data: {
                    'mealLogs.$mealName': FieldValue.delete(),
                  });
                },

                // ... (Keep the rest of your child: GestureDetector Container exactly the same!)

                // The actual Card UI
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _openLoggingSheet(context, mealName, notifier, activePlan, mealLog);
                  },
                  child: Container(
                    height: context.scale(140),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2232) : theme.cardColor,
                      borderRadius: BorderRadius.circular(context.scale(20)),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 15, offset: const Offset(0, 6))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(context.scale(20)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [

                          // Image or Placeholder
                          if (coverImage != null)
                            CachedNetworkImage(imageUrl: coverImage, fit: BoxFit.cover)
                          else
                            Container(
                              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                              child: Center(child: Icon(Icons.restaurant_rounded, size: context.scale(32), color: theme.dividerColor.withOpacity(0.5))),
                            ),

                          // Subtle Dark Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.6)],
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),

                          // Title & Edit Button (No Delete Button Here Anymore)
                          Positioned(
                            bottom: context.scale(12), left: context.scale(16), right: context.scale(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "Meal Log",
                                    style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(16), fontWeight: FontWeight.w700, color: coverImage != null ? Colors.white : color.onSurface, letterSpacing: -0.5),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // 🚀 EDIT BUTTON ONLY
                                Container(
                                  padding: EdgeInsets.all(context.scale(6)),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Icon(Icons.edit_rounded, size: context.scale(14), color: coverImage != null ? Colors.white : theme.hintColor),
                                ),
                              ],
                            ),
                          ),

                          // Image Count Badge
                          if (photos.length > 1)
                            Positioned(
                              top: context.scale(12), right: context.scale(12),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(4)),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.photo_library_rounded, size: context.scale(10), color: Colors.white),
                                    SizedBox(width: context.scale(4)),
                                    Text("+${photos.length - 1}", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// 🚀 CLEAN DIALOG: Only asks Yes/No. Deletion is handled by Dismissible!
  Future<bool?> _showDeleteDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2232) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.scale(24)),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(8)),
              decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.warning_amber_rounded, color: const Color(0xFFE53935), size: context.scale(20)),
            ),
            SizedBox(width: context.scale(12)),
            Text("Delete Log?", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(18), fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          ],
        ),
        content: Text(
          "Are you sure you want to remove this meal from your journal? This cannot be undone.",
          style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(13), color: theme.hintColor, height: 1.4),
        ),
        actionsPadding: EdgeInsets.fromLTRB(context.scale(16), 0, context.scale(16), context.scale(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // 🚀 Returns false, card snaps back
            child: Text("CANCEL", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1.0)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(12))),
              padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(10)),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx, true); // 🚀 Returns true, card slides away!
            },
            child: Text("DELETE", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: context.scale(12))),
          ),
        ],
      ),
    );
  }
  // 🚀 LUXURY SWIPE-TO-DELETE CONFIRMATION
  Future<bool?> _confirmSwipeDelete(BuildContext context, String mealName, DietPlanNotifier notifier) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2232) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.scale(24)),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.1)), // ✅ FIX: Use 'side' with BorderSide
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(8)),
              decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.warning_amber_rounded, color: const Color(0xFFE53935), size: context.scale(20)),
            ),
            SizedBox(width: context.scale(12)),
            Text("Delete Log?", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(18), fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          ],
        ),
        content: Text(
          "Are you sure you want to remove this meal from your journal? This cannot be undone.",
          style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(13), color: theme.hintColor, height: 1.4),
        ),
        actionsPadding: EdgeInsets.fromLTRB(context.scale(16), 0, context.scale(16), context.scale(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // 🚀 Returns false, snapping the card back
            child: Text("CANCEL", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1.0)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(12))),
              padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(10)),
            ),
            onPressed: () {
              // 🚀 FIREBASE MAP DELETION LOGIC
              notifier.updateDailyRecord(data: {
                'mealLogs.$mealName': FieldValue.delete(),
              });

              HapticFeedback.lightImpact();
              Navigator.pop(ctx, true); // 🚀 Returns true, completing the swipe animation
            },
            child: Text("DELETE", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: context.scale(12))),
          ),
        ],
      ),
    );
  }
  Widget _buildJournalCard(BuildContext context, String mealName, MealEntry mealLog, ColorScheme color, bool isDark, ThemeData theme, DietPlanNotifier notifier, FlatClientDietPlanModel activePlan) {
    final List<dynamic> rawPhotos = mealLog.mealPhotoUrls;
    final List<String> photos = rawPhotos.map((e) => e.toString()).toList();
    final String? coverImage = photos.isNotEmpty ? photos.last : null;

    // Extract the exact time they logged it
    DateTime logTime = mealLog.loggedAt?.toLocal() ?? DateTime.now();
    final String timeString = DateFormat('hh:mm a').format(logTime);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _openLoggingSheet(context, mealName, notifier, activePlan, mealLog);
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
              if (coverImage != null)
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CachedNetworkImage(imageUrl: coverImage, fit: BoxFit.cover),
                )
              else
                Center(child: Icon(Icons.restaurant_rounded, size: context.scale(40).clamp(32.0, 48.0), color: theme.dividerColor.withOpacity(0.5))),

              if (coverImage != null)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),

              Positioned(
                top: context.scale(12), left: context.scale(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(4)),
                  decoration: BoxDecoration(color: const Color(0xFF00E676).withOpacity(0.9), borderRadius: BorderRadius.circular(context.scale(8))),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: context.scale(12).clamp(10.0, 14.0), color: Colors.white),
                      SizedBox(width: context.scale(4)),
                      Text("LOGGED", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10).clamp(9.0, 11.0), fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),

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
                              timeString,
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11).clamp(10.0, 12.0), fontWeight: FontWeight.w700, color: coverImage != null ? Colors.white70 : color.primary, letterSpacing: 1.0)
                          ),
                          SizedBox(height: context.scale(2)),
                          Text(
                            "MEAL LOG", // 🚀 Generic label
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

  void _openLoggingSheet(BuildContext context, String mealName, DietPlanNotifier notifier, FlatClientDietPlanModel plan, MealEntry? log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealDetailSheet(
        notifier: notifier,
        dbKey: mealName, // Passes the unique key strictly for saving
        activePlan: plan,
        logToEdit: log,
      ),
    );
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