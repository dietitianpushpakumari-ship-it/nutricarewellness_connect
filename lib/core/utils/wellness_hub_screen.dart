import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/breathing_detail_screen.dart';
import 'package:nutricare_connect/core/utils/daily_wellness_sheet.dart';
import 'package:nutricare_connect/core/utils/quiz_swipe_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/log_vitals_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/sleep_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:collection/collection.dart';

import 'mindfullness_config.dart';

class WellnessHubScreen extends ConsumerWidget {
  final ClientModel client;

  const WellnessHubScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch last 7 days of logs for the Mood Trend
    final historyAsync = ref.watch(
      historicalLogProvider((clientId: client.id, days: 7)),
    );
    final state = ref.read(activeDietPlanProvider);
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    final dailyLog = state.dailyLogs.firstWhereOrNull(
      (l) => l.mealName == 'DAILY_WELLNESS_CHECK',
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: CustomScrollView(
          slivers: [
            // 1. Header & Mood Trend
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Wellness Sanctuary",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMoodTrendCard(context, historyAsync),
                  ],
                ),
              ),
            ),

            // 2. Tools Grid Title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  "Body & Mind Tools",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // 3. The Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [


                  _buildToolCard(
                      context,
                      "Breathing",
                      "Relax Now",
                      Icons.self_improvement,
                      Colors.teal,
                          () {
                        // 🎯 Get providers
                        final state = ref.read(activeDietPlanProvider);
                        if (state.activePlan == null) return;

                        final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);
                        final dailyLog = state.dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

                        // 🎯 Show the menu
                        _showBreathingMenu(context, notifier, state.activePlan!, dailyLog);
                      }
                  ),
                  _buildToolCard(
                    context,
                    "Sleep Lab",
                    "Analyze Rest",
                    Icons.bedtime,
                    Colors.indigo,
                    () {
                      if (state.activePlan == null) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SleepEntryDialog(
                          notifier: notifier,
                          activePlan: state.activePlan!,
                          dailyMetricsLog: dailyLog,
                        ),
                      );
                    },
                  ),
                  _buildToolCard(
                    context,
                    "Vitals",
                    "Log Reports",
                    Icons.monitor_heart,
                    Colors.red,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LogVitalsScreen(clientId: client.id),
                      ),
                    ),
                  ),
                  _buildToolCard(
                    context,
                    "Journal",
                    "Reflect",
                    Icons.book,
                    Colors.amber,
                    () {
                      if (state.activePlan == null) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => DailyWellnessSheet(
                          notifier: notifier,
                          activePlan: state.activePlan!,
                          dailyLog: dailyLog,
                        ),
                      );
                    },
                  ),
                  _buildToolCard(
                      context, "Nutri-Quiz", "Daily Mix", Icons.school, Colors.deepPurple,
                          () {
                        // 🎯 DIRECT NAVIGATION (No Category Selection)
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const QuizSwipeScreen() // Passing 'Mixed' as a flag
                            )
                        );
                      }
                  ),


                ],
              ),
            ),

            // 4. Library Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Text(
                  "Knowledge Library",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // 5. Library Categories
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildLibraryCard(
                      context,
                      "Diabetes",
                      Icons.bloodtype,
                      Colors.red.shade100,
                      Colors.red.shade800,
                    ),
                    _buildLibraryCard(
                      context,
                      "Heart",
                      Icons.favorite,
                      Colors.pink.shade100,
                      Colors.pink.shade800,
                    ),
                    _buildLibraryCard(
                      context,
                      "Gut Health",
                      Icons.spa,
                      Colors.green.shade100,
                      Colors.green.shade800,
                    ),
                    _buildLibraryCard(
                      context,
                      "Mind",
                      Icons.psychology,
                      Colors.purple.shade100,
                      Colors.purple.shade800,
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
  Widget _buildTopicTile(BuildContext context, String title, IconData icon,
      Color color) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context); // Close sheet
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => QuizSwipeScreen()));
      },
    );
  }
  // --- WIDGETS ---

  Widget _buildMoodTrendCard(
    BuildContext context,
    AsyncValue<Map<DateTime, List<ClientLogModel>>> historyAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Emotional Weather",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            child: historyAsync.when(
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (_, __) => const SizedBox(),
              data: (groupedLogs) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    // Last 7 days
                    final date = DateTime.now().subtract(
                      Duration(days: 6 - index),
                    );
                    final dayKey = DateTime(date.year, date.month, date.day);
                    final log = groupedLogs[dayKey]?.firstWhereOrNull(
                      (l) => l.mealName == 'DAILY_WELLNESS_CHECK',
                    );

                    final int mood = log?.moodLevelRating ?? 0;
                    final String label = DateFormat(
                      'E',
                    ).format(date)[0]; // M, T, W...

                    // Mood Icons
                    IconData icon = Icons.circle;
                    Color color = Colors.grey.shade200;

                    if (mood >= 4) {
                      icon = Icons.wb_sunny;
                      color = Colors.orange;
                    } else if (mood == 3) {
                      icon = Icons.cloud;
                      color = Colors.blue.shade300;
                    } else if (mood > 0) {
                      icon = Icons.tsunami;
                      color = Colors.blueGrey;
                    } // Stormy

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(icon, color: color, size: 24),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, String title, String subtitle, IconData icon, MaterialColor color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle),
              child: Icon(icon, color: color.shade700, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }


  Widget _buildLibraryCard(
    BuildContext context,
    String title,
    IconData icon,
    Color bg,
    Color accent,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: accent,
              fontSize: 14,
            ),
          ),
          Text(
            "Read More",
            style: TextStyle(color: accent.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

void _showBreathingMenu(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel activePlan, ClientLogModel? dailyLog) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Choose a Mode", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _buildPresetTile(
            ctx,
            "Focus & Clarity",
            "Box Breathing (4-4-4-4)",
            Icons.crop_square,
            Colors.teal,
                () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.box),
          ),
          _buildPresetTile(
            ctx,
            "Sleep & Anxiety",
            "4-7-8 Relaxing Breath",
            Icons.nightlight_round,
            Colors.indigo,
                () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.relax),
          ),
          _buildPresetTile(
            ctx,
            "Energy Boost",
            "Rapid Awakening",
            Icons.bolt,
            Colors.orange,
                () => _launchBreathingSheet(context, notifier, activePlan, dailyLog, BreathingConfig.energy),
          ),
        ],
      ),
    ),
  );
}

void _launchBreathingSheet(BuildContext context, DietPlanNotifier notifier, ClientDietPlanModel plan, ClientLogModel? log, BreathingConfig config) {
  Navigator.pop(context); // Close the menu
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BreathingDetailSheet(
      notifier: notifier,
      activePlan: plan,
      dailyLog: log,
      config: config, // 🎯 Pass the selected config here
    ),
  );
}

Widget _buildPresetTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    onTap: onTap,
  );
}


