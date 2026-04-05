import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
// Adjust this import path to your actual project structure
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';

class DietitianProfileDetailScreen extends StatelessWidget {
  final AdminProfileModel profile;

  const DietitianProfileDetailScreen({super.key, required this.profile});

  Future<void> _launch(String url, BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch action. Please check the contact details.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🚀 SAFE VARIABLE EXTRACTION (Fixes the Null Crashes)
    final String safeRegNo = profile.regdNo ?? '';
    final String safeAddress = profile.address ?? '';
    final String displayEmail = profile.companyEmail.isNotEmpty ? profile.companyEmail : profile.email;
    final List<String> specs = profile.specializations.isNotEmpty
        ? profile.specializations
        : ["Clinical Nutrition", "Metabolic Health", "Lifestyle Modification"];

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

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 2. HERO HEADER (Premium Gradient + Avatar)
              SliverAppBar(
                expandedHeight: 300,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient Cover
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1A237E), const Color(0xFF0D1117)]
                                : [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Decorative Overlays
                      Positioned(top: -50, right: -50, child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),
                      Positioned(bottom: -20, left: -20, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),

                      // Center Avatar & Details
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 30),
                            // Glowing Avatar Ring
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: theme.cardColor,
                                backgroundImage: profile.photoUrl.isNotEmpty ? NetworkImage(profile.photoUrl) : null,
                                child: profile.photoUrl.isEmpty
                                    ? Text(profile.firstName.isNotEmpty ? profile.firstName[0] : "C", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: colorScheme.primary))
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                                profile.fullName,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                  profile.designation.isNotEmpty ? profile.designation : "Clinical Dietitian",
                                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1.0)
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. QUICK ACTIONS ROW (Floating below header)
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28), // Pulls the row up slightly into the header
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFloatingActionBtn(Icons.phone_rounded, "Call", Colors.blue, theme, isDark, () => _launch("tel:${profile.mobile}", context)),
                        _buildFloatingActionBtn(FontAwesomeIcons.whatsapp, "WhatsApp", Colors.green, theme, isDark, () => _launch("https://wa.me/${profile.mobile}", context)),
                        _buildFloatingActionBtn(Icons.email_rounded, "Email", Colors.orange, theme, isDark, () => _launch("mailto:$displayEmail", context)),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. MAIN CONTENT
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A. Professional Profile
                      _buildSectionTitle("Professional Profile", theme),
                      _buildPremiumCard(
                          theme, isDark,
                          [
                            _buildInfoRow(Icons.business_rounded, "Clinic / Company", profile.companyName.isNotEmpty ? profile.companyName : "Independent Practitioner", theme),
                            if (safeRegNo.isNotEmpty) ...[
                              Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
                              _buildInfoRow(Icons.verified_user_rounded, "Registration No.", safeRegNo, theme),
                            ],
                            Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
                            Text(
                                "Experienced clinical professional specializing in metabolic health and personalized nutrition strategies. Dedicated to transforming lives through science-backed dietary interventions.",
                                style: TextStyle(height: 1.6, color: theme.hintColor, fontSize: 14)
                            ),
                          ]
                      ),
                      const SizedBox(height: 32),

                      // B. Areas of Expertise
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
                                    spec,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 13)
                                ),
                              )).toList(),
                            ),
                          ]
                      ),
                      const SizedBox(height: 32),

                      // C. Clinic Location (Only shows if address exists)
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
                                        Text("Primary Address", style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(safeAddress, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface, height: 1.5)),
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
          )
        ],
      ),
    );
  }

  // --- COMPONENT BUILDERS ---

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 4),
        child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -0.5))
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

  Widget _buildInfoRow(IconData icon, String label, String value, ThemeData theme) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  ]
              )
          )
        ]
    );
  }

  // Floating Action Button for the quick actions row
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
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}