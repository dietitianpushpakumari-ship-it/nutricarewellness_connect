import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:nutricare_connect/features/auth/auth_provider.dart';

// ============================================================================
// 🎯 PROVIDER: SMART SORTED UNIFIED LIST
// ============================================================================
final clientAppointmentsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final clientProfile = ref.watch(authNotifierProvider).clientProfile;
  if (clientProfile == null) return Stream.value([]);

  final String userUid = FirebaseAuth.instance.currentUser?.uid ?? clientProfile.id;

  return FirebaseFirestore.instance
      .collection('appointments')
      .where('patientUid', isEqualTo: userUid)
      .snapshots()
      .map((snapshot) {
    final docs = snapshot.docs.map((doc) => doc.data()).toList();
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 🎯 SMART SORTING: Upcoming first (closest to today), Past last (newest to oldest)
    docs.sort((a, b) {
      final dateAStr = a['date']?.toString() ?? '2000-01-01';
      final dateBStr = b['date']?.toString() ?? '2000-01-01';

      bool isAUpcoming = dateAStr.compareTo(nowStr) >= 0;
      bool isBUpcoming = dateBStr.compareTo(nowStr) >= 0;

      if (isAUpcoming && !isBUpcoming) return -1; // A comes first
      if (!isAUpcoming && isBUpcoming) return 1;  // B comes first

      if (isAUpcoming && isBUpcoming) {
        // Both upcoming: sort ascending (closest to today is at the top)
        return dateAStr.compareTo(dateBStr);
      } else {
        // Both past: sort descending (most recent past is at the top)
        return dateBStr.compareTo(dateAStr);
      }
    });

    return docs;
  });
});

// ============================================================================
// 🎯 PREMIUM DIGITAL WALLET SCREEN (SINGLE VIEW)
// ============================================================================
class ClientWalletScreen extends ConsumerWidget {
  const ClientWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final appointmentsAsync = ref.watch(clientAppointmentsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text("My Wallet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: -0.5)),
      ),
      body: appointmentsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
        error: (e, s) => Center(child: Text("Error: $e")),
        data: (allAppointments) {

          if (allAppointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 80, color: theme.dividerColor.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text("No appointments found.", style: TextStyle(color: theme.hintColor, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: allAppointments.length,
            itemBuilder: (context, index) {
              final appt = allAppointments[index];
              return _WalletTicketCard(
                appointment: appt,
                onTap: () => _showFullSlip(context, appt, theme, colorScheme, isDark),
              );
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 🚀 FULL SCREEN SLIP VIEWER
  // ===========================================================================
  void _showFullSlip(BuildContext context, Map<String, dynamic> data, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.2), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Text("NUTRICARE CLINIC", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.primary, letterSpacing: 1)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 1)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("BOOKING REF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.hintColor, letterSpacing: 1)),
                              Text(data['bookingRef'] ?? 'N/A', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.primary)),
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
                      Text(data['slot'] ?? '', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1)),
                      Text(
                          DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(data['date'])),
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14)
                      ),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                        child: QrImageView(
                          data: data['bookingRef'] ?? "NO_REF",
                          version: QrVersions.auto,
                          size: 160.0,
                          gapless: false,
                          foregroundColor: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(data['patientName']?.toString().toUpperCase() ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                          "Dr. ${data['doctorName']} • ${data['department']}",
                          style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🎫 PREMIUM WALLET TICKET WIDGET (WITH STAMP LOGIC)
// ============================================================================
class _WalletTicketCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;

  const _WalletTicketCard({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final date = DateTime.parse(appointment['date']);
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 🎯 Status Logic
    final bool isCancelled = appointment['status'] == 'cancelled';
    final bool isPast = appointment['date'].compareTo(nowStr) < 0;

    // Determine the stamp details
    final bool showStamp = isCancelled || isPast;
    final String stampText = isCancelled ? "CANCELLED" : "COMPLETED";
    final Color stampColor = isCancelled ? Colors.redAccent : Colors.teal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: showStamp ? [] : [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: isCancelled ? Colors.redAccent.withOpacity(0.3) : theme.dividerColor.withOpacity(0.1)),
        ),
        child: Stack( // 🎯 Stack allows the Stamp to overlay the ticket
          children: [
            // --- ACTUAL TICKET CONTENT ---
            Row(
              children: [
                Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: isCancelled ? Colors.red.withOpacity(0.1) : (!isPast ? colorScheme.primary.withOpacity(0.1) : theme.dividerColor.withOpacity(0.05)),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCancelled ? Colors.red : (!isPast ? colorScheme.primary : theme.hintColor))),
                      Text(DateFormat('d').format(date), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isCancelled ? Colors.red : colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8)),
                        child: Text(appointment['slot'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1, height: 100,
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.dividerColor.withOpacity(0.2), width: 1, style: BorderStyle.none))),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Ref: ${appointment['bookingRef']}", style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text("Dr. ${appointment['doctorName']}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(appointment['department'] ?? 'General', style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                          child: QrImageView(
                            data: appointment['bookingRef'] ?? 'empty',
                            version: QrVersions.auto,
                            size: 40.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 🎯 THE "STAMP" OVERLAY
            if (showStamp)
              Positioned.fill(
                child: IgnorePointer( // Prevents stamp from blocking taps
                  child: Container(
                    // 🎯 Fades the ticket slightly so the stamp pops
                    decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20)
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: -math.pi / 12, // Angled slightly like a real hand stamp
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: stampColor, width: 3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stampText,
                            style: TextStyle(
                              color: stampColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}