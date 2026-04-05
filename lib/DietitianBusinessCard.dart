import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DietitianBusinessCard extends StatelessWidget {
  final dynamic profile; // Replace with your AdminProfileModel
  final VoidCallback onShare;

  // 🚀 Key for capturing the card as an image
  final GlobalKey _cardKey = GlobalKey();

  DietitianBusinessCard({super.key, required this.profile, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final neonGreen = const Color(0xFF00E676);

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          // 🚀 PREMIUM 3D SHADOW
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // 1. DYNAMIC BACKGROUND
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1A237E), const Color(0xFF0D1117)]
                          : [const Color(0xFFF8F9FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // 2. DECORATIVE BLOOM (Spiritual/Wellness essence)
              Positioned(
                top: -50, right: -50,
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    color: neonGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 3. MAIN CONTENT
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PROFILE AVATAR WITH GLOW
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: neonGreen, width: 2),
                            boxShadow: [BoxShadow(color: neonGreen.withOpacity(0.3), blurRadius: 10)],
                          ),
                          child: CircleAvatar(
                            radius: 35,
                            backgroundImage: NetworkImage(profile.profilePic ?? 'https://via.placeholder.com/150'),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // TEXT DETAILS
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    profile.name ?? "Coach",
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.verified_rounded, color: neonGreen, size: 18),
                                ],
                              ),
                              Text(
                                profile.specialization ?? "Clinical Nutritionist",
                                style: TextStyle(fontSize: 14, color: theme.hintColor, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              _buildBadge("Exp: ${profile.experience ?? '10+'} Yrs", neonGreen),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.dividerColor.withOpacity(0.1)),
                    const SizedBox(height: 16),

                    // CONTACT QUICK ACTIONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _contactBtn(FontAwesomeIcons.whatsapp, "WhatsApp", Colors.green, () {}),
                        _contactBtn(FontAwesomeIcons.phone, "Call", Colors.blue, () {}),
                        _contactBtn(FontAwesomeIcons.shareNodes, "Export Card", neonGreen, onShare),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _contactBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: FaIcon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}