import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/wave_clipper.dart';
import 'package:nutricare_connect/features/chat/presentation/client_chat_screen.dart';
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
                _buildSupportSection(context, client),
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

  // ... inside _CoachScreen class in client_dashboard_main_screen.dart

// REPLACE the _buildContactActions method call or the contact buttons with:

  Widget _buildSupportSection(BuildContext context, ClientModel client) {
    return Card(
      elevation: 4,
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Need Help or Have Questions?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble),
                label: const Text("Open Chat & Requests"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                onPressed: () {
                  // 🎯 Navigate to the new Chat Screen
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ClientChatScreen(clientName: client.name ?? 'Client')),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text("Upload reports, ask about meals, or book appointments directly.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

// Call this method inside your _CoachScreen build() method list.

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


// ... (inside client_dashboard_main_screen.dart)

// 🎯 REBUILT: Progress Report Card (with Vitals)
// 🎯 REBUILT: Progress Report Card (with Vitals)
class _ProgressReportCard extends ConsumerStatefulWidget {
  final String clientId;
  const _ProgressReportCard({required this.clientId});

  @override
  ConsumerState<_ProgressReportCard> createState() => _ProgressReportCardState();
}

class _ProgressReportCardState extends ConsumerState<_ProgressReportCard> {
  int _selectedDays = 7;
  final List<int> _dayOptions = [7, 15, 30, 90];

  @override
  Widget build(BuildContext context) {
    // 🎯 Watch BOTH providers
    final dailyLogHistoryAsync = ref.watch(historicalLogProvider((clientId: widget.clientId, days: _selectedDays)));
    final vitalsHistoryAsync = ref.watch(vitalsHistoryProvider(widget.clientId)); // 🎯 NEW

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      child: ExpansionTile(
        leading: Icon(Icons.show_chart, color: colorScheme.secondary),
        title: const Text('Your Progress Report', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Showing trends from the last $_selectedDays days.'),
        children: [
          // --- 1. Date Range Filter Buttons ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<int>(
              segments: _dayOptions.map((days) => ButtonSegment<int>(
                value: days,
                label: Text('$days D'),
              )).toList(),
              selected: {_selectedDays},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() { _selectedDays = newSelection.first; });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: colorScheme.primary.withOpacity(0.2),
                selectedForegroundColor: colorScheme.primary,
              ),
            ),
          ),

          // --- 2. Daily Logs Graph (Steps, Cals, etc.) ---
          dailyLogHistoryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading chart: $e', style: const TextStyle(color: Colors.red)),
            ),
            data: (groupedLogs) {
              // --- Data Processing ---
              final Map<String, double> stepData = {};
              final Map<String, double> calorieData = {};
              final Map<String, double> sleepData = {};
              final Map<String, double> hydrationData = {};

              final sortedDates = groupedLogs.keys.toList()..sort();

              for (var date in sortedDates) {
                final dayLabel = DateFormat('d/M').format(date);
                final log = groupedLogs[date]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

                stepData[dayLabel] = (log?.stepCount ?? 0).toDouble();
                calorieData[dayLabel] = (log?.caloriesBurned ?? 0).toDouble();
                sleepData[dayLabel] = (log?.totalSleepDurationHours ?? 0).toDouble();
                hydrationData[dayLabel] = (log?.hydrationLiters ?? 0).toDouble();
              }
              // --- End Data Processing ---

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildChartContainer(context, 'Steps & Calories Burned', _buildLineChart(context, stepData, calorieData)),
                    const SizedBox(height: 20),
                    _buildChartContainer(context, 'Sleep Duration & Hydration', _buildLineChart(context, sleepData, hydrationData, isSleep: true)),
                  ],
                ),
              );
            },
          ),

          // --- 🎯 3. NEW: Vitals Graph (Blood Sugar & Weight) ---
          vitalsHistoryAsync.when(
              loading: () => const SizedBox.shrink(), // Don't show a second loader
              error: (e, s) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading vitals chart: $e', style: const TextStyle(color: Colors.red)),
              ),
              data: (vitalsList) {
                // Process data for the charts
                final Map<String, double> fbsData = {};
                final Map<String, double> ppbsData = {};
                final Map<String, double> weightData = {};
                final Map<String, double> bpSystolicData = {};
                final Map<String, double> bpDiastolicData = {};

                // Filter vitals to the selected date range
                final startDate = DateTime.now().subtract(Duration(days: _selectedDays));

                // Sort by date ascending to plot correctly
                final filteredVitals = vitalsList
                    .where((v) => !v.date.isBefore(startDate))
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                for (final vitals in filteredVitals) {
                  final dayLabel = DateFormat('d/M').format(vitals.date);

                  // Lab Results
                  if (double.tryParse(vitals.labResults['fbs'] ?? '') != null) {
                    fbsData[dayLabel] = double.parse(vitals.labResults['fbs']!);
                  }
                  if (double.tryParse(vitals.labResults['ppbs'] ?? '') != null) {
                    ppbsData[dayLabel] = double.parse(vitals.labResults['ppbs']!);
                  }

                  // At-Home Vitals
                  if (vitals.weightKg > 0) {
                    weightData[dayLabel] = vitals.weightKg;
                  }
                  if (vitals.bloodPressureSystolic != null) {
                    bpSystolicData[dayLabel] = vitals.bloodPressureSystolic!.toDouble();
                  }
                  if (vitals.bloodPressureDiastolic != null) {
                    bpDiastolicData[dayLabel] = vitals.bloodPressureDiastolic!.toDouble();
                  }
                }

                if (weightData.isEmpty && bpSystolicData.isEmpty && fbsData.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No Vitals data (Weight, BP, Sugar) logged for this period.', style: TextStyle(fontStyle: FontStyle.italic)),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (weightData.isNotEmpty) ...[
                        _buildChartContainer(context, 'Weight Progress (kg)', _buildLineChart(context, weightData, {})),
                        const SizedBox(height: 20),
                      ],
                      if (bpSystolicData.isNotEmpty) ...[
                        _buildChartContainer(context, 'Blood Pressure (mmHg)', _buildLineChart(context, bpSystolicData, bpDiastolicData, isBloodPressure: true)),
                        const SizedBox(height: 20),
                      ],
                      if (fbsData.isNotEmpty || ppbsData.isNotEmpty) ...[
                        _buildChartContainer(context, 'Blood Sugar (mg/dL)', _buildLineChart(context, fbsData, ppbsData, isSugar: true)),
                      ],
                    ],
                  ),
                );
              }
          ),
        ],
      ),
    );
  }

  // --- Graph Builder Helpers ---

  Widget _buildChartContainer(BuildContext context, String title, Widget chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: chart),
      ],
    );
  }

  // 🎯 UPDATED: _buildLineChart

// ... inside _ProgressReportCardState class ...

  Widget _buildLineChart(BuildContext context, Map<String, double> data1, Map<String, double> data2, {bool isSleep = false, bool isSugar = false, bool isBloodPressure = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<FlSpot> spots1 = [];
    final List<FlSpot> spots2 = [];

    // Combine all keys and sort them to create a stable X-axis
    final allKeys = (data1.keys.toSet()..addAll(data2.keys)).toList();
    try {
      // Try to sort by date (d/M format)
      allKeys.sort((a, b) {
        final aDate = DateFormat('d/M').parse(a);
        final bDate = DateFormat('d/M').parse(b);
        return aDate.compareTo(bDate);
      });
    } catch (e) {
      // Fallback to simple string sort if parsing fails
      allKeys.sort();
    }

    // Create spots based on the sorted key index
    for (int i = 0; i < allKeys.length; i++) {
      final key = allKeys[i];
      if (data1.containsKey(key)) {
        spots1.add(FlSpot(i.toDouble(), data1[key]!));
      }
      if (data2.containsKey(key)) {
        spots2.add(FlSpot(i.toDouble(), data2[key]!));
      }
    }

    // ... (omitted color logic, it remains the same) ...
    Color color1 = colorScheme.primary; // Default: Steps
    Color color2 = Colors.red; // Default: Calories
    if (isSleep) color2 = colorScheme.secondary; // Hydration
    if (isSugar) {
      color1 = Colors.red.shade700; // FBS
      color2 = Colors.orange.shade700; // PPBS
    }
    if (isBloodPressure) {
      color1 = Colors.blue.shade700; // Systolic
      color2 = Colors.blue.shade300; // Diastolic
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                // Check bounds against the master key list
                if (index < 0 || index >= allKeys.length) return const SizedBox();

                // Logic to skip labels on dense charts
                if (_selectedDays > 10 && index % 3 != 0) return const SizedBox();

                // 🎯 CRITICAL FIX:
                // Removed 'axisSide: meta.axisSide'.
                // The 'meta' object is all that is required.
                return SideTitleWidget(
                  meta: meta, // ⬅️ THIS IS THE FIX
                  space: 8,
                  child: Text(allKeys[index], style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        lineBarsData: [
          // Line 1
          if(spots1.isNotEmpty)
            LineChartBarData(
              spots: spots1, isCurved: true, color: color1, barWidth: 4,
              isStrokeCapRound: true, dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color1.withOpacity(0.2)),
            ),
          // Line 2
          if(spots2.isNotEmpty)
            LineChartBarData(
              spots: spots2, isCurved: true, color: color2, barWidth: 4,
              isStrokeCapRound: true, dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color2.withOpacity(0.2)),
            ),
        ],
      ),
    );
  }

}

