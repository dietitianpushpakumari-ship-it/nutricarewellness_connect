import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/PremiumKnowledgeHub.dart';
import 'package:pure_shift/atmospheric_pulse_card.dart'; // Make sure PulseState is inside this file!
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/core/utils/workout_config.dart';
import 'package:pure_shift/dashboard_feed_preview.dart' hide kDisplayFont;
import 'package:pure_shift/dynamic_chat_bar.dart';
import 'package:pure_shift/elite_nudge_hub.dart' hide kDisplayFont;
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/live_action_carousal.dart';
import 'package:pure_shift/live_nudge_ticker.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/booking/client_booking_screen.dart';
import 'package:pure_shift/new/booking/client_wallet_screen.dart';
import 'package:pure_shift/new/chat/client_chat_screen.dart' hide kDisplayFont;
import 'package:pure_shift/new/core/theme_provider.dart';
import 'package:pure_shift/new/service/notification_service.dart';
import 'package:pure_shift/test_animation.dart';
import 'package:pure_shift/unified_nudge_row.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

// 🎯 WIDGETS
import 'package:pure_shift/new/dashboard/dashboard_widgets.dart' hide TickerItem;
import 'package:pure_shift/core/utils/followup_banner.dart';
import 'package:pure_shift/new/home/smart_nudge_bar.dart';
import 'package:pure_shift/new/dashboard/profile_Screen.dart' hide kDisplayFont;
import 'package:pure_shift/core/utils/rating_dialog.dart';
import 'package:pure_shift/core/utils/rating_service.dart';
import 'package:pure_shift/new/dashboard/smart_insight_grid.dart' hide kFontFamily, kDisplayFont;

// 🎯 DETAIL SHEETS
import 'package:pure_shift/new/dietplan/hydration_detail_screen.dart';
import 'package:pure_shift/new/dietplan/movement_Details_sheet.dart';
import 'package:pure_shift/new/dietplan/sleep_details_screen.dart' hide kDisplayFont;
import 'package:pure_shift/new/wellnesshub/breathing_detail_screen.dart';
import 'package:pure_shift/core/utils/mindfullness_config.dart';
import 'package:pure_shift/new/dashboard/analytics_detail_screen.dart' hide kDisplayFont;

// 🎯 PROVIDERS & ENTITIES
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/new/service/client_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../wellnesshub/workout_player_sheet.dart' hide kDisplayFont;

// ============================================================================
// 🚀 NEW MODELS FOR THE LUXURY HERO CARD & TICKER
// ============================================================================



// ============================================================================
// 🚀 CLIENT UNREAD MESSAGE COUNTER PROVIDER
// ============================================================================
final unreadMessageCountProvider = StreamProvider.autoDispose.family<int, String>((ref, clientId) {
  return FirebaseFirestore.instance
      .collection('clients')
      .doc(clientId)
      .collection('chat')
      .where('isSenderClient', isEqualTo: false)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

class HomeScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const HomeScreen({super.key, required this.client});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
// 🚀 ADD THIS: Keeps track of the last time we updated the UI
  DateTime _lastStepUiUpdate = DateTime.now();
  late AnimationController _waveController;

  // 🚀 PEDOMETER VARIABLES
  StreamSubscription<StepCount>? _stepSubscription;
  int _lastKnownHardware = 0;
  int _displaySteps = 0;

  // 🚀 STATE & STORAGE
  SharedPreferences? _prefs;
  Timer? _diskSaveTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isChatVisible = true;
  bool _isNavigating = false;
  final List<double> _milestones = [0.25, 0.50, 0.75, 1.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _initializeStorageAndPedometer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSwitchDate();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _checkAndSwitchDate();
        _tryStartPedometer();
      });
    }
  }

  Future<void> _initializeStorageAndPedometer() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    _prefs = prefs;
    setState(() {
      _displaySteps = _prefs!.getInt('steps_today') ?? 0;
    });

    await _tryStartPedometer();
  }

  Future<void> _tryStartPedometer() async {
    if (!mounted) return;

    var status = await Permission.activityRecognition.status;
    if (!mounted) return;

    if (status.isGranted) {
      if (_stepSubscription != null) return;
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepTick,
        onError: (error) => debugPrint("🔴 [PEDOMETER ERROR]: $error"),
        cancelOnError: false,
      );
    }
  }

  void _onStepTick(StepCount event) {
    if (!mounted || _prefs == null) return;

    int live = event.steps;
    _lastKnownHardware = live;

    int baseline = _prefs!.getInt('today_baseline') ?? live;
    if (_prefs!.getInt('today_baseline') == null) {
      _prefs!.setInt('today_baseline', live);
      baseline = live;
    }

    int calculated = live - baseline;

    if (calculated < 0 || (calculated - _displaySteps).abs() > 10000) {
      _prefs!.setInt('today_baseline', live);
      calculated = 0;
    }

    // 🚀 THE MISSING FIX: Throttle UI Updates to every 3 seconds
    final now = DateTime.now();
    if (now.difference(_lastStepUiUpdate).inSeconds >= 3) {
      setState(() {
        _displaySteps = calculated;
      });
      _lastStepUiUpdate = now;
    } else {
      // Just update the variable silently without rebuilding the screen
      _displaySteps = calculated;
    }

    // Disk save throttling (You already had this, which is good!)
    if (_diskSaveTimer?.isActive ?? false) {
      _diskSaveTimer!.cancel();
    }

    _diskSaveTimer = Timer(const Duration(seconds: 2), () {
      _prefs!.setInt('steps_today', calculated);
    });
  }

  void _checkAndSwitchDate() async {
    final currentState = ref.read(activeDietPlanProvider);
    if (!DateUtils.isSameDay(currentState.selectedDate, DateTime.now())) {
      if (_prefs != null) {
        await _prefs!.setInt('today_baseline', _lastKnownHardware);
        await _prefs!.setInt('steps_today', 0);
      }
      if (mounted) {
        setState(() => _displaySteps = 0);
      }
      ref.read(dietPlanNotifierProvider(widget.client.id).notifier).selectDate(DateTime.now());
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _diskSaveTimer?.cancel();
    _waveController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _safelyNavigateToChat() {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    HapticFeedback.mediumImpact();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientChatScreen()),
    ).then((_) {
      if (mounted) setState(() => _isNavigating = false);
    });
  }

  Future<void> _quickAddWater(DietPlanNotifier notifier, double current) async {
    try {
      final double newTotal = double.parse((current + 0.25).toStringAsFixed(2)).clamp(0.0, 10.0);
      await notifier.updateDailyRecord(data: {'hydrationLiters': newTotal});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('+250ml Added!'), duration: const Duration(milliseconds: 800), backgroundColor: Theme.of(context).colorScheme.primary));
    } catch (e) {
      debugPrint("Failed to add water: $e");
    }
  }

  // 🚀 AIRPORT LOGIC: Smart Time Parser (Reads exact time)
  DateTime? _parseWorkoutTime(String timeStr) {
    if (timeStr.trim().isEmpty) return null;
    final RegExp timeRegExp = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false);
    final match = timeRegExp.firstMatch(timeStr.toLowerCase());

    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      String? amPm = match.group(3);

      if (amPm == 'pm' && hour < 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final dailyRecord = state.dailyRecord;

    final double waterIntake = dailyRecord?.hydrationLiters ?? 0.0;
    final double waterGoal = state.activePlan?.dailyWaterGoal ?? 3.0;

    final int savedSteps = _displaySteps;
    final int stepGoal = state.activePlan?.dailyStepGoal ?? 8000;
    final int breathMin = dailyRecord?.breathingMinutes ?? 0;

    final allRoutines = _getParsedWorkouts();
    final unreadCountAsync = ref.watch(unreadMessageCountProvider(widget.client.id));
    final int unreadCount = unreadCountAsync.value ?? 0;
    final bool hasNewMessages = unreadCount > 0;

    double sleepHours = 0.0;
    if (dailyRecord != null && dailyRecord.sleepTime != null && dailyRecord.wakeTime != null) {
      try {
        DateTime sleepDt = dailyRecord.sleepTime!.toLocal();
        DateTime wakeDt = dailyRecord.wakeTime!.toLocal();
        if (wakeDt.isBefore(sleepDt)) wakeDt = wakeDt.add(const Duration(days: 1));
        sleepHours = wakeDt.difference(sleepDt).inMinutes / 60.0;
      } catch (_) {}
    }
    final int sleepScore = dailyRecord?.sleepQualityRating ?? 0;

    // ==========================================
    // 🧠 1. THE TICKER LOGIC (Telemetry, Duties, Insights)
    // ==========================================
    // ==========================================
    // 🧠 1. THE TICKER LOGIC (Telemetry, Duties, Insights & Booking)
    // ==========================================
    // Inside your build() method, right below calculating variables...

    // ==========================================
    // 🧠 THE TIMELINE SEQUENCE ENGINE
    // ==========================================
    // ==========================================
    // 🧠 THE TIMELINE TICKET ENGINE
    // ==========================================
    List<PulseAction> dailySequence = [];
    final now = DateTime.now();

    // 🚀 1. LIVE WORKOUTS (-30m to +15m window)
    for (var w in allRoutines) {
      final t = _parseWorkoutTime(w.description);
      if (t != null) {
        if (now.isAfter(t.subtract(const Duration(minutes: 30))) && now.isBefore(t.add(const Duration(minutes: 15)))) {
          dailySequence.add(PulseAction(
            state: PulseState.workout,
            title: "Time for ${w.title}",
            subtitle: "Your session is ready. Let's move.",
            actionText: "START WORKOUT",
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFF00E676), // Green
            isElapsed: true, // It is actively pulsing!
            onAction: () {
              HapticFeedback.heavyImpact();
              _launchWorkout(context, w, widget.client);
            },
          ));
        }
      }
    }

    // 🚀 2. UNREAD CHAT
    if (unreadCount > 0) {
      dailySequence.add(PulseAction(
        state: PulseState.chat,
        title: "Message from Coach",
        subtitle: "You have $unreadCount unread insight(s).",
        actionText: "REPLY",
        icon: Icons.chat_bubble_outline_rounded,
        color: const Color(0xFF448AFF), // Blue
        isElapsed: true, // Priority!
        onAction: _safelyNavigateToChat,
      ));
    }

    // 🚀 3. MEAL DUTIES (Breakfast, Lunch, Dinner Matrix)
    // Breakfast: 8 AM - 11 AM
    if (now.hour >= 8 && now.hour < 11 /* && !dailyRecord.breakfastLogged */) {
      dailySequence.add(PulseAction(
        state: PulseState.nudge,
        title: "Morning Fuel",
        subtitle: "Your breakfast window is open.",
        actionText: "LOG MEAL",
        icon: Icons.bakery_dining_rounded,
        color: const Color(0xFFFF9100), // Orange
        isElapsed: now.hour >= 9, // Starts pulsing if it's 9 AM or later!
        onAction: () {
          // TODO: Open your MealDetailSheet here instead of Quick Add
        },
      ));
    }
    // Lunch: 12 PM - 4 PM
    else if (now.hour >= 12 && now.hour < 16 /* && !dailyRecord.lunchLogged */) {
      dailySequence.add(PulseAction(
        state: PulseState.nudge,
        title: "Mid-Day Fuel",
        subtitle: "Your lunch window is open.",
        actionText: "LOG MEAL",
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFFF9100),
        isElapsed: now.hour >= 14,
        onAction: () {},
      ));
    }

    // 🚀 4. HYDRATION GOALS (Matrix based on time of day)
    bool needsWater = false;
    bool waterIsUrgent = false;

    if (now.hour >= 8 && now.hour < 12 && waterIntake < (waterGoal * 0.25)) {
      needsWater = true;
      waterIsUrgent = now.hour >= 9 && waterIntake == 0; // If 9 AM and 0L, it pulses!
    } else if (now.hour >= 12 && now.hour < 17 && waterIntake < (waterGoal * 0.5)) {
      needsWater = true;
      waterIsUrgent = true;
    } else if (now.hour >= 17 && waterIntake < waterGoal) {
      needsWater = true;
      waterIsUrgent = true;
    }

    if (needsWater) {
      dailySequence.add(PulseAction(
        state: PulseState.nudge,
        title: "Hydration Check",
        subtitle: "You are behind schedule. Drink up.",
        actionText: "OPEN TRACKER", // 🚀 Changed from Quick Add
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF00B0FF), // Light Blue
        isElapsed: waterIsUrgent,
        onAction: () {
          // 🚀 Opens the full sheet instead of Quick Adding
          if(state.activePlan != null) {
            showModalBottomSheet(
                isDismissible: false,
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => HydrationDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord, currentIntake: waterIntake)
            );
          }
        },
      ));
    }

    // ==========================================
    // 🚀 5. THE WISDOM ORB (Text Based)
    // ==========================================
    String calmTitle = "Daily Wisdom";
    String calmSubtitle = "Consistency is the path to transformation.";
    if (now.hour < 12) { calmTitle = "Morning Intention"; calmSubtitle = "Win the morning, win the day."; }
    else if (now.hour >= 17) { calmTitle = "Evening Reflection"; calmSubtitle = "Disconnect and recover."; }

    dailySequence.add(PulseAction(
      state: PulseState.calm,
      title: calmTitle,
      subtitle: calmSubtitle,
      actionText: "READ",
      icon: Icons.auto_awesome,
      color: const Color(0xFFB388FF), // Purple
      isElapsed: false,
      onAction: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const InsightCarouselDeck());
      },
    ));

    // ==========================================
    // 🚀 6. THE FEED ORB (Image Based - With Mini Gallery)
    // ==========================================
    dailySequence.add(PulseAction(
      state: PulseState.feed,
      title: "Community Feed",
      subtitle: "", // 🚀 Shorter text gives more room to images
      actionText: "VIEW ALL",
      icon: Icons.photo_library_rounded,
      color: const Color(0xFFFF4081),
      isElapsed: false,
      customContent: _buildLiveMiniGallery(isDark), // 🚀 Now completely live!
      onAction: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                children: [
                  SizedBox(height: context.scale(12)),
                  Container(width: context.scale(40), height: context.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                  SizedBox(height: context.scale(16)),
                  const Expanded(child: DashboardFeedPreview()),
                ],
              ),
            )
        );
      },
    ));
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 🌌 Fake Atmospheric Glow (Zero GPU Cost)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.6), // Top Right
                  radius: 1.2,
                  colors: [
                    colorScheme.primary.withOpacity(isDark ? 0.08 : 0.15),
                    theme.scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, 0.8), // Bottom Left
                  radius: 1.0,
                  colors: [
                    colorScheme.secondary.withOpacity(isDark ? 0.08 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 🌌 Ambient Background Orbs
       //   Positioned(top: -150, right: -100, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withOpacity(isDark ? 0.15 : 0.3)))),
         // Positioned(bottom: 100, left: -150, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.secondary.withOpacity(isDark ? 0.15 : 0.2)))),
         // Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent))),

          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                if (_isChatVisible) setState(() => _isChatVisible = false);
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_isChatVisible) setState(() => _isChatVisible = true);
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                // --- TOP HEADER ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.scale(16), MediaQuery.of(context).padding.top + context.scale(12), context.scale(16), context.scale(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Greeting
                        Expanded(
                          child: RepaintBoundary(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                final String rawName = widget.client.name?.split(' ').first ?? 'Friend';
                                final String formattedName = rawName.isNotEmpty ? '${rawName[0].toUpperCase()}${rawName.substring(1).toLowerCase()}' : 'Friend';
                                return Transform.translate(
                                  offset: Offset(0, 10 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: PremiumShimmerText(
                                      text: "Hi, $formattedName",
                                      style: TextStyle(fontFamily: 'Inter', fontSize: context.scale(15), fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.9), letterSpacing: -0.5),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // 2. The Utilities Row
                        Row(
                          children: [
                            // 🚀 THE NEW MICRO BOOKING BUTTON
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ClientBookingScreen(tenantId: widget.client.tenantId)));
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: context.scale(10), vertical: context.scale(6)),
                                decoration: BoxDecoration(
                                  color: isDark ? colorScheme.primary.withOpacity(0.15) : colorScheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(context.scale(20)),
                                  border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded, color: colorScheme.primary, size: context.scale(12)),
                                    SizedBox(width: context.scale(4)),
                                    Text(
                                        "BOOK",
                                        style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(10), fontWeight: FontWeight.w800, letterSpacing: 1.0, color: colorScheme.primary)
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(width: context.scale(8)),

                            // Theme Toggle
                            IconButton(
                              padding: EdgeInsets.all(context.scale(6)), constraints: const BoxConstraints(),
                              icon: Icon(Icons.palette_outlined, color: colorScheme.primary, size: context.scale(22)),
                              onPressed: () { HapticFeedback.mediumImpact(); _showThemeNavigator(context, ref); },
                            ),

                            SizedBox(width: context.scale(4)),

                            // Profile Avatar
                            GestureDetector(
                              onTap: () { HapticFeedback.mediumImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); },
                              child: Container(
                                padding: EdgeInsets.all(context.scale(6)),
                                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), shape: BoxShape.circle),
                                child: Icon(Icons.person_outline_rounded, color: colorScheme.onSurface, size: context.scale(20)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 🚀 THE NEW ATMOSPHERIC HERO CARD WITH TICKER STRIP
                // ... inside CustomScrollView ...
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: context.scale(8), bottom: context.scale(24)),
                    child: AtmosphericPulseCard(actions: dailySequence),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.40,
                    children: [
                      RepaintBoundary(child: MiniHydrationCard(currentLiters: waterIntake, goalLiters: waterGoal, waveAnimation: _waveController, onTap: () { if(state.activePlan != null) showModalBottomSheet(isDismissible: false, context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => HydrationDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord, currentIntake: waterIntake)); }, onQuickAdd: () => _quickAddWater(notifier, waterIntake))),
                      MiniStepCard(steps: savedSteps, goal: stepGoal, onTap: () { if(state.activePlan != null) showModalBottomSheet(isDismissible: false, context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MovementDetailSheet.withSteps(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord, currentSteps: savedSteps)); }),
                      MiniSleepCard(hours: sleepHours, score: sleepScore, onTap: () { if(state.activePlan != null) showModalBottomSheet(isDismissible: false, context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => SleepDetailSheet(notifier: notifier, activePlan: state.activePlan!, dailyLog: dailyRecord)); }),
                      MiniBreathingCard(minutesLogged: breathMin, onTap: () => _showBreathingMenu(context, notifier, state.activePlan, dailyRecord, theme, colorScheme, isDark)),
                    ],
                  ),
                ),


                SliverPadding(padding: EdgeInsets.only(bottom: context.scale(20))),
                // The Trend Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  sliver: SliverToBoxAdapter(child: SmartInsightCard(clientId: widget.client.id)),
                ),

                SliverPadding(padding: EdgeInsets.only(bottom: context.scale(130))),
              ],
            ),
          ),

          // Floating Chat Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _isChatVisible ? 0 : -(context.scale(150)),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  context.scale(16),
                  context.scale(32),
                  context.scale(16),
                  MediaQuery.of(context).padding.bottom + context.scale(24)
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor.withOpacity(0.0),
                    theme.scaffoldBackgroundColor.withOpacity(0.9),
                    theme.scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.0, end: hasNewMessages ? 1.0 : 0.0),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.scale(18)),
                      boxShadow: [
                        if (hasNewMessages)
                          BoxShadow(color: colorScheme.primary.withOpacity(0.3 * value), blurRadius: 15 * value, spreadRadius: 3 * value),
                      ],
                    ),
                    child: child,
                  );
                },
                child: DynamicChatBar(
                  unreadCount: unreadCount,
                  latestMessage: "Coach Pushpa sent a message",
                  onTap: _safelyNavigateToChat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 THE FIX: Live Real-Time Gallery from CMS
// 🚀 THE FIX: Compact, tighter gallery that doesn't break the layout height
  Widget _buildLiveMiniGallery(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cms_content')
          .where('isLive', isEqualTo: true)
          .orderBy('updated_at', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return SizedBox(
          height: context.scale(55), // 🚀 REDUCED from 65px to 42px
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(docs.length, (index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String coverUrl = data['coverImageUrl'] ?? '';
              final bool isNewest = index == 0;

              return Positioned(
                left: index * context.scale(35), // 🚀 Tighter overlap (was 45)
                child: Container(
                  width: context.scale(55), // 🚀 Scaled down image size
                  height: context.scale(55),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(context.scale(10)),
                    border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2), // Ring
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(context.scale(8)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        coverUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover)
                            : Container(color: Colors.grey.shade800, child: Icon(Icons.article, color: Colors.white54, size: context.scale(16))),

                        if (isNewest) Container(color: Colors.black.withOpacity(0.1)),

                        // 🚨 MINI "NEW" BADGE
                        if (isNewest)
                          Positioned(
                            top: 0, right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: context.scale(4), vertical: context.scale(2)),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6)),
                              ),
                              child: Text(
                                "NEW",
                                style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: context.scale(6), fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).reversed.toList(),
          ),
        );
      },
    );
  }
  void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, FlatClientDietPlanModel? activePlan, ClientLogModel? dailyRecord, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    if (activePlan == null) return;

    showModalBottomSheet(
      isDismissible: true, context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(16), context.scale(24), context.scale(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
                Text(context.tr("lbl_choose_mode").toUpperCase(), style: TextStyle(fontFamily: 'Inter', fontSize: context.scale(12), fontWeight: FontWeight.w800, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.6))),
                const SizedBox(height: 20),
                _buildPresetTile(ctx, context.tr("focus_and_clarity"), context.tr("lbl_box_breathing"), Icons.crop_square_rounded, Colors.teal, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.box), theme, colorScheme),
                _buildPresetTile(ctx, context.tr("sleep_and_anxiety"), context.tr("lbl_relax_breath"), Icons.nightlight_round, Colors.indigo, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.relax), theme, colorScheme),
                _buildPresetTile(ctx, context.tr("lbl_energy_boost"), context.tr("lbl_rapid_awakening"), Icons.bolt_rounded, Colors.orange, () => _launchBreathingSheet(context, notifier, activePlan, dailyRecord, BreathingConfig.energy), theme, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, FlatClientDietPlanModel plan, ClientLogModel? dailyRecord, BreathingConfig config) {
    Navigator.pop(context);
    showModalBottomSheet(isDismissible: false, context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => BreathingDetailSheet(notifier: notifier, activePlan: plan, dailyLog: dailyRecord, config: config));
  }

  Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, ThemeData theme, ColorScheme colorScheme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: context.scale(14), color: colorScheme.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: context.scale(12), color: theme.hintColor)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: theme.hintColor.withOpacity(0.3)),
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
    );
  }

  // 🚀 Builds the overlapping luxury image stack for the Feed Card
  Widget _buildMiniGallery(bool isDark) {
    // You can replace these with actual feed preview images later
    final List<String> placeholderImages = [
      'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=200&fit=crop', // Healthy food
      'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=200&fit=crop', // Workout/Yoga
      'https://images.unsplash.com/photo-1545205597-3d9d02c29597?w=200&fit=crop', // Wellness
    ];

    return SizedBox(
      height: context.scale(50),
      child: Stack(
        children: List.generate(placeholderImages.length, (index) {
          return Positioned(
            left: index * context.scale(35), // Overlapping offset
            child: Container(
              width: context.scale(50),
              height: context.scale(50),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.scale(14)),
                border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2.5), // Separates the images
                image: DecorationImage(
                  image: NetworkImage(placeholderImages[index]),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showWorkoutMenu(BuildContext context, ThemeData theme, ClientModel client) {
    final isDark = theme.brightness == Brightness.dark;
    final prescribedRoutines = _getParsedWorkouts();

    showModalBottomSheet(
      isDismissible: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121826) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(ctx.scale(28))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: ctx.scale(12)),
              Center(child: Container(width: ctx.scale(36), height: ctx.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(ctx.scale(2))))),
              SizedBox(height: ctx.scale(16)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ctx.scale(24)),
                child: Text("QUICK FIT", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: ctx.scale(10), fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.6))),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(ctx.scale(24), ctx.scale(4), ctx.scale(24), ctx.scale(16)),
                child: Text("Select a Routine", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: ctx.scale(16), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ctx.scale(20)),
                child: Column(
                  children: [
                    if (prescribedRoutines.isNotEmpty) ...[
                      ...prescribedRoutines.map((config) => _buildPresetRow(
                          ctx,
                          config.title,
                          "Dietitian Prescribed • ${config.steps.length} Steps",
                          Icons.verified_user_rounded,
                          isDark ? Colors.white : Colors.black,
                              () {
                            Navigator.pop(ctx);
                            _launchWorkout(context, config, client);
                          },
                          theme
                      )),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: ctx.scale(8), horizontal: ctx.scale(16)),
                        child: Text("STANDARD ROUTINES", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: ctx.scale(9), fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.hintColor.withOpacity(0.5))),
                      ),
                    ],
                    _buildPresetRow(ctx, "Morning Charge", "3 Min Wake Up", Icons.wb_sunny_rounded, Colors.orange, () { Navigator.pop(ctx); _launchWorkout(context, WorkoutConfig.morningStretch, client); }, theme),
                    _buildPresetRow(ctx, "Desk De-Stress", "5 Min Neck & Back", Icons.chair_rounded, Colors.blueAccent, () { Navigator.pop(ctx); _launchWorkout(context, WorkoutConfig.deskRelief, client); }, theme),
                  ],
                ),
              ),
              SizedBox(height: ctx.scale(32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetRow(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: context.scale(10)),
        padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(14)),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(context.scale(16)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
                padding: EdgeInsets.all(context.scale(10)),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: context.scale(16))
            ),
            SizedBox(width: context.scale(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.w700, fontSize: context.scale(12), color: theme.colorScheme.onSurface)),
                  SizedBox(height: context.scale(2)),
                  Text(subtitle, style: TextStyle(fontFamily: 'Inter', color: theme.hintColor, fontSize: context.scale(10), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: context.scale(16), color: theme.hintColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  void _launchWorkout(BuildContext context, WorkoutConfig config, ClientModel client) {
    showModalBottomSheet(
        isDismissible: false,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => WorkoutPlayerSheet(config: config, client: client)
    );
  }

  List<WorkoutConfig> _getParsedWorkouts() {
    if (widget.client.assignedWorkouts.isEmpty) return [];

    return widget.client.assignedWorkouts.map((routine) {
      final Map<String, dynamic> routineJson = routine as Map<String, dynamic>;
      final List stepsData = routineJson['steps'] ?? [];

      final List<WorkoutStep> parsedSteps = stepsData.map((s) {
        ExerciseType parsedType = ExerciseType.rest;
        try {
          parsedType = ExerciseType.values.byName(s['type']);
        } catch (_) {}

        return WorkoutStep(
          type: parsedType,
          duration: s['duration'] ?? 30,
          reps: s['reps'] ?? 0,
          isRepBased: (s['reps'] ?? 0) > 0,
          title: parsedType.name.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ').toUpperCase(),
          instruction: "Execute with proper form.",
          icon: Icons.fitness_center_rounded,
        );
      }).toList();

      return WorkoutConfig(
        title: routineJson['title']?.toString().toUpperCase() ?? "CLINICAL PROTOCOL",
        description: routineJson['scheduledTime'] ?? "Today",
        color: const Color(0xFF1E1E1E),
        steps: parsedSteps,
      );
    }).toList();
  }
}

class PremiumShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const PremiumShimmerText({super.key, required this.text, required this.style});

  @override
  State<PremiumShimmerText> createState() => _PremiumShimmerTextState();
}

class _PremiumShimmerTextState extends State<PremiumShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = widget.style.color ?? theme.colorScheme.onSurface;
    final shineColor = isDark ? Colors.white : theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slide = -2.0 + (_controller.value * 4.0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, shineColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(slide - 0.5, 0.0),
              end: Alignment(slide + 0.5, 0.0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: Text(widget.text, style: widget.style.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}

void _showThemeNavigator(BuildContext context, WidgetRef ref) {
  final currentTheme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: currentTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: currentTheme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("App Interface", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          const Text("PREMIUM LIGHT", style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _themeDot(ref, AppThemeType.appleHealth, const Color(0xFFFF2D55), Colors.white),
                _themeDot(ref, AppThemeType.facebook, const Color(0xFF1877F2), const Color(0xFFF0F2F5)),
                _themeDot(ref, AppThemeType.stripe, const Color(0xFF635BFF), const Color(0xFFF6F9FC)),
                _themeDot(ref, AppThemeType.mint, const Color(0xFF00A389), const Color(0xFFF4F9F8)),
                _themeDot(ref, AppThemeType.monoLight, Colors.black, const Color(0xFFF9FAFB)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("OLED DARK", style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _themeDot(ref, AppThemeType.appleOled, const Color(0xFF0A84FF), Colors.black),
                _themeDot(ref, AppThemeType.spotify, const Color(0xFF1DB954), const Color(0xFF121212)),
                _themeDot(ref, AppThemeType.amethyst, const Color(0xFFBF5AF2), const Color(0xFF0D0B14)),
                _themeDot(ref, AppThemeType.gold, const Color(0xFFFFD60A), Colors.black),
                _themeDot(ref, AppThemeType.monoDark, Colors.white, Colors.black),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}

Widget _themeDot(WidgetRef ref, AppThemeType type, Color primary, Color bg) {
  final isSelected = ref.watch(themeProvider.notifier).currentType == type;
  return GestureDetector(
    onTap: () => ref.read(themeProvider.notifier).setTheme(type),
    child: Container(
      margin: const EdgeInsets.only(right: 16),
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: bg, shape: BoxShape.circle,
        border: Border.all(color: isSelected ? primary : primary.withOpacity(0.2), width: isSelected ? 3 : 1),
        boxShadow: isSelected ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10)] : null,
      ),
      child: Center(child: Container(width: 20, height: 20, decoration: BoxDecoration(color: primary, shape: BoxShape.circle))),
    ),
  );
}