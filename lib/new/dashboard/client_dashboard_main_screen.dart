import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 Added for Haptics
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/core/string_extension.dart';
import 'package:pure_shift/core/utils/background_sync_service.dart';

import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:pure_shift/health_permission_service.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/coach/coach_tab.dart';
import 'package:pure_shift/features/auth/auth_provider.dart';

import 'package:pure_shift/new/dashboard/modern_bottom_bar.dart';
import 'package:pure_shift/core/utils/sync_manager.dart';
import 'package:pure_shift/new/wellnesshub/wellness_hub_screen.dart';
import 'package:pure_shift/new/activityhub/activity_tracker_screen.dart' hide vitalsHistoryProvider;
import 'package:pure_shift/new/dashboard/home_screen.dart';
import 'package:pure_shift/new/repositories/diet_repositories.dart';
import 'package:pure_shift/plan_focus_area.dart';
import 'package:pure_shift/shared/permission_sequence_service.dart';
import '../../features/dietplan/domain/entities/client_log_model.dart';
import '../provider/diet_plan_provider.dart';
import 'package:pure_shift/main.dart';

// 🚀 IMPORT SCALING UTILS
import 'package:pure_shift/layout_utils.dart';

// 🎯 GLOBAL FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

final unreadChatCountProvider = StreamProvider.autoDispose<int>((ref) {
  final clientId = ref.watch(currentClientIdProvider);
  if (clientId == null || clientId.isEmpty) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('clients')
      .doc(clientId)
      .collection('chat')
      .where('isSenderClient', isEqualTo: false)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

class ClientDashboardScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  final bool showWelcomeSheet;
  const ClientDashboardScreen( {super.key, required this.client,  this.showWelcomeSheet = false,});

  @override
  ConsumerState<ClientDashboardScreen> createState() => ClientDashboardScreenState();
}

class ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  int _selectedIndex = 0;
  FlatClientDietPlanModel? activePlan;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      await PermissionSequenceService().runWelcomeSequence(context);

      scheduleClinicalSync(widget.client.id!);
    if (widget.showWelcomeSheet) {
      final String clientName = widget.client.name ?? "Guest";

      // 2. Fetch the Coach details using the coachId from the client model
      String coachName = "Pushpa"; // Fallback
      if (widget.client.coachId != null) {
        final coachProfile = ref
            .read(dietitianProfileProvider(widget.client.coachId!))
            .valueOrNull;
        coachName = coachProfile?.firstName ?? "Pushpa";
      }

      // 3. Fetch the Company/Clinic details using the tenantId from the client model
      String companyName = "Nutricare Wellness"; // Fallback
      if (widget.client.tenantId != null) {
        final tenantProfile = await ref.read(
            tenantProfileProvider(widget.client.tenantId!).future);
        companyName = tenantProfile?.name ?? "Nutricare Wellness";
      }

      // 4. Show the beautiful sheet with dynamic data!
      if (mounted) {
        showLuxuryWelcomeSheet(
          context,
          clientName: clientName,
          companyName: companyName,
          coachName: coachName,
        );
      }
    }
        SyncManager().checkAppLaunchSync();




    });



  }



  void showLuxuryWelcomeSheet(
      BuildContext context, {
        required String clientName,
        required String companyName,
        required String coachName,
      }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6), // Darker, cinematic backdrop
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: SafeArea(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Glassmorphism
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 32), // 🚀 Perfect SafeArea
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor.withOpacity(0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.15),
                      blurRadius: 60,
                      offset: const Offset(0, -10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minimalist Drag Handle
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 40),
            
                    // 🚀 1. OVERLINE: Welcome To
                    Text(
                      "W E L C O M E   T O",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 12),
            
                    // 🚀 2. COMPANY NAME (Dynamic & Luxurious)
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [cs.primary, cs.tertiary, cs.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        companyName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white, // Required for ShaderMask
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
            
                    // Visual Separator (Luxury Touch)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 40, height: 1, color: theme.dividerColor.withOpacity(0.5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.spa_rounded, size: 16, color: cs.primary.withOpacity(0.5)),
                        ),
                        Container(width: 40, height: 1, color: theme.dividerColor.withOpacity(0.5)),
                      ],
                    ),
                    const SizedBox(height: 32),
            
                    // 🚀 3. CLIENT NAME
                    Text(
                      "Hello, ${clientName.toTitleCase()}.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
            
                    // 🚀 4. COACH MESSAGE (Visual Separation)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.primary.withOpacity(0.1)),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.8),
                            height: 1.6,
                          ),
                          children: [
                            const TextSpan(text: "Your clinical profile and personalized wellness protocol have been successfully configured by "),
                            TextSpan(
                              text: "Coach $coachName", // Dynamic Coach Name
                              style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary),
                            ),
                            const TextSpan(text: "."),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
            
                    // 🚀 5. MODERN CTA BUTTON
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "ENTER DASHBOARD",
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.arrow_right_alt_rounded, size: 20, color: cs.onPrimary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick(); // 🚀 Premium feel on tab switch
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProfileFutureProvider);
    final unreadCountAsync = ref.watch(unreadChatCountProvider);
    final int unreadCount = unreadCountAsync.value ?? 0;


    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return clientAsync.when(
      loading: () => Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: Center(child: CircularProgressIndicator(color: colorScheme.primary))),
      error: (err, stack) => Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: Center(child: Text('Error: $err', style: TextStyle(color: colorScheme.error, fontFamily: kBodyFont)))),
      data: (client) {
        if (client == null) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: const Center(child: Text('Client not found.')));
        if (client.coachId != null && client.coachId!.isNotEmpty) {
          ref.watch(dietitianProfileProvider(client.coachId!));
        }
        final List<Widget> widgetOptions = <Widget>[
          HomeScreen(client: client),
          PlanTimelineScreen(client: client),
          ActivityTrackerScreen(client: client),
          WellnessHubScreen(client: client),
          CoachTab(client: client),
        ];

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          extendBody: true,
          // 🚀 PERFORMANCE FIX: IndexedStack prevents screens from fully rebuilding on tab switch
          body: IndexedStack(
            index: _selectedIndex,
            children: widgetOptions,
          ),
          bottomNavigationBar: ModernBottomBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            unreadChatCount: unreadCount,
          ),
        );
      },
    );
  }
}

// =================================================================
// 🎯 PREMIUM PROGRESS REPORT CARD (SCALED & POLISHED)
// =================================================================

class ProgressReportCard extends ConsumerStatefulWidget {
  final String clientId;
  const ProgressReportCard({super.key, required this.clientId});

  @override
  ConsumerState<ProgressReportCard> createState() => _ProgressReportCardState();
}

class _ProgressReportCardState extends ConsumerState<ProgressReportCard> {
  int _selectedDays = 7;
  final List<int> _dayOptions = [7, 15, 30, 90];

  @override
  Widget build(BuildContext context) {
    final dailyLogHistoryAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final vitalsHistoryAsync = ref.watch(vitalsHistoryProvider(widget.clientId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: context.scale(8.0), horizontal: context.scale(20.0)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(context.scale(24.0)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: context.scale(15), offset: Offset(0, context.scale(8)))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: colorScheme.primary,
          collapsedIconColor: theme.hintColor,
          tilePadding: EdgeInsets.symmetric(horizontal: context.scale(20.0), vertical: context.scale(4.0)),
          leading: Container(
            padding: EdgeInsets.all(context.scale(10)),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.insights_rounded, color: colorScheme.primary, size: context.scale(20)),
          ),
          title: Text('CLINICAL PROGRESS', style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(13), fontWeight: FontWeight.w700, color: colorScheme.onSurface, letterSpacing: 0.5)),
          subtitle: Text('Showing trends from last $_selectedDays days', style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(11))),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.scale(20.0), vertical: context.scale(8.0)),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: _dayOptions.map((days) => ButtonSegment<int>(value: days, label: Text('${days}D', style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11), fontWeight: FontWeight.bold)))).toList(),
                  selected: {_selectedDays},
                  onSelectionChanged: (Set<int> newSelection) {
                    HapticFeedback.selectionClick(); // 🚀 Tactile feedback
                    setState(() => _selectedDays = newSelection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: colorScheme.primary.withOpacity(0.15),
                    selectedForegroundColor: colorScheme.primary,
                    foregroundColor: theme.hintColor,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                ),
              ),
            ),

            // 1. DAILY LOGS CHART
            dailyLogHistoryAsync.when(
              loading: () => Padding(padding: EdgeInsets.all(context.scale(32.0)), child: Center(child: CircularProgressIndicator(color: colorScheme.primary))),
              error: (e, s) => Padding(padding: EdgeInsets.all(context.scale(16.0)), child: Text('Data error', style: TextStyle(fontFamily: kBodyFont, color: colorScheme.error, fontSize: context.scale(11)))),
              data: (groupedLogs) {
                final Map<String, double> stepData = {};
                final Map<String, double> calorieData = {};
                final Map<String, double> sleepData = {};
                final Map<String, double> hydrationData = {};

                final sortedDates = groupedLogs.keys.toList()..sort();
                for (var date in sortedDates) {
                  final dayLabel = DateFormat('d/M').format(date);
                  final log = groupedLogs[date];
                  stepData[dayLabel] = (log?.stepCount ?? 0).toDouble();
                  calorieData[dayLabel] = (log?.caloriesBurned ?? 0).toDouble();
                  sleepData[dayLabel] = (log?.totalSleepDurationHours ?? 0).toDouble();
                  hydrationData[dayLabel] = (log?.hydrationLiters ?? 0).toDouble();
                }

                return Padding(
                  padding: EdgeInsets.all(context.scale(20.0)),
                  child: Column(
                    children: [
                      _buildChartContainer(context, 'STEPS & CALORIES BURNED', _buildLineChart(context, stepData, calorieData)),
                      SizedBox(height: context.scale(24)),
                      _buildChartContainer(context, 'SLEEP DURATION & HYDRATION', _buildLineChart(context, sleepData, hydrationData, isSleep: true)),
                    ],
                  ),
                );
              },
            ),

            // 2. CLINICAL VITALS CHART
            vitalsHistoryAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (vitalsList) {
                  final Map<String, double> fbsData = {};
                  final Map<String, double> weightData = {};
                  final Map<String, double> bpSystolicData = {};

                  final startDate = DateTime.now().subtract(Duration(days: _selectedDays));
                  final filteredVitals = vitalsList.where((v) => !v.date.isBefore(startDate)).toList()..sort((a, b) => a.date.compareTo(b.date));

                  for (final vitals in filteredVitals) {
                    final dayLabel = DateFormat('d/M').format(vitals.date);
                    if (vitals.labResults['fbs'] != null) fbsData[dayLabel] = vitals.labResults['fbs']!;
                    if (vitals.weightKg > 0) weightData[dayLabel] = vitals.weightKg;
                    if (vitals.bloodPressureSystolic != null) bpSystolicData[dayLabel] = vitals.bloodPressureSystolic!.toDouble();
                  }

                  if (weightData.isEmpty && bpSystolicData.isEmpty && fbsData.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: EdgeInsets.fromLTRB(context.scale(20), 0, context.scale(20), context.scale(20)),
                    child: Column(
                      children: [
                        if (weightData.isNotEmpty) ...[
                          _buildChartContainer(context, 'WEIGHT TRENDS (kg)', _buildLineChart(context, weightData, {})),
                          SizedBox(height: context.scale(24)),
                        ],
                        if (bpSystolicData.isNotEmpty) ...[
                          _buildChartContainer(context, 'SYSTOLIC BP (mmHg)', _buildLineChart(context, bpSystolicData, {}, isBloodPressure: true)),
                        ],
                      ],
                    ),
                  );
                }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer(BuildContext context, String title, Widget chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Theme.of(context).hintColor)),
        SizedBox(height: context.scale(12)),
        SizedBox(height: context.scale(160), child: chart),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, Map<String, double> data1, Map<String, double> data2, {bool isSleep = false, bool isBloodPressure = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<FlSpot> spots1 = [];
    final List<FlSpot> spots2 = [];
    final allKeys = (data1.keys.toSet()..addAll(data2.keys)).toList();
    try { allKeys.sort((a, b) => DateFormat('d/M').parse(a).compareTo(DateFormat('d/M').parse(b))); } catch (e) { allKeys.sort(); }

    for (int i = 0; i < allKeys.length; i++) {
      if (data1.containsKey(allKeys[i])) spots1.add(FlSpot(i.toDouble(), data1[allKeys[i]]!));
      if (data2.containsKey(allKeys[i])) spots2.add(FlSpot(i.toDouble(), data2[allKeys[i]]!));
    }

    Color c1 = colorScheme.primary;
    Color c2 = isDark ? Colors.orangeAccent : Colors.orange;
    if (isSleep) c2 = colorScheme.secondary;
    if (isBloodPressure) c1 = Colors.redAccent;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.onSurface.withOpacity(0.05), strokeWidth: 1, dashArray: [4, 4])
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.scale(26), // 🚀 Prevents bottom text clipping
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= allKeys.length || (_selectedDays > 10 && index % 3 != 0)) return const SizedBox();
                return SideTitleWidget(
                    meta: meta, // 🚀 Required in newer fl_chart versions
                    space: context.scale(6),
                    child: Text(allKeys[index], style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(9), fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.5)))
                );
              }
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.scale(36), // 🚀 Prevents large numbers from clipping
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                    meta: meta,
                    space: context.scale(6),
                    child: Text(value.toInt().toString(), style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(9), fontWeight: FontWeight.bold, color: colorScheme.onSurface.withOpacity(0.5)))
                );
              }
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        // 🚀 Premium Tooltips when you tap the chart
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => isDark ? Colors.white : Colors.black87,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) => LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  TextStyle(fontFamily: kDisplayFont, color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w700, fontSize: context.scale(12)),
                )).toList();
              }
          ),
        ),
        lineBarsData: [
          if(spots1.isNotEmpty) LineChartBarData(
              spots: spots1, isCurved: true, color: c1, barWidth: context.scale(3),
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: c1.withOpacity(0.1))
          ),
          if(spots2.isNotEmpty) LineChartBarData(
              spots: spots2, isCurved: true, color: c2, barWidth: context.scale(3),
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: c2.withOpacity(0.1))
          ),
        ],
      ),
    );
  }
}