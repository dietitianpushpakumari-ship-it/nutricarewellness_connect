import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// 🎯 Replace these imports with your actual paths
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/coach/package_browser_screen.dart';
import 'package:nutricare_connect/core/utils/package_payment_status_card.dart';
import 'package:nutricare_connect/core/utils/dietitian_business_card.dart';
import 'package:nutricare_connect/new/chat/client_chat_screen.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/appointments/schedule_meeting_utils.dart';

class CoachTab extends ConsumerWidget {
  final ClientModel client;
  const CoachTab({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

// 🚀 THE FIX: Pass the client object so the provider can check the coachId and tenantId
    // 🚀 THE FIX: Pass just the String ID to prevent Riverpod infinite rebuild loops
    final dietitianAsync = ref.watch(dietitianProfileProvider(client.coachId ?? ''));
    final meetingsAsync = ref.watch(upcomingMeetingsProvider(client.id));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. PREMIUM HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("My Care Team", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: -0.5)),
                    Container(
                      decoration: BoxDecoration(
                          color: theme.cardColor, borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: Icon(Icons.language_rounded, color: colorScheme.primary, size: 20), onPressed: () {}),
                          Container(width: 1, height: 20, color: theme.dividerColor.withOpacity(0.2)),
                          IconButton(icon: Icon(Icons.account_circle_rounded, color: colorScheme.primary, size: 20), onPressed: () {}),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. DIGITAL BUSINESS CARD
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: dietitianAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) => profile == null ? const SizedBox.shrink() : DietitianBusinessCard(profile: profile, onShare: () {}),
                ),
              ),
            ),

            // 3. EXPERTISE SHOWCASE
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Text("Areas of Expertise", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 1.2)),
                  ),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (context, i) {
                        final expertises = ["Weight Loss", "Gut Health", "PCOS/PCOD", "Diabetes", "Thyroid"];
                        return Container(
                          margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withOpacity(0.2))),
                          alignment: Alignment.center,
                          child: Text(expertises[i], style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 4. UPCOMING SESSION
            SliverToBoxAdapter(
              child: meetingsAsync.maybeWhen(
                data: (meetings) => meetings.isEmpty ? const SizedBox.shrink() : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: isDark ? colorScheme.surfaceContainerHighest : Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? theme.dividerColor.withOpacity(0.5) : Colors.orange.shade200)),
                    child: Row(
                      children: [
                        Icon(Icons.video_call_rounded, color: isDark ? Colors.deepOrangeAccent : Colors.deepOrange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("Upcoming: ${meetings.first.purpose}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
                          Text(DateFormat("MMM d, h:mm a").format(meetings.first.startTime), style: TextStyle(color: theme.hintColor, fontSize: 12))
                        ])),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.orangeAccent : Colors.orange),
                      ],
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),

            // 5. MEMBERSHIP & PAYMENT HUB
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Membership Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    TextButton(
                      onPressed: () => _showDetailedBillingSheet(context, client.id),
                      child: Text("View Billing", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PackagePaymentStatusCard(clientId: client.id),
              ),
            ),

            // 6. EXPLORE PACKAGES
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                    child: Text("Clinical Programs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  ),
                  SizedBox(
                    height: 160,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _packagePreviewCard("Standard Care", "3 Months • Holistic Coaching", "₹12,000", Colors.blue, isDark),
                        _packagePreviewCard("Metabolic Reset", "6 Months • Intensive", "₹22,000", Colors.orange, isDark),
                        _packagePreviewCard("Elite Premium", "12 Months • Personal Chef", "₹40,000", colorScheme.primary, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 7. QUICK ACTIONS
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5,
                children: [
                  _buildCompactActionCard(context, "Chat Coach", Icons.chat_bubble_outline_rounded, colorScheme.primary, theme, colorScheme, isDark,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen(clientName: client.name ?? 'Coach')))),
                  _buildCompactActionCard(context, "Help Center", Icons.support_agent_rounded, Colors.blue, theme, colorScheme, isDark, () {}),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _packagePreviewCard(String title, String desc, String price, Color accent, bool isDark) {
    return Container(
      width: 240, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2632) : Colors.white,
        borderRadius: BorderRadius.circular(24), border: Border.all(color: accent.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 10)),
          ),
          const Spacer(),
          Text(desc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCompactActionCard(BuildContext context, String title, IconData icon, Color color, ThemeData theme, ColorScheme colorScheme, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 6, offset: const Offset(0, 2))], border: Border.all(color: theme.dividerColor.withOpacity(0.2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  void _showDetailedBillingSheet(BuildContext context, String clientId) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => _PackageDetailSheet(clientId: clientId),
    );
  }
}

// 🎯 The Billing Bottom Sheet
class _PackageDetailSheet extends ConsumerWidget {
  final String clientId;
  const _PackageDetailSheet({required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text("Plan Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                const SizedBox(height: 20),

                Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Row(children: [Icon(Icons.auto_awesome_rounded, size: 18, color: colorScheme.primary), const SizedBox(width: 8), const Text("What's Included", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                  child: Column(
                    children: [
                      _benefitTile(Icons.check_circle_outline, "Custom Diet Charts", theme),
                      _benefitTile(Icons.check_circle_outline, "Weekly Video Consultations", theme),
                      _benefitTile(Icons.check_circle_outline, "24/7 Priority Chat Support", theme),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Row(children: [Icon(Icons.account_balance_wallet_rounded, size: 18, color: colorScheme.primary), const SizedBox(width: 8), const Text("Payment Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                  child: Column(
                    children: [
                      _paymentInfoRow("Package Price", "₹12,000", theme, false),
                      _paymentInfoRow("Discount Applied", "- ₹2,000", theme, true),
                      const Divider(height: 32),
                      _paymentInfoRow("Total Paid", "₹10,000", theme, false, isTotal: true),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_rounded, color: Colors.green, size: 14), SizedBox(width: 6), Text("FULLY PAID", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1))]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {}, icon: const Icon(Icons.file_download_outlined), label: const Text("Download Last Invoice"),
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitTile(IconData icon, String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [Icon(icon, color: Colors.green, size: 20), const SizedBox(width: 12), Text(label, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500))]),
    );
  }

  Widget _paymentInfoRow(String label, String value, ThemeData theme, bool isDiscount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor, fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold, fontSize: isTotal ? 18 : 14, color: isDiscount ? Colors.green : theme.colorScheme.onSurface)),
        ],
      ),
    );
  }
}