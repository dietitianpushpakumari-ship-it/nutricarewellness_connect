import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:url_launcher/url_launcher.dart';

class DietitianBusinessCard extends StatelessWidget {
  final AdminProfileModel profile;
  final VoidCallback onShare;

  const DietitianBusinessCard({
    super.key,
    required this.profile,
    required this.onShare
  });

  @override
  Widget build(BuildContext context) {
    // Mock data if empty
    final specs = profile.specializations.isNotEmpty
        ? profile.specializations
        : ["Weight Loss", "Diabetes Reversal", "PCOS", "Sports Nutrition"];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // 🎯 SHARP SHADOW: Gives it a "floating" feel without blurriness
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A00E0).withOpacity(0.6),
            blurRadius: 3,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. VIBRANT BACKGROUND (Royal Blue -> Purple)
            // Replaces the "Murky Dark" gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4A00E0), // Vibrant Violet
                    Color(0xFF8E2DE2), // Rich Purple
                  ],
                ),
              ),
            ),

            // 2. GEOMETRIC ACCENTS (Crisp White Circles)
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 20),
                ),
              ),
            ),
            Positioned(
              bottom: -20, left: -20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // 3. CONTENT
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with Solid White Ring
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white,
                          backgroundImage: profile.photoUrl.isNotEmpty
                              ? NetworkImage(profile.photoUrl)
                              : null,
                          child: profile.photoUrl.isEmpty
                              ? Text(profile.firstName[0], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF4A00E0)))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Name & Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company (Gold for contrast)
                            if (profile.companyName.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  profile.companyName.toUpperCase(),
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),

                            Text(
                              "${profile.firstName} ${profile.lastName}",
                              style: const TextStyle(
                                color: Colors.white, // 🎯 Solid White
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.designation.isNotEmpty ? profile.designation : "Senior Dietitian",
                              style: const TextStyle(
                                color: Colors.white, // 🎯 Solid White (was grey)
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Divider(color: Colors.white.withOpacity(0.2), height: 1),
                  const SizedBox(height: 16),

                  // --- EXPERTISE CHIPS ---
                  const Text(
                      "SPECIALIZATIONS",
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: specs.take(4).map((spec) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white, // 🎯 Solid White Chip
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          spec,
                          style: const TextStyle(
                              color: Color(0xFF4A00E0), // Colored Text
                              fontSize: 11,
                              fontWeight: FontWeight.w700
                          )
                      ),
                    )).toList(),
                  ),

                  const SizedBox(height: 28),

                  // --- FOOTER ACTIONS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Contact Row (White Icons)
                      Row(
                        children: [
                          _buildActionIcon(FontAwesomeIcons.whatsapp, () => _launch("https://wa.me/${profile.mobile}")),
                          const SizedBox(width: 12),
                          _buildActionIcon(Icons.call_rounded, () => _launch("tel:${profile.mobile}")),
                          const SizedBox(width: 12),
                          _buildActionIcon(Icons.email_rounded, () => _launch("mailto:${profile.companyEmail}")),
                        ],
                      ),

                      // 🎯 SHARE BUTTON (High Visibility)
                      ElevatedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text("Share Card"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber, // Gold Button
                          foregroundColor: const Color(0xFF4A00E0), // Dark Text
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }
}