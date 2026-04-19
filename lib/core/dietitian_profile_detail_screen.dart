import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pure_shift/features/profile/client_reminder_setting_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pure_shift/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/new/utils/utils.dart';
// 🚀 ADDED: Import your internal chat screen
import 'package:pure_shift/new/chat/client_chat_screen.dart';

// 🎯 GLOBAL FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class DietitianProfileDetailScreen extends ConsumerWidget {
  final AdminProfileModel profile;

  const DietitianProfileDetailScreen({super.key, required this.profile});

  Future<void> _launch(String url, BuildContext context) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch $url. Please check your apps.", style: const TextStyle(fontFamily: kBodyFont, fontSize: 12))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final tenantState = ref.watch(tenantDetailsProvider(profile.tenantId));

    String liveCompanyName = profile.companyName.isNotEmpty ? profile.companyName : "Independent Practitioner";
    String liveWebsite = "";

    if (tenantState is AsyncData && tenantState.value != null) {
      final tenantData = tenantState.value!;
      liveCompanyName = tenantData['name'] ?? tenantData['companyName'] ?? liveCompanyName;
      liveWebsite = tenantData['website'] ?? liveWebsite;
    }

    final String safeRegNo = profile.regdNo ?? '';
    final String safeAddress = profile.address ?? '';
    final String displayEmail = profile.companyEmail.isNotEmpty ? profile.companyEmail : profile.email;
    final String displayPhone = profile.mobile;
    final List<String> specs = profile.specializations.isNotEmpty
        ? profile.specializations
        : ["Clinical Nutrition", "Metabolic Health", "Lifestyle Modification"];

    final String titleStr = profile.title != null && profile.title!.isNotEmpty ? "${profile.title} " : "";
    final String fullName = "$titleStr${profile.firstName} ${profile.lastName}".trim();
    final String quals = profile.qualifications.isNotEmpty ? profile.qualifications.join(", ") : "";
    final String philosophy = profile.aboutMe?.trim() ?? "";

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Ambient Background Glow
          Positioned(
              top: -100, right: -100,
              child: Container(
                  width: 400, height: 400,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08), blurRadius: 100, spreadRadius: 40)
                      ]
                  )
              )
          ),

          SafeArea(
            top: false,
            bottom: true,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 2. HERO HEADER & QUICK ACTIONS
                SliverAppBar(
                  expandedHeight: 400, // 🚀 FIX 1: Increased from 380 to 400 for better breathing room
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      children: [
                        // A. Gradient Cover (Stops 45px before the bottom so buttons can float)
                        Positioned(
                          top: 0, left: 0, right: 0, bottom: 45,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF1A237E), const Color(0xFF0D1117)]
                                    : [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                        Positioned(top: -50, right: -50, child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),
                        Positioned(bottom: 30, left: -20, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),

                        // B. Center Avatar & Details
                        Positioned(
                          top: 50, left: 0, right: 0,
                          bottom: 120, // 🚀 FIX 2: Increased from 80 to 120 to guarantee a vertical gap!
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Glowing Avatar Ring
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: theme.cardColor,
                                  backgroundImage: profile.photoUrl.isNotEmpty ? NetworkImage(profile.photoUrl) : null,
                                  child: profile.photoUrl.isEmpty
                                      ? Text(profile.firstName.isNotEmpty ? profile.firstName[0].toUpperCase() : "C", style: TextStyle(fontFamily: kDisplayFont, fontSize: 36, fontWeight: FontWeight.bold, color: colorScheme.primary))
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // NAME
                              Text(
                                  fullName,
                                  style: const TextStyle(fontFamily: kDisplayFont, fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)
                              ),

                              // QUALIFICATIONS
                              if (quals.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(quals, style: TextStyle(fontFamily: kBodyFont, color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],

                              const SizedBox(height: 10),

                              // DESIGNATION
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                    profile.designation.isNotEmpty ? profile.designation.capitalize() : "Clinical Dietitian",
                                    style: const TextStyle(fontFamily: kDisplayFont, fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.0)
                                ),
                              ),
                            ],
                          ),
                        ),

                        // C. 🚀 OVERLAPPING QUICK ACTIONS ROW
                        Positioned(
                          bottom: 0, left: 24, right: 24,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildFloatingActionBtn(Icons.phone_rounded, "Call", Colors.blue, theme, isDark, () => _launch("tel:$displayPhone", context)),
                              _buildFloatingActionBtn(Icons.chat_bubble_rounded, "Chat", Colors.green, theme, isDark, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen()));
                              }),
                              _buildFloatingActionBtn(Icons.email_rounded, "Email", Colors.orange, theme, isDark, () => _launch("mailto:$displayEmail", context)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. MAIN CONTENT
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40), // Added 24px top padding to space out from the buttons
                    child: Column(
// ... (The rest of your code continues normally here)
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A. THE PHILOSOPHY / ABOUT ME
                        if (philosophy.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(FontAwesomeIcons.quoteLeft, size: 20, color: colorScheme.primary.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                    philosophy,
                                    style: TextStyle(
                                        fontFamily: kBodyFont,
                                        fontSize: 12,
                                        height: 1.6,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w500
                                    )
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // B. Professional Details
                        _buildSectionTitle("Professional Details", theme),
                        _buildPremiumCard(
                            theme, isDark,
                            [
                              _buildInfoRow(Icons.business_rounded, "Clinic / Company", liveCompanyName.capitalize(), theme),

                              if (liveWebsite.isNotEmpty) ...[
                                Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
                                GestureDetector(
                                  onTap: () {
                                    final url = liveWebsite.startsWith('http') ? liveWebsite : 'https://$liveWebsite';
                                    _launch(url, context);
                                  },
                                  child: _buildInfoRow(Icons.language_rounded, "Website", liveWebsite.replaceFirst('https://', '').replaceFirst('http://', ''), theme, isLink: true),
                                ),
                              ],

                              if (safeRegNo.isNotEmpty) ...[
                                Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
                                _buildInfoRow(Icons.verified_user_rounded, "Registration No.", safeRegNo, theme),
                              ],
                            ]
                        ),
                        const SizedBox(height: 32),

                        // C. Areas of Expertise
                        _buildSectionTitle("Areas of Expertise", theme),
                        _buildPremiumCard(
                            theme, isDark,
                            [
                              Wrap(
                                spacing: 8,
                                runSpacing: 12,
                                children: specs.map((spec) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                      spec.capitalize(),
                                      style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 9)
                                  ),
                                )).toList(),
                              ),
                            ]
                        ),
                        const SizedBox(height: 32),

                        // D. Clinic Location
                        if (safeAddress.isNotEmpty) ...[
                          _buildSectionTitle("Clinic Location", theme),
                          _buildPremiumCard(
                              theme, isDark,
                              [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Primary Address", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(safeAddress, style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface, height: 1.5)),
                                        ],
                                      ),
                                    )
                                  ],
                                )
                              ]
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- COMPONENT BUILDERS ---

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 4),
        child: Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface, letterSpacing: -0.5))
    );
  }

  Widget _buildPremiumCard(ThemeData theme, bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, 8))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ThemeData theme, {bool isLink = false}) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        value,
                        style: TextStyle(
                            fontFamily: kBodyFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isLink ? Colors.blue : theme.colorScheme.onSurface,
                            decoration: isLink ? TextDecoration.underline : TextDecoration.none
                        )
                    ),
                  ]
              )
          )
        ]
    );
  }

  Widget _buildFloatingActionBtn(IconData icon, String label, Color color, ThemeData theme, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.08), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: FaIcon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}