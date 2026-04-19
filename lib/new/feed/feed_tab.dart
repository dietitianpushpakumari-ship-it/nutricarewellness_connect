import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pure_shift/core/utils/feed_item_model.dart';
import 'package:pure_shift/features/content/feed_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// 🎯 GLOBAL FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

// 🚀 VIEW MODE STATE (false = Modern/Editorial, true = Inbox/List)
final feedViewModeProvider = StateProvider<bool>((ref) => false);

class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Videos', 'Recipes', 'Offers', 'Articles'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  // =========================================================================
  // 🔗 ROBUST MEDIA & TAP ROUTING
  // =========================================================================

  String? _getYouTubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final RegExp regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|shorts\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 2 && match.group(2)?.length == 11) {
      return match.group(2);
    }
    return null;
  }

  String? _getDisplayImageUrl(FeedItemModel item) {
    final ytId = _getYouTubeId(item.actionUrl) ?? _getYouTubeId(item.mediaUrl);
    if (ytId != null) return 'https://img.youtube.com/vi/$ytId/maxresdefault.jpg'; // Using maxres for crisper images
    return item.mediaUrl;
  }

  bool _isVideo(FeedItemModel item) {
    if (item.type == FeedContentType.video) return true;
    return (_getYouTubeId(item.actionUrl) ?? _getYouTubeId(item.mediaUrl)) != null;
  }

  void _handleItemTap(FeedItemModel item) {
    final ytId = _getYouTubeId(item.actionUrl) ?? _getYouTubeId(item.mediaUrl);

    if (ytId != null) {
      _launchUrl('https://www.youtube.com/watch?v=$ytId');
      return;
    }

    if (item.actionUrl != null && item.actionUrl!.isNotEmpty) {
      _launchUrl(item.actionUrl);
      return;
    }

    if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) {
      _openFullScreenImage(item.mediaUrl!);
      return;
    }
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
          extendBodyBehindAppBar: true,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 50),
              ),
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

    final feedState = ref.watch(feedProvider);
    final feedNotifier = ref.read(feedProvider.notifier);
    final isListView = ref.watch(feedViewModeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: true, // Ensures safety over bottom indicators
        child: Stack(
          children: [
            // Ambient Glow Effect
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(isDark ? 0.08 : 0.05), blurRadius: 100, spreadRadius: 40)],
                ),
              ),
            ),

            RefreshIndicator(
              color: colorScheme.primary,
              backgroundColor: theme.cardColor,
              onRefresh: () async => await feedNotifier.refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(theme, colorScheme, isDark, isListView)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTextField(_searchController, "Search insights...", Icons.search_rounded, theme, colorScheme, isDark),
                    ),
                  ),

                  SliverToBoxAdapter(child: _buildFilterBar(feedNotifier, theme, colorScheme, isDark)),

                  if (feedState.isLoading && feedState.items.isEmpty)
                    SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: colorScheme.primary)))
                  else if (feedState.items.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState(theme))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120), // Standardized padding
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            if (index == _getLayoutChunkCount(feedState.items, isListView)) {
                              return feedNotifier.hasMore
                                  ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: CircularProgressIndicator(color: colorScheme.primary)))
                                  : const SizedBox.shrink();
                            }
                            return isListView
                                ? _buildInboxItem(feedState.items[index], isDark)
                                : _buildModernChunk(feedState.items, index, isDark);
                          },
                          childCount: _getLayoutChunkCount(feedState.items, isListView) + 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🧩 MODERN LAYOUT ALGORITHMS
  // =========================================================================

  int _getLayoutChunkCount(List<FeedItemModel> items, bool isListView) {
    if (isListView) return items.length;
    int chunks = 0;
    int i = 0;
    while (i < items.length) {
      if (i % 4 == 0) { chunks++; i++; }
      else if (i % 4 == 1) { chunks++; i += 2; }
      else if (i % 4 == 3) { chunks++; i++; }
    }
    return chunks;
  }

  Widget _buildModernChunk(List<FeedItemModel> items, int chunkIndex, bool isDark) {
    int itemIndex = 0;
    for (int c = 0; c < chunkIndex; c++) {
      if (itemIndex % 4 == 0) itemIndex++;
      else if (itemIndex % 4 == 1) itemIndex += 2;
      else if (itemIndex % 4 == 3) itemIndex++;
    }

    if (itemIndex >= items.length) return const SizedBox.shrink();

    final item = items[itemIndex];
    final pattern = itemIndex % 4;

    if (pattern == 0) {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildHeroCard(item, isDark));
    } else if (pattern == 1) {
      final hasNext = itemIndex + 1 < items.length;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(flex: 5, child: _buildTallCard(item, isDark)),
            const SizedBox(width: 16),
            if (hasNext) Expanded(flex: 4, child: _buildSquareCard(items[itemIndex + 1], isDark))
            else const Expanded(flex: 4, child: SizedBox.shrink()),
          ],
        ),
      );
    } else {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildWideUpdateCard(item, isDark));
    }
  }

  // =========================================================================
  // 🎨 ULTRA-PREMIUM BENTO CARDS (Typography & Layout fixed)
  // =========================================================================

// =========================================================================
  // 🎨 ULTRA-PREMIUM BENTO CARDS (Typography & Layout fixed)
  // =========================================================================

  Widget _buildHeroCard(FeedItemModel item, bool isDark) {
    final isVideo = _isVideo(item);
    final displayImg = _getDisplayImageUrl(item);

    // 🚀 THE FIX: Force complex objects back to simple Strings safely.
    final String safeTitle = item.title is Map ? (item.title as Map).values.first.toString() : item.title.toString();
    final String safeDesc = item.description is Map ? (item.description as Map).values.first.toString() : item.description.toString();

    return GestureDetector(
      onTap: () => _handleItemTap(item),
      child: _PremiumGlassCard(
        height: 280,
        imageUrl: displayImg,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.95)]),
              ),
            ),
            if (isVideo)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.3))),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(type: item.type), // Main hero cards always show badge if applicable
                  const SizedBox(height: 10),
                  Text(safeTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: kDisplayFont, color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text(safeDesc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kBodyFont, color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTallCard(FeedItemModel item, bool isDark) {
    final displayImg = _getDisplayImageUrl(item);
    final isVideo = _isVideo(item);
    final String safeTitle = item.title is Map ? (item.title as Map).values.first.toString() : item.title.toString();

    return GestureDetector(
      onTap: () => _handleItemTap(item),
      child: _PremiumGlassCard(
        height: 240,
        imageUrl: displayImg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.95)]),
              ),
            ),
            if (isVideo)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(type: item.type, compact: true),
                  const SizedBox(height: 8),
                  Text(safeTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: kDisplayFont, color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareCard(FeedItemModel item, bool isDark) {
    final displayImg = _getDisplayImageUrl(item);
    final isVideo = _isVideo(item);
    final String safeTitle = item.title is Map ? (item.title as Map).values.first.toString() : item.title.toString();

    return GestureDetector(
      onTap: () => _handleItemTap(item),
      child: _PremiumGlassCard(
        height: 240,
        imageUrl: displayImg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.95)]),
              ),
            ),
            if (isVideo)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TypeBadge(type: item.type, compact: true),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(safeTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: kDisplayFont, color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.visibility_rounded, size: 12, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text("${item.views}", style: TextStyle(fontFamily: kDisplayFont, color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                          ),
                        ],
                      )
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

  Widget _buildWideUpdateCard(FeedItemModel item, bool isDark) {
    final displayImg = _getDisplayImageUrl(item);
    final isVideo = _isVideo(item);
    final String safeTitle = item.title is Map ? (item.title as Map).values.first.toString() : item.title.toString();
    final String safeDesc = item.description is Map ? (item.description as Map).values.first.toString() : item.description.toString();

    return GestureDetector(
      onTap: () => _handleItemTap(item),
      child: _PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (displayImg != null)
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    image: DecorationImage(image: CachedNetworkImageProvider(displayImg), fit: BoxFit.cover),
                  ),
                  child: isVideo ? const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24)) : null,
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                  child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                ),

              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(safeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: kDisplayFont, color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(safeDesc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kBodyFont, color: Colors.white.withOpacity(0.6), fontSize: 11)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 📝 INBOX (LIST) VIEW BUILDER
  // =========================================================================

  Widget _buildInboxItem(FeedItemModel item, bool isDark) {
    final isVideo = _isVideo(item);
    final displayImg = _getDisplayImageUrl(item);
    final ytId = _getYouTubeId(item.actionUrl) ?? _getYouTubeId(item.mediaUrl);
    final externalUrl = ytId != null ? 'https://www.youtube.com/watch?v=$ytId' : item.actionUrl;
    final hasActionBtn = externalUrl != null && externalUrl.isNotEmpty;
    final String safeTitle = item.title is Map ? (item.title as Map).values.first.toString() : item.title.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleItemTap(item),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    image: displayImg != null ? DecorationImage(image: CachedNetworkImageProvider(displayImg), fit: BoxFit.cover) : null,
                  ),
                  child: isVideo
                      ? const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32))
                      : (displayImg == null ? Center(child: Icon(Icons.article_rounded, color: isDark ? Colors.white24 : Colors.grey)) : null),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TypeBadge(type: item.type),
                          const Spacer(),
                          Icon(Icons.more_horiz_rounded, color: isDark ? Colors.white24 : Colors.grey, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(safeTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kDisplayFont, color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w800, height: 1.2)),

                      if (hasActionBtn) ...[
                        const SizedBox(height: 12),
                        _buildActionButton(item, isVideo, externalUrl!, isDark),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 12, color: isDark ? Colors.white54 : Colors.grey),
                            const SizedBox(width: 4),
                            Text("${item.views} views", style: TextStyle(fontFamily: kDisplayFont, color: isDark ? Colors.white54 : Colors.grey, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        )
                      ]
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

  Widget _buildActionButton(FeedItemModel item, bool isVideo, String destUrl, bool isDark) {
    Color color;
    IconData icon;
    String label;

    if (isVideo) {
      color = isDark ? Colors.redAccent : Colors.red.shade700;
      icon = FontAwesomeIcons.youtube;
      label = "Watch Video";
    } else if (item.type == FeedContentType.recipe) {
      color = isDark ? Colors.orangeAccent : Colors.orange.shade700;
      icon = Icons.restaurant_menu_rounded;
      label = "View Recipe";
    } else if (item.type == FeedContentType.advertisement) {
      color = isDark ? Colors.purpleAccent : Colors.purple.shade700;
      icon = Icons.local_offer_rounded;
      label = "Claim Offer";
    } else {
      color = isDark ? Colors.blueAccent : Colors.blue.shade700;
      icon = Icons.open_in_new_rounded;
      label = "Read More";
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: () => _launchUrl(destUrl),
        icon: Icon(icon, size: 12, color: Colors.white),
        label: Text(label, style: const TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, fontSize: 10, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  // =========================================================================
  // 🛠️ HEADER & CONTROLS
  // =========================================================================

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, bool isDark, bool isListView) {
    return Container(
      // Adjusted left padding from 20 to 12 to account for the IconButton's built-in padding
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🚀 THE FIX: Grouped the Back Button and Title together
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface, size: 26),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(width: 4),
              Text(
                "Discover",
                style: TextStyle(
                  fontFamily: kDisplayFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          // View mode toggles (Unchanged)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleBtn(icon: Icons.dashboard_rounded, isActive: !isListView, isDark: isDark, onTap: () => ref.read(feedViewModeProvider.notifier).state = false),
                _ToggleBtn(icon: Icons.view_agenda_rounded, isActive: isListView, isDark: isDark, onTap: () => ref.read(feedViewModeProvider.notifier).state = true),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : theme.dividerColor.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 14),
          prefixIcon: Icon(icon, color: theme.hintColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterBar(FeedNotifier notifier, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = filter);
              notifier.setFilter(filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300)),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(fontFamily: kDisplayFont, color: isSelected ? (isDark ? Colors.black : Colors.white) : theme.hintColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_rounded, size: 50, color: theme.disabledColor),
          const SizedBox(height: 12),
          Text("Feed is quiet today.", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 14)),
        ],
      ),
    );
  }
}

// =========================================================================
// 🧱 SHARED UI COMPONENTS
// =========================================================================

class _PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final String? imageUrl;

  const _PremiumGlassCard({required this.child, this.height, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C).withOpacity(0.8) : const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (imageUrl != null)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.02)),
                  errorWidget: (context, url, error) => Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.broken_image_rounded, color: Colors.white24)),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final FeedContentType type;
  final bool compact;

  const _TypeBadge({required this.type, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Color accent;
    String label;
    IconData? icon;

    switch (type) {
      case FeedContentType.video: accent = Colors.redAccent; label = "VIDEO"; icon = Icons.play_circle_fill_rounded; break;
      case FeedContentType.article: accent = Colors.greenAccent; label = "ARTICLE"; icon = Icons.article_rounded; break;
      case FeedContentType.recipe: accent = Colors.orangeAccent; label = "RECIPE"; icon = Icons.restaurant_menu_rounded; break;
      case FeedContentType.advertisement: accent = Colors.purpleAccent; label = "OFFER"; icon = Icons.local_offer_rounded; break;
      default: return const SizedBox.shrink(); // 🚀 FIX: Hides unnecessary "UPDATE" badges on grids
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact && icon != null) ...[
            Icon(icon, size: 10, color: accent),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontFamily: kDisplayFont, color: accent, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ToggleBtn({required this.icon, required this.isActive, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white.withOpacity(0.3) : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? (isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade200) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 18, color: isActive ? activeColor : inactiveColor),
      ),
    );
  }
}