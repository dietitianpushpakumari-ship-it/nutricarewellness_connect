import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // 🎯 Ensure this is in pubspec
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/active_package_card.dart';
import 'package:nutricare_connect/core/utils/package_browser_screen.dart';
import 'package:nutricare_connect/features/chat/presentation/client_chat_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_reminder_setting_screen.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/schedule_meeting_utils.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CoachTab extends ConsumerWidget {
  final ClientModel client;
  const CoachTab({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dietitianAsync = ref.watch(dietitianProfileProvider);
    final meetingsAsync = ref.watch(upcomingMeetingsProvider(client.id));
    final bool isSensorEnabled = ref.watch(stepSensorEnabledProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          // 1. Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: const Text(
                "My Care Team",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
            ),
          ),

          // 🎯 2. Active Membership Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  ActivePackageCard(clientId: client.id),
                  const SizedBox(height: 10),
                  // Link to Store
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackageBrowserScreen())),
                    icon: const Icon(Icons.storefront, size: 16),
                    label: const Text("Browse New Packages"),
                  ),
                ],
              ),
            ),
          ),

          // 2. Dietitian Profile Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: dietitianAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text("Error: $e"),
                data: (profile) => _buildDietitianCard(context, profile, client),
              ),
            ),
          ),

          // 3. Quick Actions
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  context, "Chat Now", "Ask a question", Icons.chat_bubble_outline, Colors.indigo,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen(clientName: client.name ?? 'Client'))),
                ),
                _buildActionCard(
                  context, "Schedule", "Book Session", Icons.calendar_today, Colors.orange,
                      () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking flow coming soon"))),
                ),
              ],
            ),
          ),

          // 🎯 4. NEW: REFERRAL & SOCIALS SECTION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Community & Support", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // A. Referral Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade600]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        const Icon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Invite a Friend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("Share the journey on WhatsApp.", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _shareAppOnWhatsApp(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text("Share"),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // B. Social Media Row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialBtn(FontAwesomeIcons.globe, "Website", Colors.blueGrey, "https://yourwebsite.com"),
                        _buildSocialBtn(FontAwesomeIcons.instagram, "Instagram", Colors.pink, "https://instagram.com/yourhandle"),
                        _buildSocialBtn(FontAwesomeIcons.facebook, "Facebook", Colors.blue, "https://facebook.com/yourpage"),
                        _buildSocialBtn(FontAwesomeIcons.youtube, "YouTube", Colors.red, "https://youtube.com/@yourchannel"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Upcoming Sessions Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: const Text("Upcoming Sessions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          SliverToBoxAdapter(
            child: meetingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
              data: (meetings) {
                if (meetings.isEmpty) return _buildEmptyState();
                return SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: meetings.length,
                    itemBuilder: (context, index) => _buildMeetingCard(context, meetings[index]),
                  ),
                );
              },
            ),
          ),

          // 6. Settings
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: const Text("Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSettingsTile(
                  context, "Notifications", Icons.notifications_outlined,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientReminderSettingsScreen(client: client))),
                ),
                _buildSwitchTile(
                  context, "Step Sensor", Icons.directions_walk, isSensorEnabled,
                      (val) => ref.read(stepSensorEnabledProvider.notifier).state = val,
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // --- NEW WIDGETS ---

  Widget _buildSocialBtn(IconData icon, String label, Color color, String url) {
    return GestureDetector(
      onTap: () => _launch(url),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  Future<void> _shareAppOnWhatsApp(BuildContext context) async {
    // 🎯 Customize your message here
    const String message = "Hey! I'm getting healthier with NutriCare. Check it out: https://nutricare.com/app";
    const String url = "https://wa.me/?text=$message"; // Universal link

    await _launch(url);
  }

  // --- EXISTING WIDGETS ---
  // (DietitianCard, ActionCard, MeetingCard, SettingsTile code remains same as previous step)
  // ... (Paste previous helper methods here) ...

  Widget _buildDietitianCard(BuildContext context, AdminProfileModel? profile, ClientModel client) {
    if (profile == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigo.shade800, Colors.indigo.shade600]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Text(profile.firstName[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${profile.firstName} ${profile.lastName}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), Text(profile.designation.isNotEmpty ? profile.designation : "Senior Dietitian", style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)))])),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildContactAction(Icons.call, "Call", () => _launch("tel:${profile.mobile}")),
              _buildContactAction(Icons.email, "Email", () => _launch("mailto:${profile.companyEmail}")),
              _buildContactAction(Icons.message, "WhatsApp", () => _launch("https://wa.me/${client.whatsappNumber ?? client.mobile}")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 20)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 28), const Spacer(), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))]),
      ),
    );
  }

  Widget _buildMeetingCard(BuildContext context, MeetingModel meeting) {
    return Container(
      width: 240, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(DateFormat("MMM d, h:mm a").format(meeting.startTime), style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12))), const Spacer(), Text(meeting.purpose, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text("Via ${meeting.meetingType}", style: const TextStyle(color: Colors.grey, fontSize: 12))]),
    );
  }

  Widget _buildEmptyState() {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), child: Center(child: Text("No upcoming sessions.", style: TextStyle(color: Colors.grey.shade500))));
  }

  Widget _buildSettingsTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]), child: ListTile(leading: Icon(icon, color: Colors.grey.shade700), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey), onTap: onTap));
  }

  Widget _buildSwitchTile(BuildContext context, String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]), child: SwitchListTile(secondary: Icon(icon, color: value ? Colors.green : Colors.grey), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), value: value, onChanged: onChanged, activeColor: Colors.green));
  }

  // 🎯 LAUNCH METHOD
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url: $e");
    }
  }
}