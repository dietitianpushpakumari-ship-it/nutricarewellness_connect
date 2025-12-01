import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:url_launcher/url_launcher.dart';

class DietitianProfileDetailScreen extends StatelessWidget {
  final AdminProfileModel profile;

  const DietitianProfileDetailScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          // 1. Ambient Background
          Positioned(top: -100, right: -100, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 100, spreadRadius: 40)]))),

          CustomScrollView(
            slivers: [
              // 2. Hero Header (Cover Image + Avatar)
              SliverAppBar(
                expandedHeight: 280,
                backgroundColor: Colors.white,
                elevation: 0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient Cover
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Decorative Circles
                      Positioned(top: -50, right: -50, child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),
                      Positioned(bottom: -20, left: -20, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),

                      // Avatar Centered
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40), // Push down from status bar
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                backgroundImage: profile.photoUrl.isNotEmpty ? NetworkImage(profile.photoUrl) : null,
                                child: profile.photoUrl.isEmpty ? Text(profile.firstName[0], style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Color(0xFF3949AB))) : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text("${profile.firstName} ${profile.lastName}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(profile.designation, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A. About / Company
                      _buildSectionTitle("Professional Profile"),
                      _buildInfoCard([
                        _buildInfoRow(Icons.business, "Company", profile.companyName),
                        if (profile.regdNo.isNotEmpty) _buildInfoRow(Icons.verified_user, "Registration No.", profile.regdNo),
                        // Mock Bio if missing
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text("Experienced clinical dietitian specializing in metabolic health and personalized nutrition strategies. Dedicated to transforming lives through science-backed dietary interventions.", style: TextStyle(height: 1.5, color: Colors.grey)),
                        )
                      ]),
                      const SizedBox(height: 24),

                      // B. Specializations (Full List)
                      _buildSectionTitle("Areas of Expertise"),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: (profile.specializations.isNotEmpty ? profile.specializations : ["Weight Management", "Diabetes", "PCOS", "Thyroid", "Gut Health", "Sports Nutrition"])
                              .map((spec) => Chip(
                            label: Text(spec, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                            backgroundColor: Colors.indigo.shade50,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // C. Contact & Connect
                      _buildSectionTitle("Get in Touch"),
                      _buildInfoCard([
                        _buildContactTile(Icons.email, "Email", profile.companyEmail.isNotEmpty ? profile.companyEmail : profile.email, () => _launch("mailto:${profile.companyEmail}")),
                        _buildContactTile(Icons.phone, "Phone", profile.mobile, () => _launch("tel:${profile.mobile}")),
                        _buildContactTile(FontAwesomeIcons.whatsapp, "WhatsApp", profile.mobile, () => _launch("https://wa.me/${profile.mobile}")),
                        if (profile.website.isNotEmpty) _buildContactTile(Icons.language, "Website", profile.website, () => _launch(profile.website)),
                        if (profile.address.isNotEmpty) _buildContactTile(Icons.location_on, "Clinic Address", profile.address, (){}),
                      ]),

                      const SizedBox(height: 40),
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

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))));
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: Colors.indigo),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]))
      ]),
    );
  }

  Widget _buildContactTile(IconData icon, String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle), child: Icon(icon, color: Colors.indigo, size: 20)),
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }
}