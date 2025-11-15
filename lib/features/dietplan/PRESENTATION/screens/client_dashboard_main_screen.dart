import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/wave_clipper.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/activity_tracker_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/breathing_excercise_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_log_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_reminder_setting_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/daily_wellness_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/diet_plan_dashboard_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/home_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/lab_report_list_Screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/plan_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/tracker_screen.dart';
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
import 'package:nutricare_connect/main.dart';

// --- MOCK/CONCEPTUAL DATA STRUCTURES (Must be defined/imported elsewhere) ---

class ActivityData {
  final double waterL;
  final int steps;
  final int calories;

  // 🎯 NEW FIELDS: Daily Goals (Assumed to be set by Admin)
  final double goalWaterLiters;
  final int goalSteps;

  ActivityData({
    this.waterL = 1.5,
    this.steps = 4500,
    this.calories = 1200,
    this.goalWaterLiters = 3.0,
    this.goalSteps = 8000,
  });

  ActivityData copyWith({double? waterL, int? steps, int? calories}) =>
      ActivityData(
        waterL: waterL ?? this.waterL,
        steps: steps ?? this.steps,
        calories: calories ?? this.calories,
        goalWaterLiters: goalWaterLiters,
        // Preserve goals
        goalSteps: goalSteps,
      );
}

class WaterSize {
  final String label;
  final double volumeL;
  final IconData icon;

  const WaterSize({
    required this.label,
    required this.volumeL,
    required this.icon,
  });
}

// 🎯 FIX: Define the required list of standard sizes
const List<WaterSize> standardSizes = [
  WaterSize(label: 'Small Glass', volumeL: 0.25, icon: Icons.local_drink),
  WaterSize(
    label: 'Large Glass',
    volumeL: 0.40,
    icon: Icons.local_drink_outlined,
  ),
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
      ClientDashboardScreenState();
}

class ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  int _selectedIndex = 0;

  //late final List<Widget> _widgetOptions;
  ClientDietPlanModel? activePlan;

  @override
  void initState() {
    super.initState();
    // Initialize content pages based on client data
    /* _widgetOptions = <Widget>[
      HomeScreen(client: widget.client), // Index 0: Home
      PlanScreen(client: widget.client),
      ActivityTrackerScreen(client: widget.client),
      TrackerScreen(client: widget.client),
      _WellnessHubScreen(client: widget.client),

      //_AddOnsScreen(client: widget.client), // Index 2: Add-ons

      _FeedScreen(), // Index 3: Content
      _CoachScreen(client: widget.client), // Index 4: Coach
    ];*/
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProfileFutureProvider);

    return clientAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error loading client profile: $err')),
      ),
      data: (client) {
        if (client == null) {
          // This should not happen if the user is authenticated, but good to check
          return const Scaffold(body: Center(child: Text('Client not found.')));
        }

        // 🎯 The widget list is now built here, with the FRESH client data
        final List<Widget> widgetOptions = <Widget>[
          HomeScreen(client: client), // Index 0: Home
          PlanScreen(client: client), // Index 1: Plan/Log
          ActivityTrackerScreen(client: client), // Index 2: Activity Hub
          TrackerScreen(client: widget.client),
          _WellnessHubScreen(client: widget.client),

          //_AddOnsScreen(client: widget.client), // Index 2: Add-ons
          _FeedScreen(), // Index 3: Content
          _CoachScreen(client: widget.client), // Index 4: Coach
        ];

        // -----------------------------------------------------------------
        // 🎯 Reminder Logic Trigger (This remains the same)
        // -----------------------------------------------------------------
        ref.listen<DietPlanState>(activeDietPlanProvider, (
          previousState,
          newState,
        ) {
          if (!newState.isLoading && newState.activePlan != null) {
            localReminderService.reScheduleAllReminders(
              client: client, // Pass the fresh client model
              activePlan: newState.activePlan,
              dailyLogs: newState.dailyLogs,
            );
          }
        });
        // -----------------------------------------------------------------

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

          body: IndexedStack(index: _selectedIndex, children: widgetOptions),

          // --- BOTTOM NAVIGATION BAR ---
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant),
                label: 'Plan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center),
                label: 'Tracker',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center),
                label: 'Tracker2',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center),
                label: 'Tracker2',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center),
                label: 'Addon',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.lightbulb),
                label: 'Feed',
              ),
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
      },
    );
  }

  void initialize() async {
    activePlan = await DietRepository().getActivePlan(widget.client.id);
  }

  void onItemTapped(int i) {
    _onItemTapped(2);
  }
}

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

class _WellnessHubScreen extends ConsumerWidget {
  final ClientModel client;

  const _WellnessHubScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Wellness Center',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          'Guided exercises to help refuel your body and mind.',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const Divider(height: 30),

        // --- 1. Breathing Exercise (Existing) ---
        _buildModuleCard(
          context: context,
          title: 'Mindful Breathing',
          subtitle: 'Start a guided "Sun Glow" session to calm your mind.',
          icon: Icons.brightness_high_rounded,
          color: Theme.of(context).colorScheme.secondary,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BreathingExerciseScreen(client: client),
              ),
            );
          },
        ),

        // --- 2. Activity / Step Input (Existing) ---
        // --- 2. Posture Tracker (New - Placeholder) ---
        _buildModuleCard(
          context: context,
          title: 'Posture & Form Tracker',
          subtitle: 'COMING SOON: Get real-time feedback on your exercises.',
          icon: Icons.camera_alt,
          color: Colors.orange.shade700,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This feature is coming soon!')),
            );
          },
        ),

        // --- 3. Voice Journal (New - Placeholder) ---
        _buildModuleCard(
          context: context,
          title: 'Voice & Mood Journal',
          subtitle: 'COMING SOON: Log your mood and stress just by talking.',
          icon: Icons.mic,
          color: Colors.purple.shade400,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This feature is coming soon!')),
            );
          },
        ),

        // --- 4. Food Scanner (New - Placeholder) ---
        _buildModuleCard(
          context: context,
          title: 'AI Food Scanner',
          subtitle: 'COMING SOON: Log your deviated meals with your camera.',
          icon: Icons.document_scanner,
          // or Icons.camera
          color: Colors.green.shade600,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This feature is coming soon!')),
            );
          },
        ),

        // --- 5. Advanced Sleep (New - Placeholder) ---
        _buildModuleCard(
          context: context,
          title: 'Auto Sleep Analysis',
          subtitle:
              'COMING SOON: Track sleep quality with your phone\'s sensors.',
          icon: Icons.bedtime,
          color: Colors.grey,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This feature is coming soon!')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 44, color: color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
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
    final bool isSensorEnabled = ref.watch(stepSensorEnabledProvider);
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
        // --- 🎯 NEW: Settings Section ---
        const SizedBox(height: 20),
        Text('App Settings', style: Theme.of(context).textTheme.titleLarge),
        const Divider(),

        // 1. Notification Settings
        Card(
          elevation: 2,
          child: ListTile(
            leading: Icon(
              Icons.notifications_active,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: const Text('Notification Settings'),
            subtitle: const Text(
              'Manage your daily reminders and voice alerts.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  // 🎯 Navigate to the new client-side screen
                  builder: (_) => ClientReminderSettingsScreen(client: client),
                ),
              );
            },
          ),
        ),

        // 2. Sensor Settings
        Card(
          elevation: 2,
          child: SwitchListTile(
            title: const Text('Enable Phone Step Sensor'),
            subtitle: const Text(
              'Use this phone\'s sensor for live step tracking.',
            ),
            value: isSensorEnabled,
            onChanged: (bool newValue) {
              ref.read(stepSensorEnabledProvider.notifier).state = newValue;
            },
            secondary: Icon(
              isSensorEnabled ? Icons.sensors : Icons.sensors_off,
              color: isSensorEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
          ),
        ),
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
