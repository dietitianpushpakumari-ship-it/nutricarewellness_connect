import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pure_shift/core/utils/clinical_services_sheet.dart';

import 'package:pure_shift/core/utils/pdf_viewer_screen.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/booking/client_booking_screen.dart';
import 'package:pure_shift/new/booking/client_wallet_screen.dart';
import 'package:pure_shift/new/chat/client_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/core/utils/package_payment_status_card.dart';
import 'package:pure_shift/core/utils/dietitian_business_card.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/appointments/schedule_meeting_utils.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class CoachTab extends ConsumerWidget {
  final ClientModel client;
  const CoachTab({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dietitianAsync = ref.watch(dietitianProfileProvider(client.coachId ?? ''));
    final meetingsAsync = ref.watch(upcomingMeetingsProvider(client.id));

    // 🚀 We use a Stack to manually position the FAB exactly where we want it,
    // immune to any bottom navigation bar interference.
    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            top: true,
            bottom: true,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. 🛰️ PREMIUM HEADER
                SliverToBoxAdapter(
                  child: _buildTopHeader(context, theme, colorScheme, isDark),
                ),

                // 2. 🪪 DIGITAL BUSINESS CARD
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(20), vertical: context.scale(8)),
                    child: dietitianAsync.when(
                      loading: () => Padding(
                        padding: EdgeInsets.all(context.scale(20)),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (profile) => profile == null
                          ? const SizedBox.shrink()
                          : DietitianBusinessCard(profile: profile),
                    ),
                  ),
                ),

                // 3. 📅 UPCOMING SESSIONS BANNER
                SliverToBoxAdapter(
                  child: meetingsAsync.maybeWhen(
                    data: (meetings) => meetings.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                      padding: EdgeInsets.fromLTRB(context.scale(20), context.scale(16), context.scale(20), context.scale(24)),
                      child: _buildUpcomingSessionAlert(context, meetings.first, theme, colorScheme, isDark),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),

                // 4. 💼 BOOKINGS & WALLET
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: context.scale(8)),
                      _buildSectionLabel(context, "BOOKINGS & WALLET", theme),
                      _buildBookingWalletRow(context, theme, colorScheme, isDark),
                      SizedBox(height: context.scale(24)),
                    ],
                  ),
                ),

                // 5. 🛡️ MEMBERSHIP HUB
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (meetingsAsync.value == null || meetingsAsync.value!.isEmpty)
                        SizedBox(height: context.scale(16)),

                      _buildSectionLabel(context, "ACTIVE MEMBERSHIP", theme),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: context.scale(20)),
                        child: PackagePaymentStatusCard(clientId: client.id),
                      ),
                    ],
                  ),
                ),

                // 6. 🏥 PREMIUM SERVICES TRIGGER
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: context.scale(32)),
                      _buildSectionLabel(context, "CLINICAL PROGRAMS", theme),
                      _buildPremiumServicesLink(context, theme, colorScheme, isDark),
                    ],
                  ),
                ),

                // 7. 📄 IN-APP PDF VIEWER BUTTON
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(height: context.scale(16)),
                      _buildMiniExploreBar(context, theme, colorScheme, isDark),
                    ],
                  ),
                ),

                // Extra padding so the user can scroll past the floating button
                SliverPadding(padding: EdgeInsets.only(bottom: context.scale(120))),
              ],
            ),
          ),
        ),

        // 🚀 THE PERMANENTLY FIXED FLOATING ACTION BUTTON
        Positioned(
          right: 16,
          // This mathematically calculates the perfect distance above the physical screen bottom
          // 80 is the height of your custom bottom nav bar. MediaQuery handles the hardware bezel.
          bottom: MediaQuery.paddingOf(context).bottom + 80,
          child: FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientChatScreen()),
              );
            },
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 8, // Slightly higher elevation so it floats clearly above content
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text(
              "Message Coach",
              style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 🛠️ MODERN CLINICAL UI COMPONENTS
  // =========================================================================

  Widget _buildQuoteBanner(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      margin: EdgeInsets.fromLTRB(context.scale(20), 0, context.scale(20), context.scale(20)),
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.primary.withOpacity(0.05) : colorScheme.primary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(context.scale(16)),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: colorScheme.primary.withOpacity(0.5), size: context.scale(24)),
          SizedBox(width: context.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Let food be thy medicine, and medicine be thy food.",
                  style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12), fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                SizedBox(height: context.scale(4)),
                Text(
                  "— Hippocrates (Food is a Treatment)",
                  style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(10), color: theme.hintColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingWalletRow(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.scale(20)),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              context,
              title: "Book Session",
              subtitle: "Schedule 1-on-1",
              icon: Icons.calendar_month_rounded,
              color: colorScheme.primary,
              theme: theme,
              isDark: isDark,
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => ClientBookingScreen(
                  tenantId: client.tenantId ?? 'nutricare',
                  initialCoachId: client.coachId,
                )));
              },
            ),
          ),
          SizedBox(width: context.scale(12)),
          Expanded(
            child: _buildActionCard(
              context,
              title: "My Wallet",
              subtitle: "Manage funds",
              icon: Icons.account_balance_wallet_rounded,
              color: isDark ? Colors.tealAccent : Colors.teal,
              theme: theme,
              isDark: isDark,
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientWalletScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap, required ThemeData theme, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.scale(16)),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(context.scale(16)),
            border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: context.scale(10), offset: Offset(0, context.scale(4)))
            ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(8)),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: context.scale(20)),
            ),
            SizedBox(height: context.scale(16)),
            Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(12), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            SizedBox(height: context.scale(2)),
            Text(subtitle, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(10), color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(20), context.scale(24), context.scale(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("CLINICAL TEAM",
                  style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: context.scale(1.5), color: theme.hintColor.withOpacity(0.5))),
              SizedBox(height: context.scale(2)),
              Text("My Care Team",
                  style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(20), fontWeight: FontWeight.w700, color: colorScheme.onSurface, letterSpacing: context.scale(-0.5))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.scale(24), 0, context.scale(24), context.scale(12)),
      child: Text(label,
          style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: context.scale(1.5), color: theme.hintColor.withOpacity(0.5))),
    );
  }

  Widget _buildUpcomingSessionAlert(BuildContext context, dynamic meeting, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final alertColor = isDark ? Colors.orangeAccent : Colors.orange.shade700;

    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
          color: alertColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(context.scale(20)),
          border: Border.all(color: alertColor.withOpacity(0.2))
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.scale(10)),
            decoration: BoxDecoration(color: alertColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.videocam_rounded, color: alertColor, size: context.scale(18)),
          ),
          SizedBox(width: context.scale(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("UPCOMING TELEHEALTH",
                    style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), fontWeight: FontWeight.w700, letterSpacing: context.scale(1.0), color: alertColor)),
                SizedBox(height: context.scale(2)),
                Text(meeting.purpose,
                    style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: context.scale(13), color: colorScheme.onSurface, letterSpacing: context.scale(-0.2))),
                SizedBox(height: context.scale(2)),
                Text(DateFormat("EEEE, MMM d • h:mm a").format(meeting.startTime),
                    style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(11), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: context.scale(12), color: alertColor.withOpacity(0.4)),
        ],
      ),
    );
  }


  // =========================================================================
  // 🚀 IN-APP PDF LAUNCHER WITH BROWSER FALLBACK
  // =========================================================================
  Widget _buildMiniExploreBar(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: () => _openPricingPdf(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: context.scale(20)),
        padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(12)),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : theme.dividerColor.withOpacity(0.03),
          borderRadius: BorderRadius.circular(context.scale(16)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: context.scale(16), color: colorScheme.primary),
            SizedBox(width: context.scale(10)),
            Text("VIEW PRICING CHART PDF",
                style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: context.scale(1.0), color: colorScheme.primary)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: context.scale(10), color: theme.hintColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  void _openPricingPdf(BuildContext context) {
    HapticFeedback.lightImpact();

    const String pdfUrl = "https://nutricarewellness.com/assets/nutricare_price_chart.pdf";

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PdfViewerScreen(
            pdfUrl: pdfUrl,
            title: "Pricing & Packages",
          ),
        ),
      );
    } catch (e) {
      debugPrint("Failed to launch PDF viewer, falling back to browser: $e");
      _launchExternalUrl(context, 'https://nutricarewellness.com/price-model');
    }
  }
  Widget _buildPremiumServicesLink(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const ClinicalServicesSheet(),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: context.scale(20)),
        padding: EdgeInsets.all(context.scale(20)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [colorScheme.primary.withOpacity(0.15), Colors.black26]
                : [colorScheme.primary.withOpacity(0.08), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(context.scale(20)),
          border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05), blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(12)),
              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              child: Icon(Icons.medical_services_rounded, color: colorScheme.onPrimary, size: context.scale(24)),
            ),
            SizedBox(width: context.scale(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Explore Clinical Services", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                  SizedBox(height: context.scale(4)),
                  Text("View all 14 specialized therapeutic programs.", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), color: theme.hintColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.primary, size: context.scale(14)),
          ],
        ),
      ),
    );
  }
  Future<void> _launchExternalUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open browser.', style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12))),
                backgroundColor: Theme.of(context).colorScheme.error,
              )
          );
        }
      }
    } catch (e) {
      debugPrint("URL Launch Error: $e");
    }
  }
}