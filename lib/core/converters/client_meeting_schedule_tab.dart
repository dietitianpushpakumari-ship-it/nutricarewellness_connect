import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/features/appointments/meeting_Service.dart';
import 'package:nutricare_connect/features/appointments/schedule_meeting_utils.dart';
import 'package:nutricare_connect/new/service/client_service.dart';

import 'package:url_launcher/url_launcher.dart';


// Make sure you have a way to get the Coach Profile.
// For now, I will assume we pass a mock or fetch it, OR we just disable the FAB if coach is unknown.
// Ideally, ClientModel should have a 'assignedCoachId'.

class ClientMeetingScheduleTab extends StatefulWidget {
  final ClientModel client;
  const ClientMeetingScheduleTab({super.key, required this.client});

  @override
  State<ClientMeetingScheduleTab> createState() => _ClientMeetingScheduleTabState();
}

class _ClientMeetingScheduleTabState extends State<ClientMeetingScheduleTab> {
  final MeetingService _meetingService = MeetingService();
  late Future<List<MeetingModel>> _meetingsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _meetingsFuture = _meetingService.getClientMeetings(widget.client.id);
    });
  }

  Future<void> _cancelRequest(MeetingModel meeting) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Request?"),
        content: const Text("Are you sure you want to cancel this booking request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Cancel"),
          )
        ],
      ),
    );

    if (confirm == true) {
      await _meetingService.cancelAppointment(meeting.id);
      _refresh();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Cancelled")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: FutureBuilder<List<MeetingModel>>(
        future: _meetingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final meetings = snapshot.data ?? [];

          // 🎯 FILTERING LOGIC
          final pending = meetings.where((m) =>
          m.status == MeetingStatus.pending ||
              m.status == MeetingStatus.payment_pending ||
              m.status == MeetingStatus.verification_pending
          ).toList();

          final upcoming = meetings.where((m) =>
          m.status == MeetingStatus.confirmed ||
              m.status == MeetingStatus.scheduled
          ).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Quick Connect
                _buildPremiumCard(
                    title: "Quick Connect",
                    icon: Icons.bolt,
                    color: Colors.orange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickBtn(Icons.phone, "Call", Colors.blue, () => launchUrl(Uri(scheme: 'tel', path: widget.client.mobile))),
                        _buildQuickBtn(FontAwesomeIcons.whatsapp, "WhatsApp", Colors.green, () => launchUrl(Uri.parse("https://wa.me/${widget.client.whatsappNumber ?? widget.client.mobile}"))),
                        _buildQuickBtn(FontAwesomeIcons.video, "Meet", Colors.red, () => launchUrl(Uri.parse("https://meet.google.com/new"))),
                      ],
                    )
                ),
                const SizedBox(height: 24),

                // 🎯 2. PENDING REQUESTS SECTION
                if (pending.isNotEmpty) ...[
                  const Text("Pending Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  ...pending.map((m) => _buildRequestCard(m)),
                  const SizedBox(height: 24),
                ],

                // 3. UPCOMING MEETINGS
                const Text("Upcoming Sessions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No upcoming sessions scheduled.", style: TextStyle(color: Colors.grey))))
                else
                  ...upcoming.map((m) => _buildMeetingCard(m)),

                // 4. History Button (Optional)
                const SizedBox(height: 20),
                Center(child: TextButton.icon(onPressed: (){}, icon: const Icon(Icons.history), label: const Text("View Past History"))),
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          );
        },
      ),
      // 🎯 FAB to Book New
      /*floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
           // NAVIGATE TO CLIENT BOOKING SHEET
           // Note: You need the Coach Profile here.
           // If 'widget.client' has a 'coachId', fetch it first.
        },
        label: const Text("Book New"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),*/
    );
  }

  // 🎯 NEW: Request Card with Cancel Button
  Widget _buildRequestCard(MeetingModel m) {
    bool isPaymentPending = m.status == MeetingStatus.payment_pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.hourglass_top, color: Colors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.purpose, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                        DateFormat('dd MMM @ h:mm a').format(m.startTime),
                        style: const TextStyle(fontSize: 13, color: Colors.black87)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPaymentPending ? "Waiting for Payment" : "Waiting for Confirmation",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _cancelRequest(m),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  ),
                  child: const Text("Cancel Request", style: TextStyle(fontSize: 12)),
                ),
              ),
              if (isPaymentPending) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to Payment Screen or Show QR
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment flow not linked yet.")));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    ),
                    child: const Text("Pay Now", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  // Standard Meeting Card
  Widget _buildMeetingCard(MeetingModel m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 3))]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(DateFormat('dd').format(m.startTime), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                Text(DateFormat('MMM').format(m.startTime), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.purpose, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("${DateFormat.jm().format(m.startTime)} • ${m.meetingType}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          if (m.meetLink != null)
            IconButton(
                icon: const Icon(Icons.video_call, color: Colors.green),
                onPressed: () => launchUrl(Uri.parse(m.meetLink!))
            )
        ],
      ),
    );
  }

  Widget _buildPremiumCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))]),
          const SizedBox(height: 16),
          child
        ],
      ),
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
      ],
    );
  }
}