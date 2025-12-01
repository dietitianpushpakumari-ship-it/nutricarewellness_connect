import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/core/dietitian_profile_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';

class DietitianBusinessCard extends StatelessWidget {
  final AdminProfileModel profile;
  final VoidCallback onShare;

  const DietitianBusinessCard({
    super.key,
    required this.profile,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final specs = profile.specializations.isNotEmpty
        ? profile.specializations
        : ["Weight Loss", "Diabetes", "PCOS", "Sports Nutrition"];

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DietitianProfileDetailScreen(profile: profile))
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // Slightly tighter corners
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A00E0).withOpacity(0.7),
              blurRadius: 2,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 1. COMPACT GRADIENT
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                  ),
                ),
              ),

              // 2. DECORATIVE ELEMENTS (Subtle)
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 15),
                  ),
                ),
              ),

              // 3. COMPACT CONTENT
              Padding(
                padding: const EdgeInsets.all(16.0), // 🎯 Reduced Padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // 🎯 Shrink wrap
                  children: [
                    // --- HEADER ---
                    Row(
                      children: [
                        // Compact Avatar
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 26, // 🎯 Reduced Size
                            backgroundColor: Colors.white,
                            backgroundImage: profile.photoUrl.isNotEmpty
                                ? NetworkImage(profile.photoUrl)
                                : null,
                            child: profile.photoUrl.isEmpty
                                ? Text(
                              profile.firstName.isNotEmpty ? profile.firstName[0] : 'D',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A00E0)),
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${profile.firstName} ${profile.lastName}",
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.designation.isNotEmpty ? profile.designation : "Senior Dietitian",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withOpacity(0.2), height: 1),
                    const SizedBox(height: 12),

                    // --- SPECIALIZATIONS (Compact) ---
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: specs.take(3).map((spec) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                            spec,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)
                        ),
                      )).toList(),
                    ),

                    const SizedBox(height: 16),

                    // --- FOOTER ACTIONS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Contact Icons
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildActionIcon(FontAwesomeIcons.whatsapp, () => _launch("https://wa.me/${profile.mobile}")),
                                const SizedBox(width: 10),
                                _buildActionIcon(Icons.call_rounded, () => _launch("tel:${profile.mobile}")),
                                const SizedBox(width: 10),
                                _buildActionIcon(Icons.email_rounded, () => _launch("mailto:${profile.companyEmail}")),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Share Button (Smaller)
                        SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            onPressed: onShare,
                            icon: const Icon(Icons.share_rounded, size: 14),
                            label: const Text("Share", style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: const Color(0xFF4A00E0),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }
}