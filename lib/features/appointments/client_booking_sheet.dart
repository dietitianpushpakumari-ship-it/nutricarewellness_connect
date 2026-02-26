import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/features/appointments/appointment_model.dart';
import 'package:nutricare_connect/features/appointments/meeting_Service.dart';
import 'package:nutricare_connect/core/package_payment_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/new/service/client_service.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

import 'package:url_launcher/url_launcher.dart';

class ClientBookingSheet extends ConsumerStatefulWidget {
  final ClientModel client;
  final AdminProfileModel coach;

  const ClientBookingSheet({
    super.key,
    required this.client,
    required this.coach
  });

  @override
  ConsumerState<ClientBookingSheet> createState() => _ClientBookingSheetState();
}

class _ClientBookingSheetState extends ConsumerState<ClientBookingSheet> {
  final MeetingService _meetingService = MeetingService();

  DateTime _selectedDate = DateTime.now();
  AppointmentSlot? _selectedSlot;
  int _durationMinutes = 30;
  bool _useFreeCredit = false;
  bool _isBooking = false;

  // Wallet State
  int _freeCredits = 0;
  double _outstandingBalance = 0.0;
  bool _isLoadingBalance = true;

  // Booking State
  final TextEditingController _guestNameCtrl = TextEditingController();
  final TextEditingController _guestPhoneCtrl = TextEditingController();
  String _selectedTopic = "Diet Review";
  bool _bookForSelf = true;

  final List<int> _durations = [15, 30, 45, 60];

  final List<String> _topicOptions = [
    "Diet Review", "New Plan Request", "Health Concern",
    "Lab Report Analysis", "General Query", "Follow-up"
  ];

  final String _adminUpiId = "nutricare@upi";
  final String _adminName = "NutriCare Wellness";
  Map<String, int> _prices = {};

  @override
  void initState() {
    super.initState();
    _freeCredits = widget.client.freeSessionsRemaining ?? 0;
    if (_freeCredits > 0) _useFreeCredit = true;
    _fetchFinancialStatus();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final p = await _meetingService.getSessionPricing();
    if (mounted) setState(() => _prices = p);
  }

  Future<void> _fetchFinancialStatus() async {
    try {
      // 🎯 FIX: Use the provider-scoped service for auto-tenantId fetching
      final paymentService = ref.read(packagePaymentServiceProvider);
      final assignments = await paymentService.getAllAssignmentsWithCollectedAmounts();

      // Filter for this specific client
      final clientData = assignments.where((a) => a.assignment.clientId == widget.client.id).toList();

      double totalDue = 0.0;
      for (var data in clientData) {
        // 🎯 FIX: Calculate pending amount from available fields
        final booked = data.assignment.bookedAmount ?? 0.0;
        final collected = data.collectedAmount;
        totalDue += (booked - collected).clamp(0.0, double.infinity);
      }

      if (mounted) {
        setState(() {
          _outstandingBalance = totalDue;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  Future<void> _launchUPI(String apptId, double amount) async {
    final String uriString = "upi://pay?pa=$_adminUpiId&pn=$_adminName&am=$amount&tr=$apptId&tn=$_selectedTopic&cu=INR";
    final Uri uri = Uri.parse(uriString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No UPI App found. Booking saved as Pending Payment.")));
      }
    } catch (e) {
      // Fallback
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a time slot.")));
      return;
    }
    if (!_bookForSelf && (_guestNameCtrl.text.isEmpty || _guestPhoneCtrl.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guest details required.")));
      return;
    }

    setState(() => _isBooking = true);

    try {
      final String finalClientName = _bookForSelf ? widget.client.name! : "${_guestNameCtrl.text.trim()} (via ${widget.client.name})";
      final String finalPhone = _bookForSelf ? widget.client.mobile : _guestPhoneCtrl.text.trim();

      final apptId = await _meetingService.bookSession(
        clientId: widget.client.id,
        clientName: finalClientName,
        guestPhone: finalPhone,
        coachId: widget.coach.id,
        startTime: _selectedSlot!.startTime,
        durationMinutes: _durationMinutes,
        topic: _selectedTopic,
        useFreeSession: _useFreeCredit,
        performedByUid: widget.client.id,
        performedByName: widget.client.name!,
        paymentRef: _useFreeCredit ? null : "PAY_PENDING",
      );

      if (mounted) {
        Navigator.pop(context);

        if (_useFreeCredit) {
          // 🎯 UPDATED MESSAGE
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Request Sent! Waiting for Coach Approval."),
              backgroundColor: Colors.orange
          ));
        } else {
          final double price = (_prices[_durationMinutes.toString()] ?? 500).toDouble();
          _launchUPI(apptId, price);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slot Reserved. Proceed to Payment."), duration: Duration(seconds: 4)));
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().replaceAll("Exception:", "")}")));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _buildGlassHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wallet
                      _buildPremiumWalletCard(),
                      const SizedBox(height: 24),

                      // Coach
                      _buildCoachCard(),
                      const SizedBox(height: 30),

                      // Toggle (Self / Guest)
                      _buildSegmentedToggle(),
                      if (!_bookForSelf) _buildGuestForm(),
                      const SizedBox(height: 30),

                      // Date
                      Text("Select Date", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 12),
                      _buildPremiumDateStrip(),
                      const SizedBox(height: 30),

                      // Slots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Available Time", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          if (_selectedSlot != null)
                            Text(DateFormat('h:mm a').format(_selectedSlot!.startTime), style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSlotsGrid(),

                      if (_selectedSlot != null) ...[
                        const SizedBox(height: 30),
                        Text("Consultation Topic", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        // 🎯 TOPIC CHIPS
                        Wrap(
                          spacing: 10, runSpacing: 10,
                          children: _topicOptions.map((t) => _buildTopicChip(t)).toList(),
                        ),

                        const SizedBox(height: 30),
                        Text("Duration", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        _buildDurationSelector(),

                        if (_freeCredits > 0) ...[
                          const SizedBox(height: 20),
                          _buildFreeCreditSwitch(theme),
                        ]
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar())
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildGlassHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1)))),
      child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: const Icon(Icons.close, size: 20))),
        const SizedBox(width: 16),
        const Text("Book Appointment", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
      ]),
    );
  }

  Widget _buildPremiumWalletCard() {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2C3E50)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.wallet, color: Colors.white54, size: 24), Text("MY WALLET", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5))]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Free Credits", style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text("$_freeCredits Sessions", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
          Container(width: 1, height: 30, color: Colors.white24),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text("Outstanding", style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text(_isLoadingBalance ? "..." : currency.format(_outstandingBalance), style: TextStyle(color: _outstandingBalance > 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold))]),
        ])
      ]),
    );
  }

  Widget _buildCoachCard() {
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))), child: CircleAvatar(radius: 26, backgroundImage: widget.coach.photoUrl.isNotEmpty ? NetworkImage(widget.coach.photoUrl) : null, child: widget.coach.photoUrl.isEmpty ? Text(widget.coach.firstName[0]) : null)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Dr. ${widget.coach.firstName} ${widget.coach.lastName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(widget.coach.designation, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600))]),
        const Spacer(), const Icon(Icons.verified, color: Colors.blue, size: 20)
      ]),
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [_buildSegment("Myself", _bookForSelf, () => setState(() => _bookForSelf = true)), _buildSegment("For Others", !_bookForSelf, () => setState(() => _bookForSelf = false))]),
    );
  }

  Widget _buildSegment(String label, bool isActive, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : []), child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isActive ? Colors.black87 : Colors.grey)))));
  }

  Widget _buildGuestForm() {
    return Padding(padding: const EdgeInsets.only(top: 20), child: Column(children: [_buildPremiumField(_guestNameCtrl, "Guest Name", Icons.person), const SizedBox(height: 16), _buildPremiumField(_guestPhoneCtrl, "Guest Mobile", Icons.phone, isNum: true)]));
  }

  Widget _buildPremiumField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: TextField(controller: ctrl, keyboardType: isNum ? TextInputType.phone : TextInputType.text, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: Colors.grey), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16))));
  }

  Widget _buildPremiumDateStrip() {
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final primaryColor = Theme.of(context).colorScheme.primary;
          return GestureDetector(onTap: () => setState(() { _selectedDate = date; _selectedSlot = null; }), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 60, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: isSelected ? primaryColor : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200), boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white70 : Colors.grey)), Text(date.day.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)), Text(DateFormat('E').format(date), style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey))])));
        },
      ),
    );
  }

  Widget _buildSlotsGrid() {
    return StreamBuilder<List<AppointmentSlot>>(
      stream: _meetingService.streamCoachSlots(widget.coach.id, _selectedDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final slots = snapshot.data ?? [];
        if (slots.isEmpty) return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text("No available slots for this date.", style: TextStyle(color: Colors.grey))));
        return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: slots.length, itemBuilder: (context, index) {
          final slot = slots[index];
          final isSelected = _selectedSlot?.startTime == slot.startTime;
          final primaryColor = Theme.of(context).colorScheme.primary;
          return GestureDetector(onTap: () => setState(() => _selectedSlot = slot), child: AnimatedContainer(duration: const Duration(milliseconds: 200), decoration: BoxDecoration(color: isSelected ? primaryColor : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200), boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 5)] : []), alignment: Alignment.center, child: Text(DateFormat('h:mm a').format(slot.startTime), style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87, fontSize: 12))));
        });
      },
    );
  }

  Widget _buildTopicChip(String topic) {
    final isSelected = _selectedTopic == topic;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(onTap: () => setState(() => _selectedTopic = topic), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300)), child: Text(topic, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? primaryColor : Colors.grey.shade700))));
  }

  Widget _buildDurationSelector() {
    return Row(children: _durations.map((min) {
      final isSelected = _durationMinutes == min;
      return Expanded(child: GestureDetector(onTap: () => setState(() => _durationMinutes = min), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: isSelected ? Colors.black87 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.black87 : Colors.grey.shade300)), child: Text("$min m", style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)))));
    }).toList());
  }

  Widget _buildFreeCreditSwitch(ThemeData theme) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _useFreeCredit ? Colors.green.shade50 : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _useFreeCredit ? Colors.green.shade200 : Colors.grey.shade200)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _useFreeCredit ? Colors.green : Colors.grey.shade200, shape: BoxShape.circle), child: Icon(Icons.card_giftcard, color: _useFreeCredit ? Colors.white : Colors.grey, size: 18)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Use Free Session", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text("Balance: ${_freeCredits} remaining", style: TextStyle(color: Colors.grey.shade600, fontSize: 11))])), Switch(value: _useFreeCredit, onChanged: (v) => setState(() => _useFreeCredit = v), activeColor: Colors.green)]));
  }

  Widget _buildBottomBar() {
    final price = MeetingService.sessionPrices[_durationMinutes] ?? 0;
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))], borderRadius: const BorderRadius.vertical(top: Radius.circular(32))), child: SafeArea(child: Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const Text("Total Cost", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)), Text(_useFreeCredit ? "FREE" : "₹${price.toStringAsFixed(0)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _useFreeCredit ? Colors.green : Colors.black87))]), const SizedBox(width: 24), Expanded(child: SizedBox(height: 56, child: ElevatedButton(onPressed: _isBooking ? null : _confirmBooking, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4)), child: _isBooking ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text("BOOK NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)))))])));
  }
}