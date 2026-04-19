import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart'; // 🚀 Added for active icons

// Adjust imports based on your actual project structure
import 'package:pure_shift/core/dietitian_profile_detail_screen.dart';
import 'package:pure_shift/features/dietplan/domain/entities/admin_profile_model.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class DietitianBusinessCard extends StatefulWidget {
  final AdminProfileModel profile;

  const DietitianBusinessCard({super.key, required this.profile});

  @override
  State<DietitianBusinessCard> createState() => _DietitianBusinessCardState();
}

class _DietitianBusinessCardState extends State<DietitianBusinessCard> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  // =========================================================================
  // 📤 SMART SHARE LOGIC
  // =========================================================================
  Future<void> _captureAndShareLocal() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    try {
      File? fileToShare;
      final String? realCardUrl = widget.profile.visitingCardUrl;

      if (realCardUrl != null && realCardUrl.isNotEmpty) {
        fileToShare = await DefaultCacheManager().getSingleFile(realCardUrl);
      } else {
        RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        final directory = await getTemporaryDirectory();
        fileToShare = await File('${directory.path}/digital_card_${widget.profile.id}.png').create();
        await fileToShare.writeAsBytes(pngBytes);
      }

      if (mounted && fileToShare != null) {
        await Share.shareXFiles(
          [XFile(fileToShare.path)],
          text: 'Here is the clinical contact card for ${widget.profile.fullName} from NutriCare Wellness.',
        );
      }
    } catch (e) {
      debugPrint("Sharing failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to share card. Please try again.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            )
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // =========================================================================
  // 🔗 URL LAUNCHER HELPERS
  // =========================================================================
  Future<void> _launchAction(String urlString) async {
    HapticFeedback.selectionClick();
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError("Action unavailable on this device.");
      }
    } catch (e) {
      _showError("Could not launch action.");
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🪪 THE CARD PREVIEW (Captured area)
        RepaintBoundary(
          key: _globalKey,
          child: _buildSystemGeneratedCard(context),
        ),

        const SizedBox(height: 12),

        // 🛠️ THE SHARE BUTTON (Outside capture area)
        _buildShareButton(context),
      ],
    );
  }

  // =========================================================================
  // 🎨 DIGITAL PREVIEW CARD WITH ACTIVE ICONS
  // =========================================================================
  Widget _buildSystemGeneratedCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final profile = widget.profile;

    final String titlePrefix = (profile.title != null && profile.title!.isNotEmpty) ? "${profile.title} " : "";
    final String name = "$titlePrefix${profile.fullName}".trim();
    final String designation = profile.designation.isNotEmpty ? profile.designation : "Clinical Specialist";
    final String avatarUrl = profile.photoUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        gradient: LinearGradient(
          colors: [theme.cardColor, isDark ? Colors.grey.shade900 : Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER PROFILE
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  image: avatarUrl.isNotEmpty
                      ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: avatarUrl.isEmpty
                    ? Icon(Icons.person_rounded, color: colorScheme.primary, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: kDisplayFont, fontSize: 18, fontWeight: FontWeight.w800, color: colorScheme.onSurface, letterSpacing: -0.5)
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.verified_rounded, color: Colors.green, size: 14),
                        )
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        designation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary)
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 🚀 NEW: ACTIVE ICON ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionIcon(
                  context,
                  icon: Icons.phone_rounded,
                  label: "Call",
                  onTap: () {
                    final phone = profile.mobile;
                    if (phone.isNotEmpty) _launchAction('tel:$phone');
                  }
              ),
              _buildActionIcon(
                  context,
                  icon: Icons.email_rounded,
                  label: "Email",
                  onTap: () {
                    final email = profile.companyEmail.isNotEmpty ? profile.companyEmail : profile.email;
                    if (email.isNotEmpty) _launchAction('mailto:$email');
                  }
              ),
              _buildActionIcon(
                  context,
                  icon: Icons.language_rounded,
                  label: "Website",
                  onTap: () => _launchAction('https://nutricarewellness.com')
              ),
              _buildActionIcon(
                  context,
                  icon: Icons.person_search_rounded,
                  label: "Profile",
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DietitianProfileDetailScreen(profile: profile)));
                  }
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🚀 HELPER: SINGLE ACTIVE ICON
  Widget _buildActionIcon(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.primary.withOpacity(0.15) : colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontFamily: kBodyFont, fontSize: 10, fontWeight: FontWeight.w600, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔘 FULL-WIDTH SHARE BUTTON
  // =========================================================================
  Widget _buildShareButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isSharing ? null : _captureAndShareLocal,
        icon: _isSharing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
        label: Text(
            _isSharing ? "PREPARING..." : "SHARE DIGITAL CARD",
            style: const TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: Colors.white)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          disabledBackgroundColor: colorScheme.primary.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}