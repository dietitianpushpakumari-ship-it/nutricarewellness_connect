import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';


const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class DashboardFeedPreview extends ConsumerWidget {
  final String categoryFilter; // e.g., 'article' or 'testimonial'

  const DashboardFeedPreview({super.key, this.categoryFilter = 'journal'});

  // --- ACTIONS ---
  Future<void> _handleContentTap(BuildContext context, Map<String, dynamic> data) async {
    HapticFeedback.lightImpact();
    final String type = data['type'] ?? 'text';
    final List<String> urls = List<String>.from(data['urls'] ?? []);

    // 📄 PDF Handling
    if (type == 'document' && urls.isNotEmpty) {
      final Uri url = Uri.parse(urls.first);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else if (urls.isNotEmpty) {
      // 🖼️ Image/Video Handling (Existing logic)
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      // 🚀 Listen to cms_content instead of local feedProvider
      stream: FirebaseFirestore.instance
          .collection('cms_content')
          .where('isLive', isEqualTo: true)
          .where('category', isEqualTo: categoryFilter)
          .orderBy('updated_at', descending: true)
          .limit(3) // Only show the latest 3 on dashboard
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        final recentDocs = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, theme, colorScheme),
              const SizedBox(height: 16),
              ...recentDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildCmsBentoCard(context, data, theme, isDark);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "DAILY BRIEFING",
          style: TextStyle(
            fontFamily: kDisplayFont,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: theme.hintColor.withOpacity(0.5),
          ),
        ),
        GestureDetector(
          onTap: () { /* Navigate to full list */ },
          child: Text(
            "View All",
            style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w800, color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildCmsBentoCard(BuildContext context, Map<String, dynamic> data, ThemeData theme, bool isDark) {
    final String title = data['title_en'] ?? '';
    final String coverUrl = data['coverImageUrl'] ?? '';
    final String type = data['type'] ?? 'text';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _handleContentTap(context, data),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [theme.colorScheme.surface, theme.colorScheme.surface.withOpacity(0.8)]
                  : [Colors.white, const Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1), width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 🖼️ CMS COVER IMAGE / THUMBNAIL
                _buildThumbnail(coverUrl, type, theme),
                const SizedBox(width: 16),

                // 📝 CONTENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryBadge(type, theme),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        style: TextStyle(fontFamily: kDisplayFont, fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String url, String type, ThemeData theme) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Icon(type == 'document' ? Icons.picture_as_pdf_rounded : Icons.article_rounded, color: theme.primaryColor.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildCategoryBadge(String type, ThemeData theme) {
    final bool isPdf = type == 'document';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isPdf ? Colors.redAccent : theme.primaryColor).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPdf ? "PDF REPORT" : "CLINICAL ARTICLE",
        style: TextStyle(color: isPdf ? Colors.redAccent : theme.primaryColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0),
      ),
    );
  }
}