import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/appointment_model.dart';
import 'package:nutricare_connect/core/meeting_Service.dart';

class BookingSheet extends StatefulWidget {
  final String clientId;
  final String clientName;
  final int freeSessionsRemaining;

  const BookingSheet({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.freeSessionsRemaining,
  });

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final MeetingService _service = MeetingService();
  final _topicCtrl = TextEditingController();

  int _duration = 30;
  AppointmentSlot? _selectedSlot;
  bool _isBooking = false;
  bool _useFree = false;

  // Dynamic Prices & Descriptions
  Map<String, int> _prices = {};
  bool _loadingPrices = true;

  final Map<int, String> _descriptions = {
    15: "Quick Query & Check-in",
    30: "Weekly Progress Review",
    60: "Detailed Consultation",
  };

  @override
  void initState() {
    super.initState();
    if (widget.freeSessionsRemaining > 0) _useFree = true;
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final p = await _service.getSessionPricing();
    if (mounted) {
      setState(() {
        _prices = p;
        _loadingPrices = false;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null || _topicCtrl.text.isEmpty) return;

    if (_useFree && _duration > 30) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Free sessions max 30 mins."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isBooking = true);
    try {
      await _service.bookSession(
        clientId: widget.clientId,
        clientName: widget.clientName,
        startTime: _selectedSlot!.startTime,
        durationMinutes: _duration,
        topic: _topicCtrl.text.trim(),
        useFreeSession: _useFree,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_useFree ? "Session Confirmed!" : "Booking Request Sent. Proceed to Payment."), backgroundColor: Colors.green));
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Book Session", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryColor)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Duration Selector
                    const Text("Select Duration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_loadingPrices)
                      const LinearProgressIndicator()
                    else
                      SizedBox(
                        height: 130, // Fixed height for horizontal scroll
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [15, 30, 60].map((min) => _buildDurationCard(min, primaryColor)).toList(),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // 3. Topic Input
                    _buildTextField("Reason for consultation", _topicCtrl, Icons.edit_note),

                    const SizedBox(height: 24),

                    // 4. Free Session Toggle
                    if (widget.freeSessionsRemaining > 0)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _useFree ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _useFree ? Colors.green.shade200 : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: _useFree ? Colors.green : Colors.grey, shape: BoxShape.circle),
                              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Use Free Session", style: TextStyle(fontWeight: FontWeight.bold, color: _useFree ? Colors.green.shade800 : Colors.black54)),
                                  Text("${widget.freeSessionsRemaining} remaining", style: TextStyle(fontSize: 12, color: _useFree ? Colors.green.shade600 : Colors.grey)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _useFree,
                              onChanged: _duration > 30 ? null : (v) => setState(() => _useFree = v),
                              activeColor: Colors.green,
                            )
                          ],
                        ),
                      ),

                    if (_duration > 30 && widget.freeSessionsRemaining > 0)
                      const Padding(padding: EdgeInsets.only(top: 8, left: 4), child: Text("⚠️ Free sessions are limited to 30 mins.", style: TextStyle(fontSize: 12, color: Colors.red))),

                    const SizedBox(height: 24),

                    // 5. Slot Selection
                    const Text("Available Slots", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: StreamBuilder<List<AppointmentSlot>>(
                          stream: _service.streamAvailableSlots(),
                          builder: (ctx, snap) {
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                            final slots = snap.data!;
                            if (slots.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, color: Colors.grey.shade300, size: 40), const SizedBox(height: 8), const Text("No slots available.", style: TextStyle(color: Colors.grey))]));

                            return GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                              itemCount: slots.length,
                              itemBuilder: (ctx, i) {
                                final slot = slots[i];
                                final isSel = _selectedSlot?.id == slot.id;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedSlot = slot),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSel ? primaryColor : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSel ? primaryColor : Colors.grey.shade300),
                                      boxShadow: isSel ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                        DateFormat('d MMM\nh:mm a').format(slot.startTime),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black87)
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Total", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(_useFree ? "FREE" : "₹$currentPrice", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _useFree ? Colors.green : primaryColor)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isBooking ? null : _confirmBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: primaryColor.withOpacity(0.4),
                        ),
                        child: _isBooking
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_useFree ? "CONFIRM BOOKING" : "PAY & BOOK", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard(int min, Color primaryColor) {
    final isSelected = _duration == min;
    return GestureDetector(
      onTap: () => setState(() {
        _duration = min;
        if (min > 30) _useFree = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: 2),
          boxShadow: [BoxShadow(color: isSelected ? primaryColor.withOpacity(0.3) : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$min Mins", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text("₹${_prices[min.toString()] ?? '-'}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white70 : primaryColor)),
            const Spacer(),
            Text(_descriptions[min] ?? "", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}