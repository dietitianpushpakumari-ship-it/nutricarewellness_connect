import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/appointments/appointment_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';

import '../features/appointments/meeting_Service.dart';

class BookingSheet extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String coachId; // 🎯 NEW: Required to know WHO we are booking with
  final int freeSessionsRemaining;

  const BookingSheet({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.coachId, // 🎯 Add this
    required this.freeSessionsRemaining,
  });

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final MeetingService _service = MeetingService();
  final _topicCtrl = TextEditingController();

  int _duration = 30;
  DateTime? _selectedTime;
  List<AppointmentSlot> _availableSlotsForSelectedTime = [];

  bool _isBooking = false;
  bool _useFree = false;
  Map<String, int> _prices = {};
  bool _loadingPrices = true;

  final String _adminUpiId = "nutricare@upi";
  final String _adminName = "NutriCare Wellness";

  @override
  void initState() {
    super.initState();
    if (widget.freeSessionsRemaining > 0) _useFree = true;
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final p = await _service.getSessionPricing();
    if (mounted) setState(() { _prices = p; _loadingPrices = false; });
  }

  Future<void> _launchUPI(String apptId, double amount) async {
    final String uriString = "upi://pay?pa=$_adminUpiId&pn=$_adminName&am=$amount&tr=$apptId&tn=Consultation&cu=INR";
    final Uri uri = Uri.parse(uriString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch UPI apps.";
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No UPI App found. Please pay manually.")));
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedTime == null || _availableSlotsForSelectedTime.isEmpty || _topicCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a time and enter a topic.")));
      return;
    }

    if (_useFree && _duration > 30) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Free sessions max 30 mins."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isBooking = true);
    try {
      final slotToBook = _availableSlotsForSelectedTime.first;

      // 🎯 UPDATED CALL with all required parameters
      final apptId = await _service.bookSession(
        clientId: widget.clientId,
        clientName: widget.clientName,
        coachId: widget.coachId, // 🎯 Passed from widget
        startTime: slotToBook.startTime,
        durationMinutes: _duration,
        topic: _topicCtrl.text.trim(),
        useFreeSession: _useFree,
        // 🎯 NEW: Audit Fields (Client is performing the action)
        performedByUid: widget.clientId,
        performedByName: widget.clientName,
        // 🎯 NEW: Payment Ref (Null if free, else placeholder until paid)
        paymentRef: _useFree ? null : "PENDING_UPI",
      );

      if (mounted) {
        Navigator.pop(context);

        if (_useFree) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session Confirmed!"), backgroundColor: Colors.green));
        } else {
          final double price = (_prices[_duration.toString()] ?? 500).toDouble();
          _launchUPI(apptId, price);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Initiated. Slot Reserved."), duration: Duration(seconds: 4)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPrice = _prices[_duration.toString()] ?? 0;
    final primaryColor = Theme.of(context).primaryColor;

    return Material(
        color: Colors.transparent,
        child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Book Session", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Duration & Price Cards
                  SizedBox(
                    height: 80,
                    child: Row(
                      children: [15, 30, 60].map((min) => Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _duration = min; if (min > 30) _useFree = false; _selectedTime = null; }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: _duration == min ? primaryColor : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _duration == min ? primaryColor : Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("$min Mins", style: TextStyle(color: _duration == min ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                                Text("₹${_prices[min.toString()] ?? '-'}", style: TextStyle(fontSize: 12, color: _duration == min ? Colors.white70 : Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextField(
                      controller: _topicCtrl,
                      decoration: InputDecoration(labelText: "Topic / Reason", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)
                  ),

                  const SizedBox(height: 20),
                  // Free Toggle
                  if (widget.freeSessionsRemaining > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                      child: Row(
                        children: [
                          const Icon(Icons.card_giftcard, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(child: Text("Use Free Session (${widget.freeSessionsRemaining} left)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                          Switch(value: _useFree, onChanged: _duration > 30 ? null : (v) => setState(() => _useFree = v), activeColor: Colors.green)
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  const Text("Select Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),

                  // 🎯 SLOT GRID (Stream using coachId)
                  Expanded(
                      child: StreamBuilder<List<AppointmentSlot>>(
                        // 🎯 FIXED: Pass coachId and a valid date (or iterate dates)
                        // Ideally, this sheet should have a DatePicker or default to Today/Tomorrow.
                        // For now, let's assume we check Today or the selected time context if passed.
                        // To keep it simple for this snippet, we default to DateTime.now()
                          stream: _service.streamCoachSlots(widget.coachId, _selectedTime ?? DateTime.now()),
                          builder: (ctx, snap) {
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                            final allSlots = snap.data!;
                            if (allSlots.isEmpty) return const Center(child: Text("No slots available today."));

                            final groupedByTime = groupBy(allSlots, (AppointmentSlot s) => s.startTime);
                            final sortedTimes = groupedByTime.keys.toList()..sort();

                            return GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10
                              ),
                              itemCount: sortedTimes.length,
                              itemBuilder: (ctx, i) {
                                final time = sortedTimes[i];
                                final slotsAtThisTime = groupedByTime[time]!;
                                final count = slotsAtThisTime.length;
                                final isSelected = _selectedTime == time;

                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedTime = time;
                                    _availableSlotsForSelectedTime = slotsAtThisTime;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected ? primaryColor : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
                                      boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8)] : [],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                            DateFormat('h:mm a').format(time), // 🎯 Simplified format
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                      )
                  ),

                  const Divider(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isBooking ? null : _confirmBooking,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      child: _isBooking
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_useFree ? "BOOK FREE SESSION" : "PAY ₹$currentPrice & BOOK", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ]
            )
        )
    );
  }
}