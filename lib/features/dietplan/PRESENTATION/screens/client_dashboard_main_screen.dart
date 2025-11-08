import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_log_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/daily_wellness_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/diet_plan_dashboard_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/plan_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/water_quick_add_model.dart';
import 'package:nutricare_connect/features/dietplan/dATA/repositories/diet_repositories.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/programme_feature_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/schedule_meeting_utils.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';
import 'package:url_launcher/url_launcher.dart';

// 🎯 ADJUST IMPORTS

// Import necessary core files
import '../../../../services/client_service.dart';
import '../../domain/entities/client_diet_plan_model.dart';
import '../../domain/entities/client_log_model.dart';
import '../providers/diet_plan_provider.dart';

// --- MOCK/CONCEPTUAL DATA STRUCTURES (Must be defined/imported elsewhere) ---

class ActivityData {
  final double waterL;
  final int steps;
  final int calories;
  // 🎯 NEW FIELDS: Daily Goals (Assumed to be set by Admin)
  final double goalWaterLiters;
  final int goalSteps;

  ActivityData({this.waterL = 1.5, this.steps = 4500, this.calories = 1200,this.goalWaterLiters = 3.0, this.goalSteps = 8000});

  ActivityData copyWith({double? waterL, int? steps, int? calories}) =>
      ActivityData(
        waterL: waterL ?? this.waterL,
        steps: steps ?? this.steps,
        calories: calories ?? this.calories,
        goalWaterLiters: goalWaterLiters, // Preserve goals
        goalSteps: goalSteps,
      );
}

class WaterSize {
  final String label;
  final double volumeL;
  final IconData icon;

  const WaterSize({required this.label, required this.volumeL, required this.icon});
}

// 🎯 FIX: Define the required list of standard sizes
const List<WaterSize> standardSizes = [
  WaterSize(label: 'Small Glass', volumeL: 0.25, icon: Icons.local_drink),
  WaterSize(label: 'Large Glass', volumeL: 0.40, icon: Icons.local_drink_outlined),
  WaterSize(label: 'Small Bottle', volumeL: 0.75, icon: Icons.water_drop),
  WaterSize(label: 'Big Bottle', volumeL: 1.0, icon: Icons.water_drop_outlined),
];

//final dietitianInfoProvider = Provider((ref) => DietitianInfo());
final activityDataProvider = StateProvider((ref) => ActivityData());
// 🎯 UPDATED PROVIDER:
//final activityDataProvider = StateProvider((ref) => ActivityData(
  //  waterL: 1.5, steps: 4500, calories: 1200,
    //goalWaterLiters: 3.0, // Admin sets 3.0L goal
    //goalSteps: 8000 // Admin sets 8000 steps goal
//));
//final upcomingMeetingsProvider = Provider((ref) => [MeetingModel(startTime: DateTime.now().add(const Duration(days: 2)), id: '', clil(std: '', meetingType: '', purpose: '', createdAt: null, updatedAt: null)]);
// --------------------------------------------------------------------------

class ClientDashboardScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const ClientDashboardScreen({super.key, required this.client});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;
  ClientDietPlanModel? activePlan;

  @override
  void initState() {
    super.initState();
    // Initialize content pages based on client data
    _widgetOptions = <Widget>[
      _HomeScreen(client: widget.client), // Index 0: Home
       PlanScreen(client: widget.client), // Index 1: Plan/Log
      _TrackerScreen(client: widget.client),
      _AddOnsScreen(client: widget.client), // Index 2: Add-ons

      _FeedScreen(), // Index 3: Content
      _CoachScreen(client: widget.client), // Index 4: Coach
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, ${widget.client.name?.split(' ').first}"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Log History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ClientLogHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
        ],
      ),

      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),

      // --- BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Plan'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Tracker2',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Feed'),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'Coach',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo.shade700,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        // Use fixed for 5 items
        onTap: _onItemTapped,
      ),
    );
  }

  void initialize() async {
    activePlan = await DietRepository().getActivePlan(widget.client.id);
  }
}

// =================================================================
// --- TAB 0: HOME SCREEN (Snapshot & Progress) ---
// =================================================================

class _HomeScreen extends ConsumerWidget {
  final ClientModel client;

  const _HomeScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityData = ref.watch(activityDataProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Snapshot Card
          _buildGreetingCard(context, client),
          const SizedBox(height: 20),

          _buildHydrationTracker(context, ref, activityData),
          const SizedBox(height: 20),

          // Progress Graph
          _buildProgressGraph(context),
          const SizedBox(height: 20),

          // Quick Stats/Trackers
          _buildQuickTracker(context, ref, activityData),
        ],
      ),
    );
  }


  Widget _buildHydrationTracker(BuildContext context, WidgetRef ref, ActivityData activityData) {
    final currentIntake = activityData.waterL;
    final goalLiters = activityData.goalWaterLiters;
    final progress = (currentIntake / goalLiters).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Hydration Goal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Visual Container (Glass/Bottle)
                Container(
                  width: 80,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Animated Water Level
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        height: 120 * progress,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade300.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Current Volume Text
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('${currentIntake.toStringAsFixed(1)} L',
                            style: TextStyle(
                                color: progress > 0.5 ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // 2. Status and Goal Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target: ${goalLiters.toStringAsFixed(1)} L', style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600)),
                      Text('Progress: ${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 10),

                      // Action to Add Water (Simple Button)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (_) => WaterQuickAddModal(
                                currentData: activityData,
                                activityProvider: activityDataProvider, // Pass the provider for direct modification
                              )
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Water'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          backgroundColor: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard(BuildContext context, ClientModel clientInfo) {
    // Gradient Background
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.9),
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${clientInfo.name}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.white70),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoBox(
                  context,
                  label: 'Age',
                  value: '${clientInfo.age ?? 'N/A'} yrs',
                  icon: Icons.cake,
                  color: Colors.white,
                ),
                _buildInfoBox(
                  context,
                  label: 'Weight',
                  value: '75.5 kg',
                  icon: Icons.monitor_weight,
                  color: Colors.white,
                ),
                _buildInfoBox(
                  context,
                  label: 'BMI',
                  value: '25.3',
                  icon: Icons.straighten,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressGraph(BuildContext context) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.auto_graph, color: Colors.blue),
        title: const Text('Progress History (Weight & Metrics)'),
        subtitle: const Text('Last Updated: Today'),
        children: [
          Container(
            height: 150,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const Text(
              'Graph Placeholder: Weight Trend',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTracker(
    BuildContext context,
    WidgetRef ref,
    ActivityData activityData,
  ) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.opacity, color: Colors.blue.shade600),
            title: const Text('Water Consumption'),
            subtitle: Text(
              '${activityData.waterL.toStringAsFixed(1)} L / 3.0 L Goal',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () {
                final newWater = (activityData.waterL + 0.5)
                    .clamp(0.0, 3.0)
                    .toDouble();
                ref.read(activityDataProvider.notifier).state = activityData
                    .copyWith(waterL: newWater);
              },
            ),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.directions_run, color: Colors.orange),
            title: const Text('Steps Count'),
            subtitle: Text('${activityData.steps} Steps / 8000 Goal'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.flash_on, color: Colors.red),
            title: const Text('Calories Logged'),
            subtitle: Text('${activityData.calories} KCal Today'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// --- TAB 1: PLAN SCREEN (Diet Plan & Logging) ---
// =================================================================
// ... (omitted existing code up to _PlanScreen) ...


// =================================================================
// --- TAB 2: ADD-ONS (Health Tools) ---
// =================================================================

class _AddOnsScreen extends ConsumerWidget {
  final ClientModel client;

  const _AddOnsScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Lab Reports / Vitals History
        _buildFeatureCard(
          context,
          'Lab Reports & History',
          'View past vital records and lab reports.',
          Icons.document_scanner,
          Colors.red,
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LabReportListScreen(client: client),
            ),
          ),
        ),

        // Calorie Counter / Steps (Placeholder for external tracking)
        _buildFeatureCard(
          context,
          'Steps & Calorie Count',
          'Link your fitness tracker or log activities manually.',
          Icons.directions_run,
          Colors.orange,
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activity tracking setup required.')),
          ),
        ),

        // Medication / Reminders
        _buildFeatureCard(
          context,
          'Medication / Supplement Reminders',
          'Set alerts for your prescribed medication schedule.',
          Icons.alarm,
          Colors.teal,
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medication reminder feature coming soon.'),
            ),
          ),
        ),

        // Breathing Exercises (Placeholder)
        _buildFeatureCard(
          context,
          'Breathing Exercises',
          'Quick 5-minute stress reduction sessions.',
          Icons.self_improvement,
          Colors.purple,
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Breathing exercise module coming soon.'),
            ),
          ),
        ),

        // Scan & Find Age (Placeholder)
        _buildFeatureCard(
          context,
          'Scan & Find Age (Add-on)',
          'Use the camera to scan objects (e.g., food label or face).',
          Icons.camera_alt,
          Colors.pink,
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scan feature integration required.')),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// =================================================================
// --- TAB 3: CONTENT FEED (Notifications, Recipes, Offers) ---
// =================================================================

class _FeedScreen extends ConsumerWidget {
  const _FeedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Daily Content & Exclusive Offers',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Divider(),

        _buildContentTile(
          context,
          'Video: Daily Yoga Routine',
          FontAwesomeIcons.youtube,
          Colors.red,
          url: 'https://youtube.com/yogavideo',
        ),
        _buildContentTile(
          context,
          'Recipe: Low Carb Breakfast',
          Icons.local_dining,
          Colors.green,
          url: 'https://nutricare.com/recipe',
        ),
        _buildContentTile(
          context,
          'Tip: Hydration Secrets',
          Icons.lightbulb,
          Colors.amber,
          url: 'https://nutricare.com/tip',
        ),
        _buildContentTile(
          context,
          'Ad: New Coaching Offer',
          Icons.campaign,
          Colors.blue,
          url: 'https://nutricare.com/offer',
        ),
        _buildContentTile(
          context,
          'Client Story: Success',
          Icons.star,
          Colors.purple,
          url: 'https://nutricare.com/story',
        ),
      ],
    );
  }

  Widget _buildContentTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color, {
    String? url,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 24),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () {
          if (url != null) _launchUrl(url, context);
        },
      ),
    );
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

// =================================================================
// --- TAB 4: COACH SCREEN (Support & Appointments) ---
// =================================================================

class _CoachScreen extends ConsumerWidget {
  final ClientModel client;

  const _CoachScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dietitianInfoAsync = ref.watch(dietitianProfileProvider);
    final upcomingMeetingsAsync = ref.watch(
      upcomingMeetingsProvider(client.id),
    );

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Know Your Dietitian Section (using AsyncValue.when)
        dietitianInfoAsync.when(
          loading: () => const Center(child: Text('Loading dietitian info...')),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (dietitianProfile) {
            if (dietitianProfile == null) return const SizedBox.shrink();
            // Create a simple Info object for display convenience
            //final dietitianInfo = Diet.fromAdminProfile(dietitianProfile);

            return Column(
              children: [
                Card(
                  elevation: 4,
                  child: ListTile(
                    leading: Icon(
                      Icons.person_pin,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                    title: Text(
                      'Your Dietitian: ${dietitianProfile.firstName} ${dietitianProfile.lastName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text('Email: ${dietitianProfile.companyEmail}'),
                  ),
                ),
                const SizedBox(height: 20),
                _buildContactActions(context, client, dietitianProfile),
                // Pass the simple info object
              ],
            );
          },
        ),
        // Upcoming Appointments
        _buildAppointmentsSection(context, upcomingMeetingsAsync),
      ],
    );
  }

  Widget _buildContactActions(
    BuildContext context,
    ClientModel clientInfo,
    AdminProfileModel dietitianInfo,
  ) {
    final bool hasWebsite = dietitianInfo.website?.isNotEmpty == true;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direct Contact',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildContactButton(
                  'Call',
                  Icons.phone,
                  Colors.blue,
                  () => _launchUrl('tel:${dietitianInfo.mobile}', context),
                ),
                _buildContactButton(
                  'Email',
                  Icons.email,
                  Colors.red,
                  () => _launchUrl(
                    'mailto:${dietitianInfo.companyEmail}',
                    context,
                  ),
                ),
                _buildContactButton(
                  'WhatsApp',
                  FontAwesomeIcons.whatsapp,
                  Colors.green,
                  () => _launchUrl(
                    'https://wa.me/${client.whatsappNumber ?? client.mobile}',
                    context,
                  ),
                ),
                if (hasWebsite)
                  _buildContactButton('Website', Icons.web, Colors.purple, () {
                    // Ensure URL has http/https prefix for launching
                    String url = dietitianInfo.website!;
                    if (!url.startsWith('http')) {
                      url = 'https://$url';
                    }
                    _launchUrl(url, context);
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsSection(
    BuildContext context,
    AsyncValue<List<MeetingModel>> meetingsAsync,
  ) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.event, color: Colors.red),
        title: const Text('Upcoming Appointments'),
        children: [
          meetingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Failed to load appointments: $e'),
            ),
            data: (meetings) {
              if (meetings.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No upcoming sessions scheduled.'),
                );
              }
              return Column(
                children: [
                  ...meetings
                      .map(
                        (meeting) => ListTile(
                          title: Text(meeting.purpose),
                          subtitle: Text(
                            DateFormat(
                              'EEE, MMM d, h:mm a',
                            ).format(meeting.startTime),
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              // You can implement launching the meet link or a reschedule dialog here
                            },
                            child: const Text('Join/Edit'),
                          ),
                        ),
                      )
                      .toList(),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add_task),
                    title: const Text('Request New Session'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Launching scheduling form...'),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

// NOTE: This code replaces the entire _TrackerScreen class definition.

class _TrackerScreen extends ConsumerWidget {
  final ClientModel client;

  const _TrackerScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Live Activity Data (Water/Steps)
    final activityData = ref.watch(activityDataProvider);

    // 2. Latest Vitals Data (For Profile/Medical History)
    final latestVitalsAsync = ref.watch(latestVitalsFutureProvider(client.id));

    // 3. Client Assignments (For Package Status)
    // NOTE: This should be replaced with a proper provider fetching PackageAssignmentModel
    final assignedPackagesAsync = ref.watch(
      assignedPackageProvider(client.id),
    );

    final weeklyLogsAsync = ref.watch(weeklyLogHistoryProvider(client.id));

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [

        Text('Activity Input Tools', style: Theme.of(context).textTheme.headlineSmall),
        const Divider(),

        // 🎯 1. Water Intake Input (Tap to add standard sizes)
        _buildWaterInputSection(context, ref, activityData),
        const SizedBox(height: 20),

        // 🎯 2. Steps Input (Simplified for quick logging)
        _buildStepInputSection(context, ref, activityData),
        const SizedBox(height: 20),
        // --- 1. CORE TRACKING TOOLS (Water/Steps/Calories) ---
        _buildCoreTrackingSection(context, ref, activityData),
        const SizedBox(height: 20),

        _buildWeeklyLogHistory(context, weeklyLogsAsync, client.id),
        const SizedBox(height: 20),

        // --- 2. CLIENT MEDICAL PROFILE OVERVIEW ---
        latestVitalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) =>
              Center(child: Text('Error loading medical data: $e')),
          data: (vitals) => _buildClientProfileOverview(context, vitals),
        ),
        const SizedBox(height: 20),

        // --- 3. PACKAGE & PAYMENT STATUS ---
        assignedPackagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) =>
              Center(child: Text('Error loading package data: $e')),
          data: (assignedPackage) => _buildPackagePaymentStatus(
            context,
            assignedPackage,
          ), // Reusing meetings data structure as placeholder
        ),
        const SizedBox(height: 20),

        // --- 4. ADD-ON HEALTH FEATURES ---
        _buildAddOnFeatures(context),
      ],
    );
  }


  Widget _buildWaterInputSection(BuildContext context, WidgetRef ref, ActivityData activityData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log Water Intake', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue.shade700)),
            Text('Current: ${activityData.waterL.toStringAsFixed(2)} L / ${activityData.goalWaterLiters.toStringAsFixed(1)} L', style: TextStyle(color: Colors.grey.shade600)),
            const Divider(),

            // Input Buttons (Standard Sizes)
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: standardSizes.map((size) {
                return OutlinedButton.icon(
                  onPressed: () {
                    final newVolume = (activityData.waterL + size.volumeL).clamp(0.0, 10.0).toDouble();
                    ref.read(activityDataProvider.notifier).state = activityData.copyWith(waterL: newVolume);
                  },
                  icon: Icon(size.icon, size: 18),
                  label: Text(size.label),
                );
              }).toList(),
            ),

            TextButton(
              onPressed: () {
                ref.read(activityDataProvider.notifier).state = activityData.copyWith(waterL: 0.0);
              },
              child: const Text('Reset Today\'s Water'),
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Step Count Input Section ---
  Widget _buildStepInputSection(BuildContext context, WidgetRef ref, ActivityData activityData) {
    final stepsController = TextEditingController(text: activityData.steps.toString());

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Steps Count', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.orange.shade700)),
            const Divider(),

            TextFormField(
              controller: stepsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter Today\'s Steps',
                hintText: '${activityData.steps} (Current)',
                suffixText: 'Steps',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                final newSteps = int.tryParse(stepsController.text) ?? activityData.steps;
                ref.read(activityDataProvider.notifier).state = activityData.copyWith(steps: newSteps);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Steps updated!')));
              },
              icon: const Icon(Icons.update),
              label: const Text('Update Steps'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyLogHistory(BuildContext context, AsyncValue<Map<DateTime, List<ClientLogModel>>> logsAsync, String clientId) {
    return Card(
      elevation: 4,
      child: ExpansionTile(
        leading: const Icon(Icons.history, color: Colors.blueGrey),
        title: const Text('Last 7 Days Log History', style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: true,

        children: [
          logsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(16.0), child: LinearProgressIndicator()),
            error: (e, s) => Padding(padding: const EdgeInsets.all(16.0), child: Text('Failed to load logs: $e')),
            data: (groupedLogs) {
              final sortedDays = groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a));

              if (sortedDays.isEmpty) {
                return const Padding(padding: EdgeInsets.all(16.0), child: Text('No log entries in the last 7 days.'));
              }

              return Column(
                children: sortedDays.map((date) {
                  final logs = groupedLogs[date]!;
                  final mealsLogged = logs.where((l) => l.mealName != 'DAILY_WELLNESS_CHECK').length;
                  final wellnessComplete = logs.any((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
                  final colorScheme = Theme.of(context).colorScheme;

                  return ListTile(
                    onTap: () {
                      // 🎯 LAUNCH DETAILED MODAL on tap
                      _showDailyLogDetailModal(context, logs, date);
                    },
                    leading: Icon(
                      wellnessComplete ? Icons.star : Icons.chevron_right,
                      color: wellnessComplete ? colorScheme.primary : Colors.grey,
                    ),
                    title: Text(DateFormat('EEEE, MMM d').format(date)),
                    subtitle: Text(
                      '${mealsLogged} Meals Logged | ${wellnessComplete ? 'Wellness Check COMPLETE' : 'Wellness Check MISSING'}',
                      style: TextStyle(fontSize: 12, color: mealsLogged > 0 ? Colors.black87 : Colors.red),
                    ),
                    trailing: const Icon(Icons.search),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          // Link to Full History
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('View Full History Archive'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to the old ClientLogHistoryScreen if needed
            },
          ),
        ],
      ),
    );
  }

  // 🎯 NEW: DETAILED VIEW MODAL
  void _showDailyLogDetailModal(BuildContext context, List<ClientLogModel> logs, DateTime date) {
    // 1. Separate logs: meals vs. wellness check
    final mealLogs = logs.where((l) => l.mealName != 'DAILY_WELLNESS_CHECK').toList();
    final wellnessLog = logs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return _DailyLogDetailContent(
              controller: controller,
              date: date,
              mealLogs: mealLogs,
              wellnessLog: wellnessLog,
            );
          },
        );
      },
    );
  }

  // --- Core Tracking Tools (Reused from Home Screen) ---
  Widget _buildCoreTrackingSection(
    BuildContext context,
    WidgetRef ref,
    ActivityData activityData,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Key Metrics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),

            // Water Consumption
            ListTile(
              leading: Icon(Icons.opacity, color: Colors.blue.shade600),
              title: const Text('Water Consumption'),
              subtitle: Text(
                '${activityData.waterL.toStringAsFixed(1)} L / 3.0 L Goal',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () {
                  final newWater = (activityData.waterL + 0.5)
                      .clamp(0.0, 3.0)
                      .toDouble();
                  ref.read(activityDataProvider.notifier).state = activityData
                      .copyWith(waterL: newWater);
                },
              ),
            ),

            // Steps & Calories
            ListTile(
              leading: const Icon(Icons.directions_run, color: Colors.orange),
              title: const Text('Steps & Calorie Count'),
              subtitle: Text(
                '${activityData.steps} Steps | ${activityData.calories} KCal Logged',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log activity manually.')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. NEW: CLIENT PROFILE OVERVIEW ---
  Widget _buildClientProfileOverview(
    BuildContext context,
    VitalsModel? vitals,
  ) {
    final hasMedicalData = vitals != null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 4,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.medical_services, color: primaryColor),
        title: const Text(
          'Medical Profile Overview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          hasMedicalData
              ? 'Last Vitals: ${DateFormat.yMMMd().format(vitals.date)}'
              : 'No Vitals History',
        ),

        children: [
          if (hasMedicalData)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileRow(
                    'Food Habit',
                    vitals.foodHabit ?? 'N/A',
                    Icons.dinner_dining,
                    Colors.green,
                  ),
                  _buildProfileRow(
                    'Activity Level',
                    vitals.activityType ?? 'N/A',
                    Icons.fitness_center,
                    Colors.orange,
                  ),
                  _buildProfileRow(
                    'Primary Complaint',
                    vitals.complaints ?? 'N/A',
                    Icons.sick,
                    Colors.red,
                  ),
                  _buildProfileRow(
                    'Med. History',
                    vitals.medicalHistoryDurations ?? 'None',
                    Icons.history_edu,
                    Colors.blueGrey,
                  ),

                  const Divider(height: 20),
                  Text(
                    'Lab/Vitals Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  _buildProfileRow(
                    'Weight',
                    '${vitals.weightKg.toStringAsFixed(1)} kg',
                    Icons.monitor_weight,
                    primaryColor,
                  ),
                  _buildProfileRow(
                    'BMI',
                    vitals.bmi.toStringAsFixed(1),
                    Icons.straighten,
                    primaryColor,
                  ),
                ],
              ),
            ),

          // Link to Full Reports
          ListTile(
            leading: const Icon(Icons.document_scanner),
            title: const Text('View Full Lab Reports & Vitals History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Assuming VitalsHistoryPage handles the display of all records
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LabReportListScreen(client: client),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper for displaying profile rows
  Widget _buildProfileRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  // --- 3. NEW: PACKAGE & PAYMENT STATUS ---
  // --- 3. NEW: PACKAGE & PAYMENT STATUS (FIXED IMPLEMENTATION) ---
  // NOTE: This method assumes the surrounding helper methods like _buildProfileRow and _launchUrl are defined.

// --- 3. NEW: PACKAGE & PAYMENT STATUS (FINAL DYNAMIC IMPLEMENTATION) ---
  Widget _buildPackagePaymentStatus(
      BuildContext context,
      List<PackageAssignmentModel> assignments,
      ) {

    // 1. Identify the primary active assignment
    final activeAssignment = assignments.firstWhereOrNull((a) => a.isActive);

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    final hasActivePackage = activeAssignment != null;
    final packageId = activeAssignment?.packageId;

    // --- Early Exit for No Package ---
    if (!hasActivePackage || packageId == null) {
      return Card(
        elevation: 4,
        child: ExpansionTile(
          leading: Icon(Icons.card_membership, color: colorScheme.secondary),
          title: const Text('Package & Payment Status', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('No Active Package'),
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No active packages. Schedule a consultation to book your plan.'),
            ),
          ],
        ),
      );
    }

    // Calculate financial details based on the assignment model
    final double netBooked = activeAssignment!.bookedAmount;
    final double mockCollected = activeAssignment.bookedAmount * 0.7; // MOCK: Assume 70% collected
    final double pending = netBooked - mockCollected;


    return FutureBuilder<PackageModel>( // 🎯 STEP A: Fetch Package Details (Async)
      future: PackageService().getAllActivePackagesById(packageId),
      builder: (context, snapshot) {

        final PackageModel? packageDetails = snapshot.data;
        final bool isDataLoaded = snapshot.connectionState == ConnectionState.done && snapshot.hasData;

        final List<String> featureIds = packageDetails?.programFeatureIds ?? [];

        return Card(
          elevation: 4,
          child: ExpansionTile(
            leading: Icon(Icons.card_membership, color: colorScheme.secondary),
            title: const Text('Package & Payment Status', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(activeAssignment.packageName),

            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(padding: EdgeInsets.all(16.0), child: LinearProgressIndicator()),

              if (isDataLoaded)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Plan: ${packageDetails!.name}', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                      const Divider(),

                      // --- Financial Details (Unchanged) ---
                      _buildProfileRow('Start Date', DateFormat.yMMMd().format(activeAssignment.purchaseDate), Icons.event, Colors.blueGrey),
                      _buildProfileRow('Expiry Date', DateFormat.yMMMd().format(activeAssignment.expiryDate), Icons.access_time, Colors.red),
                      _buildProfileRow('Net Booked Amount', currencyFormatter.format(netBooked), Icons.price_change, Colors.black87),
                      _buildProfileRow('Total Collected', currencyFormatter.format(mockCollected), Icons.receipt_long, Colors.green.shade700),
                      _buildProfileRow('Due Balance', currencyFormatter.format(pending > 0 ? pending : 0.0), Icons.money_off, pending > 0 ? Colors.red.shade700 : Colors.green.shade700),

                      const SizedBox(height: 15),

                      // 🎯 STEP B: Nested FutureBuilder to fetch Program Feature Names
                      Text('Included Features:', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      FutureBuilder<List<ProgramFeatureModel>>(
                        future: PackageService().getFeaturesByIds(featureIds),
                        builder: (context, featureSnapshot) {
                          if (featureSnapshot.connectionState == ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          if (featureSnapshot.hasError) {
                            return const Text('Failed to load features.', style: TextStyle(color: Colors.red));
                          }

                          final features = featureSnapshot.data ?? [];

                          return Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: features.map((feature) => Chip(
                              label: Text(feature.name, style: const TextStyle(fontSize: 12)),
                              backgroundColor: colorScheme.secondary.withOpacity(0.1),
                              labelStyle: TextStyle(color: colorScheme.secondary),
                            )).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 10),
                      ListTile(
                        title: const Text('View Payment Ledger & Features'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigating to Payment Ledger...')));
                        },
                      ),
                    ],
                  ),
                ),
              // Fallback for general error state
              if (snapshot.hasError && !isDataLoaded)
                const Padding(padding: EdgeInsets.all(16.0), child: Text('Failed to load package details.', style: TextStyle(color: Colors.red))),

            ],
          ),
        );
      },
    );
  }
  // --- 4. ADD-ON HEALTH FEATURES (Reused from previous step) ---
  Widget _buildAddOnFeatures(BuildContext context) {
    return Column(
      children: [
        _buildHealthFeatureTile(
          context,
          'Breathing Exercises',
          Icons.self_improvement,
          Colors.purple,
        ),
        _buildHealthFeatureTile(
          context,
          'Medication Reminders',
          Icons.medication,
          Colors.red,
        ),
        _buildHealthFeatureTile(
          context,
          'Scan & Find Age',
          Icons.camera_alt,
          Colors.pink,
        ),
      ],
    );
  }

  Widget _buildHealthFeatureTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title feature coming soon!'))),
      ),
    );
  }
}




class _DailyLogDetailContent extends StatelessWidget {
  final ScrollController controller;
  final DateTime date;
  final List<ClientLogModel> mealLogs;
  final ClientLogModel? wellnessLog;

  const _DailyLogDetailContent({
    required this.controller,
    required this.date,
    required this.mealLogs,
    this.wellnessLog,
  });

  Widget _buildWellnessMetric(String label, String value, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${DateFormat('EEEE').format(date)} Log Detail'),
        backgroundColor: colorScheme.secondary,
      ),
      body: SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- A. WELLNESS METRICS (The single daily entry) ---
            Text('Daily Wellness Check', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.primary)),
            const Divider(),

            if (wellnessLog != null)
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _buildWellnessMetric('Sleep Quality', (wellnessLog!.sleepQualityRating ?? 'N/A').toString(), Icons.nights_stay, Colors.deepPurple),
                      _buildWellnessMetric('Hydration', '${wellnessLog!.hydrationLiters ?? 'N/A'} L', Icons.opacity, Colors.blue),
                      _buildWellnessMetric('Energy Level', (wellnessLog!.energyLevelRating ?? 'N/A').toString(), Icons.bolt, Colors.orange),
                      _buildWellnessMetric('Mood', (wellnessLog!.moodLevelRating ?? 'N/A').toString(), Icons.sentiment_satisfied_alt, Colors.green),
                      if (wellnessLog!.notesAndFeelings?.isNotEmpty == true)
                        ListTile(
                          title: const Text('Notes'),
                          subtitle: Text(wellnessLog!.notesAndFeelings!),
                          leading: const Icon(Icons.edit_note),
                        ),
                    ],
                  ),
                ),
              )
            else
              const Center(child: Text('Wellness check was not completed on this day.')),

            const SizedBox(height: 30),

            // --- B. MEAL LOGS (The multiple meal entries) ---
            Text('Meal Logs', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.primary)),
            const Divider(),

            if (mealLogs.isEmpty)
              const Center(child: Text('No meals were logged on this day.'))
            else
              ...mealLogs.map((log) {
                final isDeviation = log.logStatus == LogStatus.deviated;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Icon(isDeviation ? Icons.warning : Icons.restaurant, color: isDeviation ? Colors.red : Colors.green),
                    title: Text(log.mealName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(log.logStatus.name.toUpperCase()),
                    children: [
                      _buildMealLogDetailRow('Food Eaten', log.actualFoodEaten.join(', ')),
                      _buildMealLogDetailRow('Status', log.logStatus.name),
                      if (isDeviation)
                        _buildMealLogDetailRow('Deviation Time', DateFormat.jm().format(log.deviationTime!)),
                      if (log.clientQuery?.isNotEmpty == true)
                        _buildMealLogDetailRow('Client Query', log.clientQuery!),
                      if (log.adminReplied)
                        _buildMealLogDetailRow('Dietitian Reply', log.adminComment!, color: Colors.green),

                      // Photo Preview (Need to implement image loading from URL)
                      if (log.mealPhotoUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Photos Attached: ${log.mealPhotoUrls.length} (Tap to view)'),
                        ),

                      // Button to launch Edit Dialog (Optional)
                      TextButton(onPressed: () {
                        // You can launch the edit dialog here using the log model
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tapped to edit log: ${log.mealName}')));
                      }, child: const Text('Edit Log')),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealLogDetailRow(String label, String value, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}