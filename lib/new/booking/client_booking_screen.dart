import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

import 'package:nutricare_connect/features/auth/auth_provider.dart';

class ClientBookingScreen extends ConsumerStatefulWidget {
  final String tenantId;
  final String? initialCoachId;

  const ClientBookingScreen({
    super.key,
    required this.tenantId,
    this.initialCoachId,
  });

  @override
  ConsumerState<ClientBookingScreen> createState() => _ClientBookingScreenState();
}

class _ClientBookingScreenState extends ConsumerState<ClientBookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;

  String? _selectedDepartment;
  String? _selectedDoctorId;
  String? _selectedDoctorName;

  bool _isProcessing = false;
  bool _isDownloading = false;
  final int _bookingBufferHours = 2;

  Map<String, dynamic>? _successBookingData;
  final GlobalKey _slipKey = GlobalKey();

  // 🎯 FAMILY MEMBER STATE
  bool _isForFamily = false;
  bool _isAddingNewFamily = false;
  bool _saveFamilyMember = true;
  List<Map<String, dynamic>> _savedFamilyMembers = [];
  Map<String, dynamic>? _selectedFamilyMember;

  final TextEditingController _familyNameController = TextEditingController();
  final TextEditingController _familyPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDoctorId = widget.initialCoachId;

    // Fetch saved family members immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFamilyMembers();
    });
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _familyPhoneController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 🚀 FETCH FAMILY MEMBERS
  // ===========================================================================
  Future<void> _fetchFamilyMembers() async {
    final clientProfile = ref.read(authNotifierProvider).clientProfile;
    if (clientProfile != null) {
      final doc = await FirebaseFirestore.instance.collection('clients').doc(clientProfile.id).get();
      if (doc.exists && doc.data()!.containsKey('familyMembers')) {
        setState(() {
          _savedFamilyMembers = List<Map<String, dynamic>>.from(doc.data()!['familyMembers']);
          if (_savedFamilyMembers.isNotEmpty) {
            _selectedFamilyMember = _savedFamilyMembers.first;
          } else {
            _isAddingNewFamily = true;
          }
        });
      } else {
        setState(() => _isAddingNewFamily = true);
      }
    }
  }

  // ===========================================================================
  // 🚀 CONFIRMATION DIALOG (NEW)
  // ===========================================================================
  void _showConfirmationDialog() {
    if (_selectedDoctorId == null || _selectedDoctorName == null) {
      _showToast("Please select a specialist first.", isError: true);
      return;
    }

    if (_isForFamily && _isAddingNewFamily) {
      if (_familyNameController.text.trim().isEmpty || _familyPhoneController.text.trim().isEmpty) {
        _showToast("Please enter the patient's name and phone number.", isError: true);
        return;
      }
    }

    final String patientName = _isForFamily
        ? (_isAddingNewFamily ? _familyNameController.text.trim() : _selectedFamilyMember!['name'])
        : "Yourself";

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.event_available_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text("Confirm Booking", style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("You are about to book an appointment with:", style: TextStyle(color: theme.hintColor, fontSize: 13)),
            const SizedBox(height: 12),
            _buildDialogRow(Icons.person, "Patient", patientName, theme),
            _buildDialogRow(Icons.medical_services_rounded, "Doctor", "Dr. $_selectedDoctorName", theme),
            _buildDialogRow(Icons.calendar_today_rounded, "Date", DateFormat('EEEE, MMM d').format(_selectedDate), theme),
            _buildDialogRow(Icons.access_time_rounded, "Time", _selectedSlot!, theme),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processFinalBooking(); // Proceed to actually book
            },
            child: const Text("Confirm & Book", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(child: Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 14))),
        ],
      ),
    );
  }

  // ===========================================================================
  // 🚀 CORE BOOKING LOGIC
  // ===========================================================================
  Future<void> _processFinalBooking() async {
    final clientProfile = ref.read(authNotifierProvider).clientProfile;
    if (clientProfile == null) return;

    setState(() => _isProcessing = true);

    try {
      final String hexCode = Random().nextInt(0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
      final String bookingRef = "NC-$hexCode";
      final String appointmentDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final String userUid = FirebaseAuth.instance.currentUser?.uid ?? clientProfile.id;

      final String safeSlotId = _selectedSlot!.replaceAll(' ', '');
      final String uniqueDocId = "${_selectedDoctorId}_${appointmentDate}_$safeSlotId";

      final docRef = FirebaseFirestore.instance.collection('appointments').doc(uniqueDocId);

      // 🎯 PATIENT DETAILS LOGIC
      String? finalPatientName = clientProfile.name;
      String finalPatientPhone = clientProfile.mobile;

      if (_isForFamily) {
        if (_isAddingNewFamily) {
          finalPatientName = _familyNameController.text.trim();
          finalPatientPhone = _familyPhoneController.text.trim();

          // 🎯 Save new family member to Firestore profile if checkbox is ticked
          if (_saveFamilyMember) {
            await FirebaseFirestore.instance.collection('clients').doc(clientProfile.id).update({
              'familyMembers': FieldValue.arrayUnion([{
                'name': finalPatientName,
                'phone': finalPatientPhone,
              }])
            });
          }
        } else {
          finalPatientName = _selectedFamilyMember!['name'];
          finalPatientPhone = _selectedFamilyMember!['phone'];
        }
      }

      final Map<String, dynamic> bookingData = {
        'tenantId': widget.tenantId,
        'doctorId': _selectedDoctorId,
        'doctorName': _selectedDoctorName,
        'department': _selectedDepartment ?? 'General',
        'date': appointmentDate,
        'slot': _selectedSlot,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'bookingType': 'app_patient',
        'clientId': clientProfile.id,
        'patientUid': userUid,
        'patientName': finalPatientName,
        'patientPhone': finalPatientPhone,
        'patientEmail': clientProfile.email,
        'isFamilyMember': _isForFamily,
        'bookedByName': clientProfile.name,
        'bookingRef': bookingRef,
        'paymentStatus': 'pending',
      };

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (snapshot.exists) throw Exception("This slot was just taken. Please select another.");
        transaction.set(docRef, bookingData);
      });

      _triggerBookingNotification(bookingData, clientProfile.fcmToken);

      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _successBookingData = bookingData;
        });
      }
    } catch (e) {
      String errorMsg = e.toString().contains("just taken") ? "This slot was just taken. Please select another." : "Booking failed. Try again.";
      _showToast(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ... (Keep existing _triggerBookingNotification, _downloadSlipAsImage, _generateSlots unchanged) ...
  Future<void> _triggerBookingNotification(Map<String, dynamic> data, String? clientToken) async {
    try {
      if (clientToken != null && clientToken.isNotEmpty) {
        FirebaseFunctions.instanceFor(region: "asia-south1").httpsCallable('sendPushNotification').call({
          "token": clientToken,
          "title": "Booking Confirmed! ✅",
          "body": "Appointment for ${data['patientName']} with Dr. ${data['doctorName']} is confirmed for ${data['date']} at ${data['slot']}.",
          "payload": { "click_action": "OPEN_BOOKINGS" }
        }).catchError((_) {});
      }
    } catch (e) {}
  }

  Future<void> _downloadSlipAsImage() async {
    bool hasPermission = false;
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      final photosStatus = await Permission.photos.request();
      if (storageStatus.isGranted || photosStatus.isGranted) hasPermission = true;
    } else if (Platform.isIOS) {
      final iosStatus = await Permission.photosAddOnly.request();
      if (iosStatus.isGranted || await Permission.photos.request().isGranted) hasPermission = true;
    }

    if (!hasPermission) {
      _showToast("Permission denied. We cannot save the slip.", isError: true);
      return;
    }

    setState(() => _isDownloading = true);
    try {
      RenderRepaintBoundary boundary = _slipKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();


// ✅ New code:
      final result = await ImageGallerySaverPlus.saveImage(pngBytes, quality: 100, name: "Booking_Slip_${_successBookingData!['bookingRef']}");   if (result != null && result['isSuccess'] == true) {
        _showToast("Slip saved to your Gallery! 📸");
      } else {
        throw Exception("Gallery save failed.");
      }
    } catch (e) {
      _showToast("Failed to save slip.", isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  List<String> _generateSlots(List<dynamic> shifts, DateTime selectedDate, int slotDurationMinutes) {
    List<String> slots = [];
    DateTime now = DateTime.now();
    DateTime cutoffTime = now.add(Duration(hours: _bookingBufferHours));

    for (var shift in shifts) {
      DateTime startTimeParsed = DateFormat("HH:mm").parse(shift['start']);
      DateTime endTimeParsed = DateFormat("HH:mm").parse(shift['end']);

      while (startTimeParsed.isBefore(endTimeParsed)) {
        DateTime actualSlotTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTimeParsed.hour, startTimeParsed.minute);
        if (actualSlotTime.isAfter(cutoffTime)) slots.add(DateFormat("hh:mm a").format(startTimeParsed));
        startTimeParsed = startTimeParsed.add(Duration(minutes: slotDurationMinutes));
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_successBookingData != null) {
      return _buildSuccessSlipScreen(theme, colorScheme, isDark);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Column(
          children: [
            Text("Book Consultation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
            Text("Select a specialist and time", style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 🎯 PROPER SLIVER LAYOUT PREVENTS OVERFLOW
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSpecialistSelector(theme, colorScheme, isDark),
                    const SizedBox(height: 16),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text("Select Date", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
                    const SizedBox(height: 12),
                    _buildDateRibbon(theme, colorScheme),
                    const SizedBox(height: 24),
                    _buildPatientToggle(theme, colorScheme),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // 🎯 SLIVER WRAPPED GRID
              _buildDynamicSlotSliver(theme, colorScheme),

              const SliverPadding(padding: EdgeInsets.only(bottom: 100)), // Space for FAB
            ],
          ),

          if (_isProcessing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.1), child: Center(child: CircularProgressIndicator(color: colorScheme.primary))),
              ),
            ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedSlot == null || _isProcessing ? null : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            // 🎯 NOW CALLS CONFIRMATION DIALOG FIRST
            onPressed: _showConfirmationDialog,
            child: Text("Confirm $_selectedSlot", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🚀 FAMILY TOGGLE UI (UPDATED WITH SAVED MEMBERS)
  // ===========================================================================
  Widget _buildPatientToggle(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Who is this appointment for?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isForFamily = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: !_isForFamily ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: !_isForFamily ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : []),
                      alignment: Alignment.center,
                      child: Text("Myself", style: TextStyle(fontWeight: FontWeight.bold, color: !_isForFamily ? colorScheme.onPrimary : theme.hintColor)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isForFamily = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _isForFamily ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: _isForFamily ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : []),
                      alignment: Alignment.center,
                      child: Text("Someone Else", style: TextStyle(fontWeight: FontWeight.bold, color: _isForFamily ? colorScheme.onPrimary : theme.hintColor)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isForFamily ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: colorScheme.primary.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SAVED FAMILY MEMBERS CHIPS ---
                    if (_savedFamilyMembers.isNotEmpty) ...[
                      Text("Select Family Member:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          ..._savedFamilyMembers.map((member) {
                            bool isSelected = !_isAddingNewFamily && _selectedFamilyMember == member;
                            return ChoiceChip(
                              label: Text(member['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface)),
                              selected: isSelected,
                              selectedColor: colorScheme.primary,
                              onSelected: (val) {
                                setState(() {
                                  _isAddingNewFamily = false;
                                  _selectedFamilyMember = member;
                                });
                              },
                            );
                          }),
                          ChoiceChip(
                            label: Text("+ Add New", style: TextStyle(fontWeight: FontWeight.bold, color: _isAddingNewFamily ? colorScheme.onPrimary : colorScheme.primary)),
                            selected: _isAddingNewFamily,
                            selectedColor: colorScheme.primary,
                            backgroundColor: colorScheme.primary.withOpacity(0.1),
                            onSelected: (val) => setState(() => _isAddingNewFamily = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- ADD NEW FORM ---
                    if (_isAddingNewFamily) ...[
                      TextField(
                        controller: _familyNameController,
                        decoration: InputDecoration(labelText: "Patient Name", prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _familyPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: "Patient Phone", prefixIcon: const Icon(Icons.phone_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Save to my family members for next time", style: TextStyle(fontSize: 12, color: theme.hintColor)),
                        value: _saveFamilyMember,
                        activeColor: colorScheme.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) => setState(() => _saveFamilyMember = val ?? true),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 🚀 GRID UI (CONVERTED TO SLIVER TO PREVENT LAYOUT BREAKS)
  // ===========================================================================
  Widget _buildDynamicSlotSliver(ThemeData theme, ColorScheme colorScheme) {
    if (_selectedDoctorId == null) {
      return SliverToBoxAdapter(child: _buildEmptyState("Please select a specialist above.", theme));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('provider_schedules').doc(_selectedDoctorId).snapshots(),
      builder: (context, scheduleSnap) {
        if (!scheduleSnap.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        if (!scheduleSnap.data!.exists) return SliverToBoxAdapter(child: _buildEmptyState("Specialist schedule not found.", theme));

        var data = scheduleSnap.data!.data() as Map<String, dynamic>?;
        var daySchedule = data?['weeklySchedule']?[_selectedDate.weekday.toString()] ?? [];
        int slotDurationMins = data?['slotDuration'] ?? 30;
        int maxPatientsPerDay = data?['maxPatientsPerDay'] ?? 999;

        if (daySchedule.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("Dr. $_selectedDoctorName is off duty on this day.", theme));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('appointments')
              .where('tenantId', isEqualTo: widget.tenantId)
              .where('doctorId', isEqualTo: _selectedDoctorId)
              .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate))
              .where('status', whereIn: ['confirmed', 'blocked', 'promoted'])
              .snapshots(),
          builder: (context, apptSnap) {
            if (!apptSnap.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));

            List<String> bookedSlots = apptSnap.data!.docs.map((d) => (d.data() as Map<String, dynamic>)['slot'].toString()).toList();

            if (bookedSlots.length >= maxPatientsPerDay) {
              return SliverToBoxAdapter(child: _buildEmptyState("Dr. $_selectedDoctorName is fully booked today.", theme));
            }

            List<String> allSlots = _generateSlots(daySchedule, _selectedDate, slotDurationMins);

            if (allSlots.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("No slots remaining for this day.", theme));

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 2.2, crossAxisSpacing: 12, mainAxisSpacing: 12
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    String slotTime = allSlots[index];
                    bool isBooked = bookedSlots.contains(slotTime);
                    bool isSelected = _selectedSlot == slotTime;

                    return GestureDetector(
                      onTap: isBooked ? null : () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedSlot = slotTime);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isBooked ? theme.dividerColor.withOpacity(0.05) : isSelected ? colorScheme.primary : theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isBooked ? Colors.transparent : isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          slotTime,
                          style: TextStyle(
                            decoration: isBooked ? TextDecoration.lineThrough : TextDecoration.none,
                            color: isBooked ? theme.hintColor.withOpacity(0.5) : isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                            fontWeight: FontWeight.bold, fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: allSlots.length,
                ),
              ),
            );
          },
        );
      },
    );
  }







  // ===========================================================================
  // 🚀 SUCCESS SLIP UI
  // ===========================================================================
  Widget _buildSuccessSlipScreen(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final data = _successBookingData!;
    final String companyName = "NutriCare Clinic";

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
              ),
              const SizedBox(height: 12),
              Text("Booking Confirmed!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: colorScheme.onSurface)),
              Text("We've sent a notification to your device.", style: TextStyle(color: theme.hintColor, fontSize: 13)),
              const SizedBox(height: 32),

              // 🎯 1. REPAINT BOUNDARY (Allows us to snapshot this container)
              RepaintBoundary(
                key: _slipKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.2), width: 1.5),
                    // Shadow removed during boundary capture to prevent weird artifacts in downloaded image
                    boxShadow: _isDownloading ? [] : [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Text(companyName.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.primary, letterSpacing: 1)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 1)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("BOOKING REF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.hintColor, letterSpacing: 1)),
                              Text(data['bookingRef'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.primary)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text("PAY AT CLINIC", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 9)),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text("APPOINTMENT TIME", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.hintColor, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(data['slot'], style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1)),
                      Text(
                          DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(data['date'])),
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14)
                      ),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                        ),
                        child: QrImageView(
                          data: data['bookingRef'] ?? "NO_REF",
                          version: QrVersions.auto,
                          size: 160.0,
                          gapless: false,
                          foregroundColor: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(data['patientName'].toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                          "Dr. ${data['doctorName']} • ${data['department']}",
                          style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please present this QR code at the reception.",
                        style: TextStyle(fontSize: 10, color: theme.hintColor, fontStyle: FontStyle.italic),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 🎯 2. THE DUAL ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: theme.dividerColor),
                      ),
                      icon: _isDownloading
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                          : const Icon(Icons.download_rounded),
                      label: Text(_isDownloading ? "SAVING..." : "SAVE SLIP", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      onPressed: _isDownloading ? null : _downloadSlipAsImage, // Triggers download
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text("WHATSAPP", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final String msg = "Appointment Confirmed at $companyName\n\nPatient: ${data['patientName']}\nRef: ${data['bookingRef']}\nDate: ${data['date']}\nTime: ${data['slot']}\n\nSee you soon!";
                        final Uri waUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(msg)}");
                        if (await canLaunchUrl(waUrl)) {
                          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Back to Dashboard", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🚀 DYNAMIC UI BUILDERS (Selectors & Grid)
  // ===========================================================================

  Widget _buildSpecialistSelector(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('provider_schedules')
          .where('tenantId', isEqualTo: widget.tenantId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));

        var scheduleDocs = snap.data!.docs;

        List<String> departments = scheduleDocs
            .map((doc) => (doc.data() as Map<String, dynamic>)['department']?.toString() ?? 'General')
            .toSet().toList()..sort();

        List<QueryDocumentSnapshot> filteredDoctors = _selectedDepartment == null
            ? scheduleDocs
            : scheduleDocs.where((doc) => (doc.data() as Map<String, dynamic>)['department'] == _selectedDepartment).toList();

        if (_selectedDoctorName == null && _selectedDoctorId != null) {
          try {
            final doc = scheduleDocs.firstWhere((d) => d.id == _selectedDoctorId);
            _selectedDoctorName = (doc.data() as Map<String, dynamic>)['providerName'];
            _selectedDepartment = (doc.data() as Map<String, dynamic>)['department'];
          } catch (_) {}
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 90,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  direction: Axis.vertical,
                  spacing: 8,
                  runSpacing: 8,
                  children: departments.map((dept) {
                    bool isSelected = _selectedDepartment == dept;
                    return ChoiceChip(
                      label: Text(dept, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface)),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      backgroundColor: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : theme.dividerColor.withOpacity(0.1))),
                      onSelected: (val) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDepartment = val ? dept : null;
                          _selectedDoctorId = null;
                          _selectedDoctorName = null;
                          _selectedSlot = null;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: filteredDoctors.length,
                itemBuilder: (context, index) {
                  final doc = filteredDoctors[index];
                  final data = doc.data() as Map<String, dynamic>;
                  bool isSelected = _selectedDoctorId == doc.id;
                  final String exp = data['experience']?.toString() ?? "5";
                  final dynamic qualRaw = data['qualifications'];
                  final String qualifications = qualRaw is List ? qualRaw.join(', ') : (qualRaw?.toString() ?? 'Specialist');

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDoctorId = doc.id;
                        _selectedDoctorName = data['providerName'];
                        _selectedDepartment = data['department'];
                        _selectedSlot = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 270,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary.withOpacity(isDark ? 0.2 : 0.05) : theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: colorScheme.primaryContainer,
                                backgroundImage: data['photoUrl'] != null ? CachedNetworkImageProvider(data['photoUrl']) : null,
                                child: data['photoUrl'] == null ? Icon(Icons.person, color: colorScheme.primary) : null,
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                  child: const Icon(Icons.verified, color: Colors.white, size: 10),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data['providerName'] ?? 'Doctor',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: colorScheme.onSurface),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  qualifications,
                                  style: TextStyle(color: colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.work_history_rounded, size: 10, color: theme.hintColor),
                                    const SizedBox(width: 4),
                                    Text("$exp+ Years Exp", style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDynamicSlotGrid(ThemeData theme, ColorScheme colorScheme) {
    if (_selectedDoctorId == null) {
      return _buildEmptyState("Please select a specialist above to view their availability.", theme);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('provider_schedules').doc(_selectedDoctorId).snapshots(),
      builder: (context, scheduleSnap) {
        if (!scheduleSnap.hasData) return const Center(child: CircularProgressIndicator());
        if (!scheduleSnap.data!.exists) return _buildEmptyState("Specialist schedule not found.", theme);

        var data = scheduleSnap.data!.data() as Map<String, dynamic>?;
        var daySchedule = data?['weeklySchedule']?[_selectedDate.weekday.toString()] ?? [];
        int slotDurationMins = data?['slotDuration'] ?? 30;
        int maxPatientsPerDay = data?['maxPatientsPerDay'] ?? 999;

        if (daySchedule.isEmpty) return _buildEmptyState("Dr. $_selectedDoctorName is off duty on this day.", theme);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('appointments')
              .where('tenantId', isEqualTo: widget.tenantId)
              .where('doctorId', isEqualTo: _selectedDoctorId)
              .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate))
              .where('status', whereIn: ['confirmed', 'blocked', 'promoted'])
              .snapshots(),
          builder: (context, apptSnap) {
            if (!apptSnap.hasData) return const Center(child: CircularProgressIndicator());

            List<String> bookedSlots = apptSnap.data!.docs
                .map((d) => (d.data() as Map<String, dynamic>)['slot'].toString())
                .toList();

            if (bookedSlots.length >= maxPatientsPerDay) {
              return _buildEmptyState("Dr. $_selectedDoctorName is fully booked for this day.", theme);
            }

            List<String> allSlots = _generateSlots(daySchedule, _selectedDate, slotDurationMins);

            if (allSlots.isEmpty) return _buildEmptyState("No slots remaining for this day.", theme);

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 2.2, crossAxisSpacing: 12, mainAxisSpacing: 12
              ),
              itemCount: allSlots.length,
              itemBuilder: (context, index) {
                String slotTime = allSlots[index];
                bool isBooked = bookedSlots.contains(slotTime);
                bool isSelected = _selectedSlot == slotTime;

                return GestureDetector(
                  onTap: isBooked ? null : () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedSlot = slotTime);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isBooked ? theme.dividerColor.withOpacity(0.05) : isSelected ? colorScheme.primary : theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isBooked ? Colors.transparent : isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      slotTime,
                      style: TextStyle(
                        decoration: isBooked ? TextDecoration.lineThrough : TextDecoration.none,
                        color: isBooked ? theme.hintColor.withOpacity(0.5) : isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                        fontWeight: FontWeight.bold, fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDateRibbon(ThemeData theme, ColorScheme colorScheme) {
    final List<DateTime> upcomingDays = List.generate(14, (index) => DateTime.now().add(Duration(days: index)));

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: upcomingDays.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final date = upcomingDays[index];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);

          return GestureDetector(
            onTap: () => setState(() {
              HapticFeedback.selectionClick();
              _selectedDate = date;
              _selectedSlot = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 65, margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1), width: 1.5),
                boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white70 : theme.hintColor)),
                  const SizedBox(height: 4),
                  Text(DateFormat('d').format(date), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(DateFormat('EEE').format(date), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? Colors.white70 : theme.hintColor)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 60, color: theme.dividerColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              message,
              style: const TextStyle(
                  color: Colors.white, // 🎯 Forced white text!
                  fontWeight: FontWeight.bold
              )
          ),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
          behavior: SnackBarBehavior.floating,
        )
    );
  }
}