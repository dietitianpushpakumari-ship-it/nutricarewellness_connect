import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pure_shift/core/VitalsNudgeBanner.dart';
import 'package:pure_shift/core/utils/nudge_manager.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
import 'package:pure_shift/new/daily_insight_alert.dart';
import 'package:pure_shift/new/healthcontent/health_content.dart';
import 'package:pure_shift/new/screening/clinical_assessment_flow.dart';
import 'package:pure_shift/new/screening/clinical_assessment_trigger.dart';
import 'package:pure_shift/new/smart_insight_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/chat/client_chat_screen.dart';
import 'package:pure_shift/new/booking/client_booking_screen.dart';
import 'package:pure_shift/new/dashboard/profile_Screen.dart' hide kDisplayFont;
import 'package:pure_shift/dynamic_chat_bar.dart';
import 'package:pure_shift/new/core/theme_provider.dart';

// Dashboard widgets (Bento boxes)
import 'package:pure_shift/new/dashboard/dashboard_widgets.dart' hide TickerItem;

// Detail Sheets
import 'package:pure_shift/new/dietplan/hydration_detail_screen.dart';
import 'package:pure_shift/new/dietplan/movement_Details_sheet.dart';
import 'package:pure_shift/new/dietplan/sleep_details_screen.dart' hide kDisplayFont;
import 'package:pure_shift/new/wellnesshub/breathing_detail_screen.dart';
import 'package:pure_shift/core/utils/mindfullness_config.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

// Unread chat counter
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
  DateTime _lastStepUiUpdate = DateTime.now();
  late AnimationController _waveController;
  int? _daysSinceVitals;
  // PEDOMETER VARIABLES
  StreamSubscription<StepCount>? _stepSubscription;
  int _lastKnownHardware = 0;
  int _displaySteps = 0;
  SharedPreferences? _prefs;
  Timer? _diskSaveTimer;

  final ScrollController _scrollController = ScrollController();
  bool _isChatVisible = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _initializeStorageAndPedometer();
    _loadNudgeStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndSwitchDate());
  }
// 🚀 ADD THIS FUNCTION
  Future<void> _loadNudgeStatus() async {
    final status = await NudgeManager.getNudgeStatus();
    if (mounted) setState(() => _daysSinceVitals = status);
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
    setState(() => _displaySteps = _prefs!.getInt('steps_today') ?? 0);
    await _tryStartPedometer();
  }
  Future<void> _tryStartPedometer() async {
    if (!mounted) return;

    // 🚀 1. Absolute Web Guard: Never let the web platform touch permission_handler sensors
    if (kIsWeb) return;

    try {
      // 2. Wrap safely for native platforms only
      var status = await Permission.activityRecognition.status;
      if (!mounted) return;

      if (status.isGranted) {
        if (_stepSubscription != null) return;
        _stepSubscription = Pedometer.stepCountStream.listen(_onStepTick, cancelOnError: false);
      }
    } catch (e) {
      debugPrint("Pedometer not supported or blocked on this device: $e");
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
    final now = DateTime.now();
    if (now.difference(_lastStepUiUpdate).inSeconds >= 3) {
      setState(() => _displaySteps = calculated);
      _lastStepUiUpdate = now;
    } else {
      _displaySteps = calculated;
    }
    if (_diskSaveTimer?.isActive ?? false) _diskSaveTimer!.cancel();
    _diskSaveTimer = Timer(const Duration(seconds: 2), () => _prefs!.setInt('steps_today', calculated));
  }

  void _checkAndSwitchDate() async {
    final currentState = ref.read(activeDietPlanProvider);
    if (!DateUtils.isSameDay(currentState.selectedDate, DateTime.now())) {
      if (_prefs != null) {
        await _prefs!.setInt('today_baseline', _lastKnownHardware);
        await _prefs!.setInt('steps_today', 0);
      }
      if (mounted) setState(() => _displaySteps = 0);
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientChatScreen())).then((_) {
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

    final unreadCountAsync = ref.watch(unreadMessageCountProvider(widget.client.id!));
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Ambient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.6),
                  radius: 1.2,
                  colors: [colorScheme.primary.withOpacity(isDark ? 0.05 : 0.1), theme.scaffoldBackgroundColor],
                ),
              ),
            ),
          ),

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
                // 1. TOP HEADER (Greeting & Tools)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.scale(16), MediaQuery.paddingOf(context).top + context.scale(12), context.scale(16), context.scale(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                                      style: TextStyle(fontFamily: 'Inter', fontSize: context.scale(16), fontWeight: FontWeight.w700, color: colorScheme.onSurface.withOpacity(0.9), letterSpacing: -0.5),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Row(
                          children: [
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
                                    Text("BOOK", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(10), fontWeight: FontWeight.w800, letterSpacing: 1.0, color: colorScheme.primary)),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: context.scale(8)),
                            SmartInsightButton(
                              onOpenInsight: () => _openTodayInsight(context),
                            ),
                            SizedBox(width: context.scale(8)),
                            IconButton(
                              padding: EdgeInsets.all(context.scale(6)), constraints: const BoxConstraints(),
                              icon: Icon(Icons.palette_outlined, color: colorScheme.primary, size: context.scale(22)),
                              onPressed: () { HapticFeedback.mediumImpact(); _showThemeNavigator(context, ref); },
                            ),
                            SizedBox(width: context.scale(4)),
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
                // 🚀 1.5 THE VITALS NUDGE BANNER
                // 🚀 1.5 THE VITALS NUDGE BANNER
                // Only show this Sliver if NudgeManager returned a number
                if (_daysSinceVitals != null)
                  SliverToBoxAdapter(
                    child: VitalsNudgeBanner(
                      // You can optionally pass `_daysSinceVitals` into your banner
                      // widget here if you want to display "It's been X days..."
                      onOpenVitals: () async {

                        // 1. Await the bottom sheet until it completely closes
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => LogVitalsSheet(
                            notifier: notifier,
                            dailyLog: dailyRecord,
                          ),
                        );

                        // 2. 🚀 The sheet just closed. Refresh the UI instantly!
                        // If they saved vitals, this will return null and hide the banner!
                        _loadNudgeStatus();
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.scale(16), context.scale(12), context.scale(16), context.scale(20)),
                    child: LuxuryBentoBackground(
                      baseGlowColor: const Color(0xFFFF0000), // YouTube Red glow for primary emphasis
                      isOverdue: false,
                      expandContent: false,
                      onTap: () {},
                      child: Padding(
                        padding: EdgeInsets.all(context.scale(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🚀 Top Text Header
                            Text(
                              "Wellness Masterclasses",
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontWeight: FontWeight.w800, color: colorScheme.onSurface),
                            ),
                            SizedBox(height: context.scale(4)),
                            Text(
                              "Expert nutrition guides & community updates",
                              style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), color: theme.hintColor, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: context.scale(16)), // Gives the buttons breathing room

                            // 🚀 Bottom Action Row
                            Row(
                              children: [
                                // 🌟 PRIMARY ACTION: YouTube (Wide Pill)
                                Expanded(
                                  child: _buildPrimarySocialButton(
                                      context: context,
                                      label: "Watch on YouTube",
                                      icon: Icons.play_arrow_rounded,
                                      brandColor: const Color(0xFFFF0000),
                                      url: 'https://www.youtube.com/channel/UCqd8FSfKjwalrqXbouB6_ZQ'
                                  ),
                                ),
                                SizedBox(width: context.scale(12)), // Generous spacing

                                // 🌟 SECONDARY ACTION: Instagram (Circle)
                                _buildPremiumSocialButton(
                                    context: context,
                                    icon: Icons.camera_alt_rounded,
                                    brandColor: const Color(0xFFE1306C),
                                    url: 'https://www.instagram.com/dt_pushpa.k/'
                                ),
                                SizedBox(width: context.scale(12)),

                                // 🌟 SECONDARY ACTION: Facebook (Circle)
                                _buildPremiumSocialButton(
                                    context: context,
                                    icon: Icons.facebook_rounded,
                                    brandColor: const Color(0xFF1877F2),
                                    url: 'https://www.facebook.com/pushpa.kumari.9822'
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),



                // 3. DAILY TRACKING BENTO BOXES (Water, Steps, Sleep, Breath)
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.scale(16), context.scale(16), context.scale(16), 0),
                    child: ClinicalAssessmentTrigger(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ClinicalAssessmentFlow(
                                  clientId: widget.client.id ?? '',
                                  clientName: widget.client.name ?? 'Guest',
                                  clientGender: widget.client.gender ?? 'Female',
                                  clientAge: widget.client.age?.toDouble() ?? 30.0,
                                )
                            )
                        );
                      },
                    ),
                  ),
                ),
                // Ensure bottom isn't blocked by the chat bar
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
                  context.scale(16), context.scale(32), context.scale(16),
                  MediaQuery.paddingOf(context).bottom + context.scale(24)
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [theme.scaffoldBackgroundColor.withOpacity(0.0), theme.scaffoldBackgroundColor.withOpacity(0.9), theme.scaffoldBackgroundColor],
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
                      boxShadow: [if (hasNewMessages) BoxShadow(color: colorScheme.primary.withOpacity(0.3 * value), blurRadius: 15 * value, spreadRadius: 3 * value)],
                    ),
                    child: child,
                  );
                },
                child: DynamicChatBar(
                  unreadCount: unreadCount,
                  latestMessage: "Coach Dt. Pushpa sent a message",
                  onTap: _safelyNavigateToChat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
// 💎 REUSABLE LUXURY PRIMARY BUTTON (Wide Pill for YouTube)
  Widget _buildPrimarySocialButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color brandColor,
    required String url,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final Uri parsedUrl = Uri.parse(url);
        if (await canLaunchUrl(parsedUrl)) {
          await launchUrl(parsedUrl, mode: LaunchMode.inAppBrowserView);
        }
      },
      child: Container(
        height: context.scale(42),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.scale(21)),
          boxShadow: [
            BoxShadow(
              color: brandColor.withOpacity(isDark ? 0.15 : 0.1),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.scale(21)),
          child: Stack(
            children: [
              // LAYER 1: Deep Base
              Positioned.fill(child: Container(color: isDark ? const Color(0xFF0B0F19) : Colors.white)),

              // LAYER 2: Soft Corner Glow
              Positioned(
                bottom: -20, right: -20,
                child: Container(
                  width: context.scale(60), height: context.scale(60),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: brandColor.withOpacity(isDark ? 0.4 : 0.2)
                  ),
                ),
              ),

              // LAYER 3: Mesh Blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.transparent),
                ),
              ),

              // LAYER 4 & 5: Glass Border & Content
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.scale(21)),
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                    border: Border.all(color: brandColor.withOpacity(0.4), width: 1.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: brandColor, size: context.scale(20)),
                      SizedBox(width: context.scale(8)),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: context.scale(12),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
// 💎 REUSABLE LUXURY SOCIAL BUTTON (Original Colors + Glassmorphism)
  Widget _buildPremiumSocialButton({
    required BuildContext context,
    required IconData icon,
    required Color brandColor,
    required String url,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final Uri parsedUrl = Uri.parse(url);
        if (await canLaunchUrl(parsedUrl)) {
          await launchUrl(parsedUrl, mode: LaunchMode.inAppBrowserView); // Keeps them inside your app!
        }
      },
      child: Container(
        width: context.scale(42),
        height: context.scale(42),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: brandColor.withOpacity(isDark ? 0.15 : 0.1),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipOval(
          child: Stack(
            children: [
              // LAYER 1: Deep Base Color (Matches Bento)
              Positioned.fill(
                child: Container(color: isDark ? const Color(0xFF0B0F19) : Colors.white),
              ),

              // LAYER 2: Soft Brand-Colored Corner Glow
              Positioned(
                bottom: -10, right: -10,
                child: Container(
                  width: context.scale(30), height: context.scale(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandColor.withOpacity(isDark ? 0.6 : 0.3),
                  ),
                ),
              ),

              // LAYER 3: Mesh Blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.transparent),
                ),
              ),

              // LAYER 4 & 5: Glass Border & The Icon
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                    border: Border.all(
                      color: brandColor.withOpacity(0.4), // Hairline brand-colored border
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: brandColor, size: context.scale(20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
// 🚀 RECALL TODAY'S EXACT INSIGHT
  void _openTodayInsight(BuildContext context) {
    HapticFeedback.mediumImpact();
    // Use the exact same mathematical seed to guarantee it's the same tip
    final random = math.Random(DateTime.now().day);
    final shuffled = List<HealthTip>.from(masterHealthTips)..shuffle(random);
    final todayTip = shuffled.first;

    // Open the bottom sheet (ensure showHealthTipDetail is accessible/imported)
    _showHealthTipDetailShared(context, todayTip);
  }

  Future<void> _showHealthTipDetailShared(BuildContext context, HealthTip tip) async {
    String currentLang = 'en';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateSheet) {
              final titleText = tip.title[currentLang] ?? tip.title['en'] ?? "";
              final bodyText = tip.body[currentLang] ?? tip.body['en'] ?? "";

              return Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.paddingOf(context).bottom + 32),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF121826) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(tip.category.toUpperCase(), style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: colorScheme.primary))),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                          child: Row(
                            children: ['en', 'hi', 'or'].map((lang) {
                              bool isSelected = currentLang == lang;
                              return GestureDetector(
                                onTap: () { HapticFeedback.selectionClick(); setStateSheet(() => currentLang = lang); },
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isSelected ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Text(lang.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, color: isSelected ? Colors.white : theme.hintColor))),
                              );
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(titleText, style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 22, fontWeight: FontWeight.w900, height: 1.2, color: colorScheme.onSurface)),
                    const SizedBox(height: 16),
                    ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45), child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Text(bodyText, style: TextStyle(fontFamily: 'Inter', fontSize: 15, height: 1.6, fontWeight: FontWeight.w500, color: theme.hintColor)))),
                  ],
                ),
              );
            }
        );
      },
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