import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';


// 🎯 CMS FILTER CONSTANT
// Change this to 'testimonial', 'article', etc. depending on which tab you are building
const String kRequiredCmsCategory = 'article';

// 🚀 VIEW MODE STATE (false = Bento/Modern, true = List/Inbox)
final feedViewModeProvider = StateProvider<bool>((ref) => false);

class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 🔗 CMS ACTIONS & NAVIGATION
  // =========================================================================

  Future<void> _handleItemTap(Map<String, dynamic> data) async {
    HapticFeedback.lightImpact();
    final String type = data['type'] ?? 'text';
    final List<String> urls = List<String>.from(data['urls'] ?? []);

    // 📄 PDF / DOCUMENT HANDLING
    if (type == 'document' && urls.isNotEmpty) {
      final Uri url = Uri.parse(urls.first);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 🎥 VIDEO HANDLING (YouTube)
    if (type == 'video' && urls.isNotEmpty) {
      final Uri url = Uri.parse(urls.first);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 🖼️ IMAGE / ARTICLE HANDLING
    // Navigate to a detail view if you have one, or open full screen image
    if (urls.isNotEmpty) {
      _openFullScreenImage(urls.first);
    }
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isListView = ref.watch(feedViewModeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _buildAmbientGlow(colorScheme, isDark),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cms_content')
                  .where('isLive', isEqualTo: true)
                  .where('category', isEqualTo: kRequiredCmsCategory)
                  .orderBy('updated_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                // Filter docs by search query locally
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title_en'] ?? "").toString().toLowerCase();
                  return title.contains(_searchQuery.toLowerCase());
                }).toList();

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(colorScheme, isDark, isListView)),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: _buildSearchField(theme, colorScheme, isDark),
                      ),
                    ),

                    if (filteredDocs.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState(theme))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final data = filteredDocs[index].data() as Map<String, dynamic>;
                              return isListView
                                  ? _buildInboxItem(data, isDark, theme)
                                  : _buildModernBentoItem(data, isDark, theme, index);
                            },
                            childCount: filteredDocs.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🎨 UI BUILDERS
  // =========================================================================

  Widget _buildModernBentoItem(Map<String, dynamic> data, bool isDark, ThemeData theme, int index) {
    // We can implement a pattern (Hero, then 2 side-by-side, then Wide)
    // For simplicity and CMS reliability, we'll use a dynamic high-end card
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _CmsHeroCard(data: data, isDark: isDark, onTap: () => _handleItemTap(data)),
    );
  }

  Widget _buildInboxItem(Map<String, dynamic> data, bool isDark, ThemeData theme) {
    final String title = data['title_en'] ?? 'Untitled';
    final String coverUrl = data['coverImageUrl'] ?? '';
    final String type = data['type'] ?? 'text';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _handleItemTap(data),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnail(coverUrl, type, theme),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryBadge(type, theme),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildThumbnail(String url, String type, ThemeData theme) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Icon(type == 'document' ? Icons.picture_as_pdf_rounded : Icons.article_rounded, color: theme.primaryColor, size: 30),
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
        isPdf ? "PDF REPORT" : "ARTICLE",
        style: TextStyle(color: isPdf ? Colors.redAccent : theme.primaryColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, bool isDark, bool isListView) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Text("Discover", style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
          _buildViewToggle(isListView, isDark),
        ],
      ),
    );
  }

  Widget _buildViewToggle(bool isListView, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _toggleBtn(Icons.dashboard_rounded, !isListView, isDark, () => ref.read(feedViewModeProvider.notifier).state = false),
          _toggleBtn(Icons.view_agenda_rounded, isListView, isDark, () => ref.read(feedViewModeProvider.notifier).state = true),
        ],
      ),
    );
  }

  Widget _toggleBtn(IconData icon, bool isActive, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? (isDark ? Colors.white.withOpacity(0.1) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Icon(icon, size: 18, color: isActive ? (isDark ? Colors.white : Colors.black) : Colors.grey),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search in ${kRequiredCmsCategory}...",
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildAmbientGlow(ColorScheme colorScheme, bool isDark) {
    return Positioned(
      top: -50, right: -50,
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(isDark ? 0.08 : 0.05), blurRadius: 100, spreadRadius: 40)],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 50, color: theme.dividerColor),
          const SizedBox(height: 12),
          Text("No results found.", style: TextStyle(color: theme.hintColor)),
        ],
      ),
    );
  }
}

// =========================================================================
// 🧱 CMS HERO CARD COMPONENT
// =========================================================================

class _CmsHeroCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final VoidCallback onTap;

  const _CmsHeroCard({required this.data, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String coverUrl = data['coverImageUrl'] ?? '';
    final String title = data['title_en'] ?? '';
    final String type = data['type'] ?? 'text';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2C) : const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 🖼️ COVER IMAGE
              if (coverUrl.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.black12),
                  ),
                ),

              // 🌑 GRADIENT OVERLAY
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    ),
                  ),
                ),
              ),

              // 🎥 VIDEO ICON (Center)
              if (type == 'video')
                const Center(
                  child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 60),
                ),

              // 📝 TEXT CONTENT (Bottom)
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badge(type),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
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

  Widget _badge(String type) {
    final bool isPdf = type == 'document';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isPdf ? Colors.redAccent : Colors.blueAccent).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isPdf ? Colors.redAccent : Colors.blueAccent).withOpacity(0.5)),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0),
      ),
    );
  }
}