import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/booking_sheet.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/new/utils/easy_localization.dart';
import 'package:nutricare_connect/new/coach/package_browser_screen.dart';
import 'package:nutricare_connect/core/utils/package_payment_status_card.dart';
import 'package:nutricare_connect/core/utils/dietitian_business_card.dart';
import 'package:nutricare_connect/new/chat/client_chat_screen.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/features/appointments/schedule_meeting_utils.dart';
import 'package:nutricare_connect/new/service/client_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CoachTab extends ConsumerWidget {
  final ClientModel client;
  const CoachTab({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎨 Theme Extraction
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dietitianAsync = ref.watch(dietitianProfileProvider);
    final meetingsAsync = ref.watch(upcomingMeetingsProvider(client.id));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 🎨 Themed Background
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 🎯 1. PREMIUM HEADER WITH THEME & PROFILE BUTTONS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "My Care Team",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),

                    // 🎯 SLEEK ACTION PILL (Replaces Home Screen AppBar buttons)
                    // 🎯 SLEEK ACTION PILL
                    Container(
                      decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🎯 1. LANGUAGE SELECTOR
                          IconButton(
                            icon: Icon(Icons.language_rounded, color: colorScheme.primary, size: 20),
                            tooltip: 'App Language',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent, // Required for the glass blur to work
                                isScrollControlled: true,
                                builder: (_) => const PremiumLanguageSheet(),
                              );
                            },
                          ),
                          Container(width: 1, height: 20, color: theme.dividerColor.withOpacity(0.2)),

                          // 🎯 2. PROFILE SETTINGS
                          IconButton(
                            icon: Icon(Icons.account_circle_rounded, color: colorScheme.primary, size: 20),
                            tooltip: 'Client Profile',
                            onPressed: () {
                              // ScaffoldMessenger.of(context)...
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🎯 2. DIGITAL BUSINESS CARD
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: dietitianAsync.when(
                  loading: () => Center(child: LinearProgressIndicator(minHeight: 2, color: colorScheme.primary)),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();
                    return DietitianBusinessCard(
                      profile: profile,
                      onShare: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text("Sharing Profile Card via WhatsApp..."), backgroundColor: colorScheme.primary)
                        );
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
                    child: _buildNextSessionBanner(context, meetings.first, theme, colorScheme, isDark),
                  );
                },
              ),
            ),

            // 4. MEMBERSHIP SECTION
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text("My Plan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
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
                    context, "Chat Coach", Icons.chat_bubble_outline_rounded, colorScheme.primary, theme, colorScheme, isDark,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen(clientName: client.name ?? 'Client'))),
                  ),
                  _buildCompactActionCard(
                    context, "Explore Plans", Icons.storefront_rounded, isDark ? Colors.orangeAccent : Colors.orange, theme, colorScheme, isDark,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackageBrowserScreen())),
                  ),
                  _buildCompactActionCard(
                    context, "Payments", Icons.payment_rounded, isDark ? Colors.greenAccent : Colors.green, theme, colorScheme, isDark,
                        () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => const PaymentModesSheet()),
                  ),
                ],
              ),
            ),

            // 6. COMMUNITY (SOCIAL LINKS)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text("Join the Tribe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    const SizedBox(height: 10),
                    _buildSocialsCard(context, theme, colorScheme, isDark),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildNextSessionBanner(BuildContext context, MeetingModel meeting, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHighest : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? theme.dividerColor.withOpacity(0.5) : Colors.orange.shade200)
      ),
      child: Row(
        children: [
          Icon(Icons.video_call_rounded, color: isDark ? Colors.deepOrangeAccent : Colors.deepOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Upcoming: ${meeting.purpose}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
                    Text(DateFormat("MMM d, h:mm a").format(meeting.startTime), style: TextStyle(color: theme.hintColor, fontSize: 12))
                  ]
              )
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.orangeAccent : Colors.orange),
        ],
      ),
    );
  }

  Widget _buildCompactActionCard(BuildContext context, String title, IconData icon, Color color, ThemeData theme, ColorScheme colorScheme, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 6, offset: const Offset(0, 2))],
            border: Border.all(color: theme.dividerColor.withOpacity(0.2))
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20)
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 PRIORITY APP LAUNCHER ASSIGNMENTS
  Widget _buildSocialsCard(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10)]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSocialBtn(
              icon: FontAwesomeIcons.globe,
              label: "Web",
              color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey,
              theme: theme,
              onTap: () => SocialLauncher.openWeb("https://nutricarewellness.com")
          ),
          _buildSocialBtn(
              icon: FontAwesomeIcons.instagram,
              label: "Insta",
              color: isDark ? Colors.pinkAccent : Colors.pink,
              theme: theme,
              onTap: () => SocialLauncher.openWeb("https://instagram.com")
          ),
          _buildSocialBtn(
              icon: FontAwesomeIcons.facebook,
              label: "Facebook",
              color: isDark ? Colors.lightBlueAccent : Colors.blue,
              theme: theme,
              onTap: () => SocialLauncher.openFacebook("NutricareWellness.rkl") // 🎯 Native Priority
          ),
          _buildSocialBtn(
              icon: FontAwesomeIcons.youtube,
              label: "YouTube",
              color: isDark ? Colors.redAccent : Colors.red,
              theme: theme,
              onTap: () => SocialLauncher.openYouTube("@NutricareWellness-t2s") // 🎯 Native Priority
          ),
        ],
      ),
    );
  }

  Widget _buildSocialBtn({required IconData icon, required String label, required Color color, required ThemeData theme, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w500))
          ]
      ),
    );
  }
}

// =================================================================
// 🎯 SMART SOCIAL LAUNCHER HELPER
// =================================================================
class SocialLauncher {
  static Future<void> openFacebook(String handle) async {
    final String protocolUrl = "fb://facewebmodal/f?href=https://www.facebook.com/$handle";
    final String webUrl = "https://www.facebook.com/$handle";
    try {
      bool launched = await launchUrl(Uri.parse(protocolUrl), mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openYouTube(String channelHandle) async {
    final String protocolUrl = "youtube://www.youtube.com/$channelHandle";
    final String webUrl = "https://www.youtube.com/$channelHandle";
    try {
      bool launched = await launchUrl(Uri.parse(protocolUrl), mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openWeb(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url");
    }
  }
}

// 🎯 THEMED PAYMENT SHEET
class PaymentModesSheet extends StatelessWidget {
  const PaymentModesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1))
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2))
              )
          ),
          const SizedBox(height: 20),
          Text("Select Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 10),
          _payTile(Icons.qr_code_rounded, "UPI / GPay / PhonePe", () {}, colorScheme, theme),
          _payTile(Icons.credit_card_rounded, "Credit / Debit Card", () {}, colorScheme, theme),
          _payTile(Icons.account_balance_rounded, "Net Banking", () {}, colorScheme, theme),
          Divider(color: theme.dividerColor.withOpacity(0.2)),
          _payTile(Icons.support_agent_rounded, "Contact Support", () {}, colorScheme, theme),
        ],
      ),
    );
  }

  Widget _payTile(IconData icon, String label, VoidCallback onTap, ColorScheme colorScheme, ThemeData theme) {
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary, size: 20),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface)),
      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: theme.iconTheme.color?.withOpacity(0.5)),
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}