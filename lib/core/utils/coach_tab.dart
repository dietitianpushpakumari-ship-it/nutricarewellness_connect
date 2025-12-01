import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/booking_sheet.dart';
import 'package:nutricare_connect/core/utils/package_browser_screen.dart';
import 'package:nutricare_connect/core/utils/package_payment_status_card.dart';
import 'package:nutricare_connect/core/utils/dietitian_business_card.dart'; // 🎯 1. Import Digital Card
import 'package:nutricare_connect/features/chat/presentation/client_chat_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. COMPACT HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: const Text(
                  "My Care Team",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                ),
              ),
            ),

            // 🎯 2. DIGITAL BUSINESS CARD (Replaces old Hero Card)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: dietitianAsync.when(
                  loading: () => const Center(child: LinearProgressIndicator(minHeight: 2)),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();
                    return DietitianBusinessCard(
                      profile: profile,
                      onShare: () {
                        // 🎯 Mock Share Logic
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Sharing Profile Card via WhatsApp..."), backgroundColor: Colors.green)
                        );
                        // TODO: Add real share logic here later
                      },
                    );
                  },
                ),
              ),
            ),

            // 3. UPCOMING SESSION
            SliverToBoxAdapter(
              child: meetingsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (meetings) {
                  if (meetings.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildNextSessionBanner(context, meetings.first),
                  );
                },
              ),
            ),

            // 4. MEMBERSHIP SECTION
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: const Text("My Plan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PackagePaymentStatusCard(clientId: client.id),
              ),
            ),

            // 5. QUICK ACTIONS GRID
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
                children: [
                  _buildCompactActionCard(
                    context, "Chat Coach", Icons.chat_bubble_outline, Colors.indigo,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen(clientName: client.name ?? 'Client'))),
                  ),
                  _buildCompactActionCard(
                    context, "Explore Plans", Icons.storefront, Colors.orange,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackageBrowserScreen())),
                  ),
                  _buildCompactActionCard(
                    context, "Book Session", Icons.calendar_month, Colors.teal,
() => Navigator.push(context,MaterialPageRoute(builder: (_) => BookingSheet(clientId : client.id, clientName: client.name ?? 'Client', freeSessionsRemaining: client.freeSessionsRemaining!)                                                                                           )),
                  ),
                  _buildCompactActionCard(
                    context, "Payments", Icons.payment, Colors.green,
                        () => showModalBottomSheet(context: context, builder: (_) => const PaymentModesSheet()),
                  ),
                ],
              ),
            ),

            // 6. COMMUNITY
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text("Join the Tribe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 10),
                    _buildSocialsCard(context),
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

  // --- WIDGET BUILDERS ---

  // 🎯 Note: _buildDietitianHeroCard was removed as we now use DietitianBusinessCard

  Widget _buildNextSessionBanner(BuildContext context, MeetingModel meeting) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
      child: Row(
        children: [
          const Icon(Icons.video_call, color: Colors.deepOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Upcoming: ${meeting.purpose}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)), Text(DateFormat("MMM d, h:mm a").format(meeting.startTime), style: TextStyle(color: Colors.grey.shade700, fontSize: 12))])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildCompactActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))], border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSocialBtn(FontAwesomeIcons.globe, "Web", Colors.blueGrey, "https://yourwebsite.com"),
          _buildSocialBtn(FontAwesomeIcons.instagram, "Insta", Colors.pink, "https://instagram.com"),
          _buildSocialBtn(FontAwesomeIcons.facebook, "Facebook", Colors.blue, "https://www.facebook.com/NutricareWellness.rkl"),
          _buildSocialBtn(FontAwesomeIcons.youtube, "YouTube", Colors.red, "https://www.youtube.com/@NutricareWellness-t2s"),
        ],
      ),
    );
  }

  Widget _buildSocialBtn(IconData icon, String label, Color color, String url) {
    return GestureDetector(
      onTap: () => _launch(url),
      child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500))]),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Could not launch $url"); }
  }
}

class PaymentModesSheet extends StatelessWidget {
  const PaymentModesSheet({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 350,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text("Select Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _payTile(Icons.qr_code, "UPI / GPay / PhonePe", () {}),
          _payTile(Icons.credit_card, "Credit / Debit Card", () {}),
          _payTile(Icons.account_balance, "Net Banking", () {}),
          const Divider(),
          _payTile(Icons.support_agent, "Contact Support", () {}),
        ],
      ),
    );
  }
  Widget _payTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: Colors.indigo, size: 20), title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), trailing: const Icon(Icons.chevron_right, size: 18), onTap: onTap, dense: true);
  }
}