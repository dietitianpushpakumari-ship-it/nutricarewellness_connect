import 'dart:math';
import 'dart:ui' as ui;
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

import 'package:pure_shift/features/auth/auth_provider.dart';
// 🚀 THE FIX: Use your layout_utils for consistent scaling
import 'package:pure_shift/layout_utils.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

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
  // 🛡️ REUSABLE UI COMPONENTS
  // ===========================================================================

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
      child: Row(
        children: [
          Container(width: context.scale(4), height: context.scale(12), color: accentColor),
          SizedBox(width: context.scale(8)),
          Text(
              title,
              style: TextStyle(
                  fontFamily: kDisplayFont,
                  fontWeight: FontWeight.w900,
                  fontSize: context.scale(10),
                  letterSpacing: 2.0,
                  color: accentColor.withOpacity(0.8)
              )
          ),
          SizedBox(width: context.scale(12)),
          Expanded(child: Container(height: 1, color: accentColor.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _buildTextField(ThemeData theme, String label, TextEditingController ctrl, {bool isPhone = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(13), fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), letterSpacing: 1.0, fontWeight: FontWeight.w700, color: theme.hintColor),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.scale(12)), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
        contentPadding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(14)),
      ),
    );
  }

  // ===========================================================================
  // 🚀 MAIN BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final solidBgColor = isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC);
    final accentCyan = const Color(0xFF00E5FF);

    if (_successBookingData != null) {
      return _buildSuccessSlipScreen(theme, colorScheme, isDark, accentCyan, solidBgColor);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (_, scrollController) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: solidBgColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(24))),
                border: Border(top: BorderSide(color: accentCyan.withOpacity(0.5), width: 2.0)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: context.scale(12)),
                      child: Container(width: context.scale(40), height: context.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(context.scale(2)))),
                    ),
                  ),

                  // Header
                  _buildStickyHeader(theme, isDark),

                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: context.scale(20)),
                              _buildSpecialistSelector(theme, colorScheme, isDark, accentCyan),
                              SizedBox(height: context.scale(32)),
                              _buildSectionHeader("SELECT TIMEFRAME", accentCyan),
                              SizedBox(height: context.scale(16)),
                              _buildDateRibbon(theme, colorScheme, isDark, accentCyan),
                              SizedBox(height: context.scale(32)),
                              _buildSectionHeader("PATIENT DETAILS", accentCyan),
                              SizedBox(height: context.scale(16)),
                              _buildPatientToggle(theme, colorScheme, isDark, accentCyan),
                              SizedBox(height: context.scale(32)),
                              _buildSectionHeader("AVAILABLE SLOTS", accentCyan),
                              SizedBox(height: context.scale(16)),
                            ],
                          ),
                        ),
                        _buildDynamicSlotSliver(theme, colorScheme, isDark, accentCyan),
                        SliverPadding(padding: EdgeInsets.only(bottom: context.scale(140))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Bar
            if (_selectedSlot != null && !_isProcessing)
              _buildBottomAction(context, colorScheme, solidBgColor, isDark),

            if (_isProcessing)
              _buildProcessingOverlay(accentCyan),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(context.scale(24), 0, context.scale(16), context.scale(16)),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CLINICAL BOOKING", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black87)),
                Text("INITIALIZE PROTOCOL", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), letterSpacing: 1.5, color: theme.hintColor, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          IconButton(
              icon: Icon(Icons.close_rounded, size: context.scale(22), color: theme.hintColor.withOpacity(0.5)),
              onPressed: () => Navigator.pop(context)
          )
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, ColorScheme colorScheme, Color bgColor, bool isDark) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            context.scale(24),
            context.scale(16),
            context.scale(24),
            MediaQuery.of(context).padding.bottom + context.scale(16)
        ),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: context.scale(52),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(12))),
              elevation: 0,
            ),
            onPressed: _showConfirmationDialog,
            // 🚀 SHORTENED TEXT: Keeps the UI clean and punchy
            child: Text(
                "CONFIRM $_selectedSlot",
                style: TextStyle(
                    fontFamily: kDisplayFont,
                    fontSize: context.scale(13),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white
                )
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildProcessingOverlay(Color accentCyan) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(color: Colors.black.withOpacity(0.4), child: Center(child: CircularProgressIndicator(color: accentCyan, strokeWidth: 3))),
      ),
    );
  }

  // ===========================================================================
  // 🚀 PREMIUM CONFIRMATION DIALOG
  // ===========================================================================
  void _showConfirmationDialog() {
    if (_selectedDoctorId == null || _selectedDoctorName == null) {
      _showToast("PLEASE SELECT A SPECIALIST", isError: true);
      return;
    }
    if (_isForFamily && _isAddingNewFamily) {
      if (_familyNameController.text.trim().isEmpty || _familyPhoneController.text.trim().isEmpty) {
        _showToast("PATIENT DETAILS REQUIRED", isError: true);
        return;
      }
    }

    final String patientName = _isForFamily ? (_isAddingNewFamily ? _familyNameController.text.trim() : _selectedFamilyMember!['name']) : "Yourself";
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentCyan = const Color(0xFF00E5FF);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF121826) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16)), side: BorderSide(color: accentCyan.withOpacity(0.5), width: 1.5)),
        title: Row(
          children: [
            Icon(Icons.security_rounded, color: accentCyan),
            SizedBox(width: context.scale(8)),
            Text("CONFIRM PROTOCOL", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(13), letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("INITIALIZING APPOINTMENT WITH:", style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            SizedBox(height: context.scale(16)),
            _buildDialogRow(Icons.person, "PATIENT", patientName.toUpperCase(), theme),
            _buildDialogRow(Icons.medical_services_rounded, "SPECIALIST", "DR. ${_selectedDoctorName!.toUpperCase()}", theme),
            _buildDialogRow(Icons.calendar_today_rounded, "DATE", DateFormat('EEEE, MMM d').format(_selectedDate).toUpperCase(), theme),
            _buildDialogRow(Icons.access_time_rounded, "TIME", _selectedSlot!, theme),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontWeight: FontWeight.w800, letterSpacing: 1.0))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCyan.withOpacity(0.15), foregroundColor: accentCyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(8)), side: BorderSide(color: accentCyan.withOpacity(0.5))),
              elevation: 0,
            ),
            onPressed: () { Navigator.pop(ctx); _processFinalBooking(); },
            child: Text("AUTHORIZE", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? accentCyan : theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.scale(12.0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.scale(14), color: theme.colorScheme.primary),
          SizedBox(width: context.scale(8)),
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontWeight: FontWeight.w800, fontSize: context.scale(10), letterSpacing: 1.0))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontFamily: kDisplayFont, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: context.scale(12), letterSpacing: 0.5))),
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

      String? finalPatientName = clientProfile.name;
      String finalPatientPhone = clientProfile.mobile;

      if (_isForFamily) {
        if (_isAddingNewFamily) {
          finalPatientName = _familyNameController.text.trim();
          finalPatientPhone = _familyPhoneController.text.trim();
          if (_saveFamilyMember) {
            await FirebaseFirestore.instance.collection('clients').doc(clientProfile.id).update({
              'familyMembers': FieldValue.arrayUnion([{'name': finalPatientName, 'phone': finalPatientPhone}])
            });
          }
        } else {
          finalPatientName = _selectedFamilyMember!['name'];
          finalPatientPhone = _selectedFamilyMember!['phone'];
        }
      }

      final Map<String, dynamic> bookingData = {
        'tenantId': widget.tenantId, 'doctorId': _selectedDoctorId, 'doctorName': _selectedDoctorName,
        'department': _selectedDepartment ?? 'General', 'date': appointmentDate, 'slot': _selectedSlot,
        'status': 'confirmed', 'createdAt': FieldValue.serverTimestamp(), 'bookingType': 'app_patient',
        'clientId': clientProfile.id, 'patientUid': userUid, 'patientName': finalPatientName,
        'patientPhone': finalPatientPhone, 'patientEmail': clientProfile.email,
        'isFamilyMember': _isForFamily, 'bookedByName': clientProfile.name, 'bookingRef': bookingRef, 'paymentStatus': 'pending',
      };

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (snapshot.exists) throw Exception("SLOT TAKEN");
        transaction.set(docRef, bookingData);
      });

      _triggerBookingNotification(bookingData, clientProfile.fcmToken);
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _successBookingData = bookingData);
    } catch (e) {
      String errorMsg = e.toString().contains("SLOT TAKEN") ? "SLOT NO LONGER AVAILABLE. SELECT ANOTHER." : "SYSTEM ERROR. TRY AGAIN.";
      _showToast(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _triggerBookingNotification(Map<String, dynamic> data, String? clientToken) async {
    try {
      if (clientToken != null && clientToken.isNotEmpty) {
        // 🚀 THE FIX: Use 'await' so the try/catch block handles any Firebase AppCheck errors safely
        await FirebaseFunctions.instanceFor(region: "asia-south1").httpsCallable('sendPushNotification').call({
          "token": clientToken,
          "title": "Booking Confirmed! ✅",
          "body": "Appointment for ${data['patientName']} with Dr. ${data['doctorName']} is confirmed for ${data['date']} at ${data['slot']}.",
          "payload": { "click_action": "OPEN_BOOKINGS" }
        });
      }
    } catch (e) {
      // Safely catches the AppCheck or Network error without crashing the app
      debugPrint("Notification Failed silently: $e");
    }
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

    if (!hasPermission) { _showToast("STORAGE PERMISSION DENIED", isError: true); return; }

    setState(() => _isDownloading = true);
    try {
      RenderRepaintBoundary boundary = _slipKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(pngBytes, quality: 100, name: "Booking_Slip_${_successBookingData!['bookingRef']}");
      if (result != null && result['isSuccess'] == true) _showToast("TICKET SAVED TO GALLERY 📸");
      else throw Exception("SAVE FAILED");
    } catch (e) {
      _showToast("SYSTEM ERROR: FAILED TO SAVE", isError: true);
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

  // ===========================================================================
  // 🚀 SPECIALIST SELECTOR
  // ===========================================================================
  Widget _buildSpecialistSelector(ThemeData theme, ColorScheme colorScheme, bool isDark, Color accentCyan) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('provider_schedules')
          .where('tenantId', isEqualTo: widget.tenantId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return SizedBox(height: context.scale(150), child: Center(child: CircularProgressIndicator(color: accentCyan)));
        var scheduleDocs = snap.data!.docs;
        if (scheduleDocs.isEmpty) return _buildEmptyState("NO SPECIALISTS FOUND", theme);

        if (scheduleDocs.length == 1) {
          final doc = scheduleDocs.first;
          final data = doc.data() as Map<String, dynamic>;

          // 🚀 THE FIX: Check if the name is null, even if the ID already matches!
          if (_selectedDoctorId != doc.id || _selectedDoctorName == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if(mounted) {
                setState(() {
                  _selectedDoctorId = doc.id;
                  _selectedDoctorName = data['providerName'];
                  _selectedDepartment = data['department'];
                });
              }
            });
          }
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("ASSIGNED SPECIALIST", accentCyan),
                SizedBox(height: context.scale(16)),
                _buildSingleSpecialistCard(data, theme, colorScheme, isDark, accentCyan),
              ],
            ),
          );
        }

        List<String> departments = scheduleDocs.map((doc) => (doc.data() as Map<String, dynamic>)['department']?.toString() ?? 'General').toSet().toList()..sort();
        List<QueryDocumentSnapshot> filteredDoctors = _selectedDepartment == null ? scheduleDocs : scheduleDocs.where((doc) => (doc.data() as Map<String, dynamic>)['department'] == _selectedDepartment).toList();

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
            _buildSectionHeader("SELECT DEPARTMENT", accentCyan),
            SizedBox(height: context.scale(16)),
            SizedBox(
              height: context.scale(50),
              child: ListView.separated(
                scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
                itemCount: departments.length, separatorBuilder: (_,__) => SizedBox(width: context.scale(8)),
                itemBuilder: (context, index) {
                  final dept = departments[index]; bool isSelected = _selectedDepartment == dept;
                  return ChoiceChip(
                    label: Text(dept.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isSelected ? Colors.white : colorScheme.onSurface)),
                    selected: isSelected, selectedColor: colorScheme.primary, backgroundColor: isDark ? const Color(0xFF121826) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(6)), side: BorderSide(color: isSelected ? Colors.transparent : theme.dividerColor.withOpacity(0.1))),
                    onSelected: (val) { HapticFeedback.selectionClick(); setState(() { _selectedDepartment = val ? dept : null; _selectedDoctorId = null; _selectedDoctorName = null; _selectedSlot = null; }); },
                  );
                },
              ),
            ),
            SizedBox(height: context.scale(32)),
            _buildSectionHeader("AVAILABLE SPECIALISTS", accentCyan),
            SizedBox(height: context.scale(16)),
            SizedBox(
              height: context.scale(120),
              child: ListView.builder(
                scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: context.scale(24)), physics: const BouncingScrollPhysics(), itemCount: filteredDoctors.length,
                itemBuilder: (context, index) {
                  final doc = filteredDoctors[index]; final data = doc.data() as Map<String, dynamic>;
                  bool isSelected = _selectedDoctorId == doc.id; final String exp = data['experience']?.toString() ?? "5";
                  return GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); setState(() { _selectedDoctorId = doc.id; _selectedDoctorName = data['providerName']; _selectedDepartment = data['department']; _selectedSlot = null; }); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200), width: context.scale(280), margin: EdgeInsets.only(right: context.scale(12)), padding: EdgeInsets.all(context.scale(16)),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary.withOpacity(isDark ? 0.15 : 0.05) : (isDark ? const Color(0xFF121826) : Colors.white),
                        borderRadius: BorderRadius.circular(context.scale(12)),
                        border: Border.all(color: isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1), width: isSelected ? 1.5 : 1),
                        boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.2), blurRadius: context.scale(10), offset: Offset(0, context.scale(4)))] : [],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(radius: context.scale(28), backgroundColor: colorScheme.primary.withOpacity(0.2), backgroundImage: data['photoUrl'] != null ? CachedNetworkImageProvider(data['photoUrl']) : null, child: data['photoUrl'] == null ? Icon(Icons.person, color: colorScheme.primary) : null),
                          SizedBox(width: context.scale(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(fit: BoxFit.scaleDown, child: Text(data['providerName']?.toString().toUpperCase() ?? 'DOCTOR', style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(12), letterSpacing: 1.0, color: colorScheme.onSurface))),
                                SizedBox(height: context.scale(2)),
                                Text(data['department']?.toString().toUpperCase() ?? 'SPECIALIST', style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.primary, fontSize: context.scale(9), fontWeight: FontWeight.w800, letterSpacing: 1.0), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const Spacer(),
                                Row(children: [Icon(Icons.timeline_rounded, size: context.scale(10), color: theme.hintColor), SizedBox(width: context.scale(4)), Text("Lvl $exp Clearance", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(9), color: theme.hintColor, fontWeight: FontWeight.w600))]),
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

  Widget _buildSingleSpecialistCard(Map<String, dynamic> data, ThemeData theme, ColorScheme colorScheme, bool isDark, Color accentCyan) {
    final String? imageUrl = data['photoUrl'];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.scale(20)),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121826) : Colors.white,
          borderRadius: BorderRadius.circular(context.scale(12)),
          border: Border.all(color: accentCyan.withOpacity(0.4), width: 1.0)
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: context.scale(30),
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            child: ClipOval(
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: context.scale(60),
                height: context.scale(60),
                placeholder: (context, url) => CircularProgressIndicator(strokeWidth: 2, color: accentCyan),
                errorWidget: (context, url, error) => Icon(Icons.person, color: accentCyan, size: context.scale(30)),
              )
                  : Icon(Icons.person, color: accentCyan, size: context.scale(30)),
            ),
          ),
          SizedBox(width: context.scale(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PRIMARY SPECIALIST", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w900, color: accentCyan, letterSpacing: 1.5)),
                SizedBox(height: context.scale(4)),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                        data['providerName']?.toString().toUpperCase() ?? 'SPECIALIST',
                        style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(12), letterSpacing: 0.5, color: colorScheme.onSurface)
                    )
                ),
                Text(
                    data['department']?.toString().toUpperCase() ?? 'CLINICAL TEAM',
                    style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontSize: context.scale(9), fontWeight: FontWeight.w700, letterSpacing: 1.0)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
  // ===========================================================================
  // 🚀 PATIENT DETAILS
  // ===========================================================================
  Widget _buildPatientToggle(ThemeData theme, ColorScheme colorScheme, bool isDark, Color accentCyan) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(context.scale(4)),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(context.scale(12)), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
            child: Row(
              children: [
                Expanded(child: GestureDetector(onTap: () => setState(() => _isForFamily = false), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.symmetric(vertical: context.scale(12)), decoration: BoxDecoration(color: !_isForFamily ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(context.scale(8))), alignment: Alignment.center, child: Text("PRIMARY", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: context.scale(10), color: !_isForFamily ? Colors.white : theme.hintColor))))),
                Expanded(child: GestureDetector(onTap: () => setState(() => _isForFamily = true), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.symmetric(vertical: context.scale(12)), decoration: BoxDecoration(color: _isForFamily ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(context.scale(8))), alignment: Alignment.center, child: Text("DEPENDENT", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: context.scale(10), color: _isForFamily ? Colors.white : theme.hintColor))))),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300), crossFadeState: _isForFamily ? CrossFadeState.showSecond : CrossFadeState.showFirst, firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: EdgeInsets.only(top: context.scale(16)),
              child: Container(
                padding: EdgeInsets.all(context.scale(20)), decoration: BoxDecoration(color: isDark ? const Color(0xFF121826) : Colors.white, borderRadius: BorderRadius.circular(context.scale(12)), border: Border.all(color: accentCyan.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_savedFamilyMembers.isNotEmpty) ...[
                      Text("SAVED PROFILES", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w800, letterSpacing: 1.0, color: theme.hintColor)), SizedBox(height: context.scale(12)),
                      Wrap(
                        spacing: context.scale(8), runSpacing: context.scale(8),
                        children: [
                          ..._savedFamilyMembers.map((member) {
                            bool isSelected = !_isAddingNewFamily && _selectedFamilyMember == member;
                            return ChoiceChip(label: Text(member['name'].toString().toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, fontSize: context.scale(10), color: isSelected ? Colors.white : colorScheme.onSurface)), selected: isSelected, selectedColor: colorScheme.primary, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(6)), side: BorderSide(color: isSelected ? Colors.transparent : theme.dividerColor.withOpacity(0.1))), onSelected: (val) { setState(() { _isAddingNewFamily = false; _selectedFamilyMember = member; }); });
                          }),
                          ChoiceChip(label: Text("+ NEW RECORD", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, fontSize: context.scale(10), color: _isAddingNewFamily ? colorScheme.onPrimary : colorScheme.primary)), selected: _isAddingNewFamily, selectedColor: colorScheme.primary, backgroundColor: colorScheme.primary.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(6)), side: BorderSide.none), onSelected: (val) => setState(() => _isAddingNewFamily = true)),
                        ],
                      ),
                      SizedBox(height: context.scale(20)),
                    ],
                    if (_isAddingNewFamily) ...[
                      TextField(controller: _familyNameController, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12)), decoration: InputDecoration(labelText: "PATIENT NAME", labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), letterSpacing: 1.0, color: theme.hintColor), prefixIcon: Icon(Icons.person_outline, color: theme.hintColor, size: context.scale(18)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.scale(8))), contentPadding: const EdgeInsets.symmetric(vertical: 0))),
                      SizedBox(height: context.scale(16)),
                      TextField(controller: _familyPhoneController, keyboardType: TextInputType.phone, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12)), decoration: InputDecoration(labelText: "PATIENT PHONE", labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), letterSpacing: 1.0, color: theme.hintColor), prefixIcon: Icon(Icons.phone_outlined, color: theme.hintColor, size: context.scale(18)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.scale(8))), contentPadding: const EdgeInsets.symmetric(vertical: 0))),
                      SizedBox(height: context.scale(12)),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text("STORE RECORD FOR FUTURE ACCESS", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), letterSpacing: 1.0, fontWeight: FontWeight.w800, color: theme.hintColor)), value: _saveFamilyMember, activeColor: colorScheme.primary, controlAffinity: ListTileControlAffinity.leading, onChanged: (val) => setState(() => _saveFamilyMember = val ?? true))
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
  // 🚀 DATE & SLOTS
  // ===========================================================================
  Widget _buildDateRibbon(ThemeData theme, ColorScheme colorScheme, bool isDark, Color accentCyan) {
    final List<DateTime> upcomingDays = List.generate(14, (index) => DateTime.now().add(Duration(days: index)));
    return SizedBox(
      height: context.scale(100),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: upcomingDays.length, padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
        itemBuilder: (context, index) {
          final date = upcomingDays[index]; final isSelected = DateUtils.isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() { HapticFeedback.selectionClick(); _selectedDate = date; _selectedSlot = null; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200), width: context.scale(65), margin: EdgeInsets.only(right: context.scale(12)),
              decoration: BoxDecoration(color: isSelected ? colorScheme.primary : (isDark ? const Color(0xFF121826) : Colors.white), borderRadius: BorderRadius.circular(context.scale(12)), border: Border.all(color: isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1), width: isSelected ? 1.5 : 1), boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: context.scale(10), offset: Offset(0, context.scale(4)))] : []),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isSelected ? Colors.white70 : theme.hintColor)), SizedBox(height: context.scale(4)),
                  Text(DateFormat('dd').format(date), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12), fontWeight: FontWeight.w900, color: isSelected ? Colors.white : theme.colorScheme.onSurface)), SizedBox(height: context.scale(4)),
                  Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isSelected ? Colors.white70 : theme.hintColor)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDynamicSlotSliver(ThemeData theme, ColorScheme colorScheme, bool isDark, Color accentCyan) {
    if (_selectedDoctorId == null) return SliverToBoxAdapter(child: _buildEmptyState("AWAITING SPECIALIST ASSIGNMENT", theme));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('provider_schedules').doc(_selectedDoctorId).snapshots(),
      builder: (context, scheduleSnap) {
        if (!scheduleSnap.hasData) return SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: accentCyan)));
        if (!scheduleSnap.data!.exists) return SliverToBoxAdapter(child: _buildEmptyState("SCHEDULE DATA NOT FOUND", theme));

        var data = scheduleSnap.data!.data() as Map<String, dynamic>?;
        var daySchedule = data?['weeklySchedule']?[_selectedDate.weekday.toString()] ?? [];
        if (daySchedule.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("SPECIALIST OFFLINE ON SELECTED DATE", theme));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('appointments').where('tenantId', isEqualTo: widget.tenantId).where('doctorId', isEqualTo: _selectedDoctorId).where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate)).where('status', whereIn: ['confirmed', 'blocked', 'promoted']).snapshots(),
          builder: (context, apptSnap) {
            if (!apptSnap.hasData) return SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: accentCyan)));
            List<String> bookedSlots = apptSnap.data!.docs.map((d) => (d.data() as Map<String, dynamic>)['slot'].toString()).toList();
            if (bookedSlots.length >= (data?['maxPatientsPerDay'] ?? 999)) return SliverToBoxAdapter(child: _buildEmptyState("MAXIMUM CAPACITY REACHED", theme));

            List<String> allSlots = _generateSlots(daySchedule, _selectedDate, data?['slotDuration'] ?? 30);
            if (allSlots.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState("NO AVAILABLE SLOTS", theme));

            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: context.scale(24), vertical: context.scale(10)),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.4, crossAxisSpacing: context.scale(12), mainAxisSpacing: context.scale(12)),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    String slotTime = allSlots[index]; bool isBooked = bookedSlots.contains(slotTime); bool isSelected = _selectedSlot == slotTime;
                    return GestureDetector(
                      onTap: isBooked ? null : () { HapticFeedback.lightImpact(); setState(() => _selectedSlot = slotTime); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(color: isBooked ? (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)) : isSelected ? colorScheme.primary : (isDark ? const Color(0xFF121826) : Colors.white), borderRadius: BorderRadius.circular(context.scale(8)), border: Border.all(color: isBooked ? Colors.transparent : isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.1)), boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: context.scale(8))] : []),
                        alignment: Alignment.center,
                        child: Text(slotTime, style: TextStyle(fontFamily: kDisplayFont, decoration: isBooked ? TextDecoration.lineThrough : TextDecoration.none, color: isBooked ? theme.hintColor.withOpacity(0.5) : isSelected ? Colors.white : colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: context.scale(10), letterSpacing: 0.5)),
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
  // 🚀 SUCCESS TICKET & HELPERS
  // ===========================================================================
  Widget _buildSuccessSlipScreen(ThemeData theme, ColorScheme colorScheme, bool isDark, Color accentCyan, Color solidBgColor) {
    return DraggableScrollableSheet(
        initialChildSize: 0.95, minChildSize: 0.5, maxChildSize: 0.98,
        builder: (_, scrollController) => Material(
          child: Container(
            // ✅ Removed the conflicting color property
            decoration: BoxDecoration(color: solidBgColor, borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(24))), border: Border(top: BorderSide(color: accentCyan.withOpacity(0.5), width: 2.0))),
            child: Column(
              children: [
                Center(child: Padding(padding: EdgeInsets.only(top: context.scale(12), bottom: context.scale(8)), child: Container(width: context.scale(60), height: context.scale(3), decoration: BoxDecoration(color: accentCyan.withOpacity(0.8), boxShadow: [BoxShadow(color: accentCyan, blurRadius: context.scale(10))])))),
                Container(
                  padding: EdgeInsets.only(bottom: context.scale(12)), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1))),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.scale(24), 0, context.scale(16), 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("AUTHORIZATION COMPLETE", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12), fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black87)),
                            Text("SYSTEM UPDATED & NOTIFIED", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), letterSpacing: 1.5, color: const Color(0xFF00E676), fontWeight: FontWeight.w700)),
                          ],
                        ),
                        IconButton(icon: Icon(Icons.close_rounded, size: context.scale(20), color: theme.iconTheme.color?.withOpacity(0.6)), onPressed: () => Navigator.pop(context))
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController, physics: const BouncingScrollPhysics(), padding: EdgeInsets.symmetric(horizontal: context.scale(24), vertical: context.scale(24)),
                    child: Column(
                      children: [
                        RepaintBoundary(
                          key: _slipKey,
                          child: Container(
                            width: double.infinity, padding: EdgeInsets.all(context.scale(32)),
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF121826) : Colors.white, borderRadius: BorderRadius.circular(context.scale(16)), border: Border.all(color: accentCyan.withOpacity(0.5), width: 1.5), boxShadow: _isDownloading ? [] : [BoxShadow(color: accentCyan.withOpacity(0.1), blurRadius: context.scale(20))]),
                            child: Column(
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("NUTRICARE PROTOCOL", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(12), color: accentCyan, letterSpacing: 2.0)), Icon(Icons.health_and_safety_rounded, color: accentCyan, size: context.scale(16))]),
                                Padding(padding: EdgeInsets.symmetric(vertical: context.scale(20)), child: Container(height: 1, color: isDark ? Colors.white10 : Colors.black12)),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("TICKET REF", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 2.0)), SizedBox(height: context.scale(4)), Text(_successBookingData!['bookingRef'], style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(13), fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 1.0))]), Container(padding: EdgeInsets.symmetric(horizontal: context.scale(10), vertical: context.scale(4)), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(context.scale(4))), child: Text("PENDING", style: TextStyle(fontFamily: kDisplayFont, color: Colors.orange, fontWeight: FontWeight.w900, fontSize: context.scale(8), letterSpacing: 1.0)))]),
                                SizedBox(height: context.scale(24)),
                                Text("SCHEDULED TIMEFRAME", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(8), fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 2.0)), SizedBox(height: context.scale(8)),
                                Text(_successBookingData!['slot'], style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(36), fontWeight: FontWeight.w900, color: colorScheme.primary, height: 1.0)), SizedBox(height: context.scale(4)),
                                Text(DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(_successBookingData!['date'])).toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: context.scale(10), letterSpacing: 1.0)),
                                SizedBox(height: context.scale(32)),
                                Container(padding: EdgeInsets.all(context.scale(16)), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(context.scale(12)), border: Border.all(color: accentCyan, width: 2)), child: QrImageView(data: _successBookingData!['bookingRef'] ?? "NO_REF", version: QrVersions.auto, size: context.scale(140.0), gapless: false, foregroundColor: Colors.black)),
                                SizedBox(height: context.scale(32)),
                                Text(_successBookingData!['patientName'].toString().toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(13), color: colorScheme.onSurface, letterSpacing: 1.5)), SizedBox(height: context.scale(8)),
                                Text("DR. ${_successBookingData!['doctorName'].toString().toUpperCase()} // ${_successBookingData!['department'].toString().toUpperCase()}", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), color: theme.hintColor, fontWeight: FontWeight.w800, letterSpacing: 1.0), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: context.scale(32)),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: context.scale(16)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(8))), side: BorderSide(color: isDark ? Colors.white24 : Colors.black26)), icon: _isDownloading ? SizedBox(width: context.scale(14), height: context.scale(14), child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)) : Icon(Icons.download_rounded, size: context.scale(16)), label: Text(_isDownloading ? "SAVING..." : "SAVE TICKET", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(10), letterSpacing: 1.0, color: colorScheme.onSurface)), onPressed: _isDownloading ? null : _downloadSlipAsImage)),
                            SizedBox(width: context.scale(12)),
                            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: context.scale(16)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(8))), elevation: 0), icon: Icon(Icons.share_rounded, size: context.scale(16)), label: Text("TRANSMIT", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w900, fontSize: context.scale(10), letterSpacing: 1.0)), onPressed: () async { final String msg = "Protocol Authorized: NUTRICARE PROTOCOL\n\nPatient: ${_successBookingData!['patientName']}\nRef: ${_successBookingData!['bookingRef']}\nDate: ${_successBookingData!['date']}\nTime: ${_successBookingData!['slot']}"; final Uri waUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(msg)}"); if (await canLaunchUrl(waUrl)) { await launchUrl(waUrl, mode: LaunchMode.externalApplication); } })),
                          ],
                        ),
                        SizedBox(height: context.scale(40)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }

  Widget _buildEmptyState(String message, ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.scale(32.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar_rounded, size: context.scale(30), color: theme.dividerColor.withOpacity(0.3)),
            SizedBox(height: context.scale(16)),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontWeight: FontWeight.w800, fontSize: context.scale(10), letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // 🧩 SLOTS & DATA HELPERS (Rest of logic remains the same)
  // ===========================================================================
  // ... (Keep your generation logic as is, but ensure Text style in _buildDynamicSlotSliver uses scale)

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(fontFamily: kDisplayFont, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: context.scale(10))),
          backgroundColor: isError ? Colors.redAccent : const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(12))),
        )
    );
  }

}