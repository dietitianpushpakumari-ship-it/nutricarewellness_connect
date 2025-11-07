import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_log_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/dATA/repositories/diet_repositories.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:url_launcher/url_launcher.dart';

// 🎯 ADJUST IMPORTS

// Import necessary core files
import '../../../../services/client_service.dart';
import '../../domain/entities/client_diet_plan_model.dart';
import '../../domain/entities/client_log_model.dart';
import '../providers/diet_plan_provider.dart';


// --- MOCK/CONCEPTUAL DATA STRUCTURES (Must be defined/imported elsewhere) ---


class DietitianInfo {
  final String name = "Dr. Pushpakumari";
  final String email = "dietitian.pushpakumari@gmail.com";
  final String phone = "+919090385921";
}
class MeetingModel { final DateTime startTime; final String purpose; MeetingModel({required this.startTime, this.purpose = 'Follow-up'}); }
class ActivityData {
  final double waterL; final int steps; final int calories;
  ActivityData({this.waterL = 1.5, this.steps = 4500, this.calories = 1200});
  ActivityData copyWith({double? waterL, int? steps, int? calories}) => ActivityData(waterL: waterL ?? this.waterL, steps: steps ?? this.steps, calories: calories ?? this.calories);
}

final dietitianInfoProvider = Provider((ref) => DietitianInfo());
final activityDataProvider = StateProvider((ref) => ActivityData());
final upcomingMeetingsProvider = Provider((ref) => [MeetingModel(startTime: DateTime.now().add(const Duration(days: 2)))]);
// --------------------------------------------------------------------------


class ClientDashboardScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const ClientDashboardScreen({super.key, required this.client});

  @override
  ConsumerState<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
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
      _PlanScreen(client: widget.client), // Index 1: Plan/Log
      _AddOnsScreen(client: widget.client), // Index 2: Add-ons
      _FeedScreen(), // Index 3: Content
      _CoachScreen(client: widget.client), // Index 4: Coach
    ];
    initialize();
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
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Log History',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientLogHistoryScreen()));
            },
          ),
        ],
      ),

      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),

      // --- BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Plan'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Tracker'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: 'Coach'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo.shade700,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed, // Use fixed for 5 items
        onTap: _onItemTapped,
      ),
    );
  }

  void initialize() async {
    activePlan =   await DietRepository().getActivePlan(widget.client.id);


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

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Snapshot Card
        _buildGreetingCard(context, client),
        const SizedBox(height: 20),

        // Progress Graph
        _buildProgressGraph(context),
        const SizedBox(height: 20),

        // Quick Stats/Trackers
        _buildQuickTracker(context, ref, activityData),
      ],
    );
  }

  Widget _buildGreetingCard(BuildContext context, ClientModel clientInfo) {
    return Card(
      color: Colors.indigo.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome Back!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.indigo.shade800)),
            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoBox(context, label: 'Age', value: '${clientInfo.age ?? 'N/A'} yrs', icon: Icons.cake),
                _buildInfoBox(context, label: 'Weight', value: '75.5 kg', icon: Icons.monitor_weight),
                _buildInfoBox(context, label: 'BMI', value: '25.3', icon: Icons.straighten),
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
        subtitle: const Text('Last Updated: 2 days ago'),
        children: [
          Container(
            height: 150,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const Text('Graph Placeholder: Weight Trend', style: TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTracker(BuildContext context, WidgetRef ref, ActivityData activityData) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.opacity, color: Colors.blue.shade600),
            title: const Text('Water Consumption'),
            subtitle: Text('${activityData.waterL.toStringAsFixed(1)} L / 3.0 L Goal'),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () {
                final newWater = (activityData.waterL + 0.5).clamp(0.0, 3.0).toDouble();
                ref.read(activityDataProvider.notifier).state = activityData.copyWith(waterL: newWater);
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

  Widget _buildInfoBox(BuildContext context, {required String label, required String value, required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.teal, size: 28),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
// --- TAB 1: PLAN SCREEN (Diet Plan & Logging) ---
// =================================================================

class _PlanScreen extends ConsumerWidget {
  final ClientModel client;
  const _PlanScreen({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch the active plan state (synchronous DietPlanState object)
    final state = ref.watch(activeDietPlanProvider);

    // 2. Access the Notifier for logging actions
    // Use the client ID for the provider family argument
    final notifier = ref.read(dietPlanNotifierProvider(client.id).notifier);

    // --- Manual State Handling ---
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text('Error loading plan: ${state.error}'));
    }

    final activePlan = state.activePlan;
    final dailyLogs = state.dailyLogs;

    if (activePlan == null) {
      return const Center(child: Text('No active diet plan assigned.'));
    }

    final dayPlan = activePlan.days.isNotEmpty ? activePlan.days.first : null;

    // Mock current date for display consistency
    final currentDate = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Header
        Text('Diet Plan: ${activePlan.name}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green.shade800)),
        Text('Date: ${DateFormat.yMMMd().format(currentDate)}'),
        const Divider(),

        // Daily Meal Tracker
        if (dayPlan != null)
          ...dayPlan.meals.map((meal) {
            final mealName = meal.mealName ?? 'Meal';
            final mealLogs = dailyLogs.where((log) => log.mealName == mealName).toList();
            final isLogged = mealLogs.isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              child: ExpansionTile(
                leading: Icon(isLogged ? Icons.check_circle : Icons.radio_button_unchecked, color: isLogged ? Colors.green : Colors.grey),
                title: Text(mealName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isLogged
                    ? 'Logged: ${mealLogs.first.actualFoodEaten}'
                    : 'Planned: ${meal.items.length} items'),
                children: [
                  // Admin Comment Section
                  if (isLogged && mealLogs.first.adminReplied)
                    ListTile(
                      leading: const Icon(Icons.comment, color: Colors.blue),
                      title: Text(mealLogs.first.adminComment ?? 'No comment.'),
                      subtitle: const Text('Dietitian Feedback'),
                    ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: ElevatedButton(
                      onPressed: () {
                        // Launch Log Modification Dialog
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logging dialog for $mealName...')));
                      },
                      child: Text(isLogged ? 'EDIT LOG' : 'RECORD LOG'),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

        const Divider(),

        // Historical Link
        ListTile(
          leading: const Icon(Icons.history, color: Colors.blueGrey),
          title: const Text('View Full Log History & Reviews'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ClientLogHistoryScreen()));
          },
        ),
      ],
    );
  }
}

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
        _buildFeatureCard(context,
            'Lab Reports & History',
            'View past vital records and lab reports.',
            Icons.document_scanner,
            Colors.red,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => //VitalsHistoryPage(clientId: client.id, clientName: client.name)
                  Text("data") ))
                 ),

        // Calorie Counter / Steps (Placeholder for external tracking)
        _buildFeatureCard(context,
            'Steps & Calorie Count',
            'Link your fitness tracker or log activities manually.',
            Icons.directions_run,
            Colors.orange,
                () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity tracking setup required.')))),

        // Medication / Reminders
        _buildFeatureCard(context,
            'Medication / Supplement Reminders',
            'Set alerts for your prescribed medication schedule.',
            Icons.alarm,
            Colors.teal,
                () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medication reminder feature coming soon.')))),

        // Breathing Exercises (Placeholder)
        _buildFeatureCard(context,
            'Breathing Exercises',
            'Quick 5-minute stress reduction sessions.',
            Icons.self_improvement,
            Colors.purple,
                () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Breathing exercise module coming soon.')))),

        // Scan & Find Age (Placeholder)
        _buildFeatureCard(context,
            'Scan & Find Age (Add-on)',
            'Use the camera to scan objects (e.g., food label or face).',
            Icons.camera_alt,
            Colors.pink,
                () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan feature integration required.')))),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
        Text('Daily Content & Exclusive Offers', style: Theme.of(context).textTheme.headlineSmall),
        const Divider(),

        _buildContentTile(context,'Video: Daily Yoga Routine', FontAwesomeIcons.youtube, Colors.red, url: 'https://youtube.com/yogavideo'),
        _buildContentTile(context,'Recipe: Low Carb Breakfast', Icons.local_dining, Colors.green, url: 'https://nutricare.com/recipe'),
        _buildContentTile(context,'Tip: Hydration Secrets', Icons.lightbulb, Colors.amber, url: 'https://nutricare.com/tip'),
        _buildContentTile(context,'Ad: New Coaching Offer', Icons.campaign, Colors.blue, url: 'https://nutricare.com/offer'),
        _buildContentTile(context,'Client Story: Success', Icons.star, Colors.purple, url: 'https://nutricare.com/story'),
      ],
    );
  }

  Widget _buildContentTile(BuildContext context,String title, IconData icon, Color color, {String? url}) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $url')));
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
    final dietitianInfo = ref.watch(dietitianInfoProvider);
    final List<MeetingModel> upcomingMeetings = ref.watch(upcomingMeetingsProvider);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Know Your Dietitian Section
        Card(
          elevation: 4,
          child: ListTile(
            leading: Icon(Icons.person_pin, color: Colors.indigo.shade700, size: 36),
            title: Text('Your Dietitian: ${dietitianInfo.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text('Email: ${dietitianInfo.email}'),
          ),
        ),
        const SizedBox(height: 20),

        // Direct Contact Actions
        _buildContactActions(context, client, dietitianInfo),
        const SizedBox(height: 20),

        // Upcoming Appointments
        _buildAppointmentsSection(context, upcomingMeetings),
      ],
    );
  }

  Widget _buildContactActions(BuildContext context, ClientModel clientInfo, DietitianInfo dietitianInfo) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Direct Contact', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildContactButton('Call', Icons.phone, Colors.blue, () => _launchUrl('tel:${dietitianInfo.phone}', context)),
                _buildContactButton('Email', Icons.email, Colors.red, () => _launchUrl('mailto:${dietitianInfo.email}', context)),
                _buildContactButton('WhatsApp', FontAwesomeIcons.whatsapp, Colors.green, () => _launchUrl('https://wa.me/${client.whatsappNumber ?? client.mobile}', context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsSection(BuildContext context, List<MeetingModel> meetings) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.event, color: Colors.red),
        title: Text('Upcoming Appointments (${meetings.length})'),
        children: [
          ...meetings.map((meeting) => ListTile(
            title: Text(meeting.purpose),
            subtitle: Text(DateFormat('EEE, MMM d, h:mm a').format(meeting.startTime)),
            trailing: TextButton(onPressed: () {}, child: const Text('Join/Edit')),
          )).toList(),

          ListTile(
            leading: const Icon(Icons.add_task),
            title: const Text('Request New Session'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Launching scheduling form...')));
            },
          )
        ],
      ),
    );
  }

  Widget _buildContactButton(String label, IconData icon, Color color, VoidCallback onTap) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}