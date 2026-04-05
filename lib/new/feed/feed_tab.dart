import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';
import 'package:nutricare_connect/features/content/feed_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';

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

  String? _getYouTubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      String? videoId;

      if (uri.host.contains('youtu.be')) {
        videoId = uri.pathSegments.first;
      } else if (uri.host.contains('youtube.com')) {
        videoId = uri.queryParameters['v'];
      }

      if (videoId != null) {
        return videoId;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final feedState = ref.watch(feedProvider);
    final feedNotifier = ref.read(feedProvider.notifier);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Ambient Glow
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05),
                      blurRadius: 80,
                      spreadRadius: 30,
                    )
                  ],
                ),
              ),
            ),

            RefreshIndicator(
              color: colorScheme.primary,
              backgroundColor: theme.cardColor,
              onRefresh: () async => await feedNotifier.refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Header
                  SliverToBoxAdapter(child: _buildHeader(theme, colorScheme, isDark)),

                  // 2. Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTextField(_searchController, "Search posts...", Icons.search_rounded, theme, colorScheme, isDark),
                    ),
                  ),

                  // 3. Filter Bar
                  SliverToBoxAdapter(child: _buildFilterBar(feedNotifier, theme, colorScheme, isDark)),

                  // 4. 🔥 THE NEW GRID LAYOUT
                  if (feedState.isLoading)
                    SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: colorScheme.primary)))
                  else if (feedState.items.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState(theme, colorScheme))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 2 Columns
                          mainAxisSpacing: 16, // Vertical spacing
                          crossAxisSpacing: 16, // Horizontal spacing
                          mainAxisExtent: 340, // 🔥 Fixed height prevents layout overflow!
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            if (index == feedState.items.length) {
                              return Center(child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: colorScheme.primary),
                              ));
                            }

                            final item = feedState.items[index];

                            if (item.type == FeedContentType.video) {
                              final link = (item.mediaUrl != null && item.mediaUrl!.isNotEmpty)
                                  ? item.mediaUrl
                                  : item.actionUrl;
                              final videoId = _getYouTubeId(link);

                              if (videoId != null) {
                                return _YoutubeFeedCard(
                                  key: ValueKey(item.id),
                                  item: item,
                                  videoId: videoId,
                                  videoUrl: link ?? '',
                                );
                              }
                            }

                            return _PremiumFeedCard(
                              key: ValueKey(item.id),
                              item: item,
                            );
                          },
                          // We add 1 for the loading spinner at the bottom if hasMore is true
                          childCount: feedState.items.length + (feedNotifier.hasMore ? 1 : 0),
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

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Community Feed",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.rss_feed_rounded, color: colorScheme.primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest.withOpacity(0.5) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
          prefixIcon: Icon(icon, color: theme.hintColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterBar(FeedNotifier notifier, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                color: isSelected ? colorScheme.primary : theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? colorScheme.primary : theme.dividerColor.withOpacity(0.2)),
                boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_rounded, size: 50, color: theme.disabledColor),
          const SizedBox(height: 12),
          Text("Feed is quiet today.", style: TextStyle(color: theme.hintColor, fontSize: 14)),
        ],
      ),
    );
  }
}

// ============================================================================
// 🎯 GRID-OPTIMIZED PREMIUM CARD
// ============================================================================
// 🎯 GRID-OPTIMIZED PREMIUM CARD (With Ambient Blur Background)
// ============================================================================
// ============================================================================
// 🎯 GRID-OPTIMIZED PREMIUM CARD (Edge-to-Edge Image Focus)
// ============================================================================
class _PremiumFeedCard extends StatefulWidget {
  final FeedItemModel item;
  const _PremiumFeedCard({super.key, required this.item});

  @override
  State<_PremiumFeedCard> createState() => _PremiumFeedCardState();
}

class _PremiumFeedCardState extends State<_PremiumFeedCard> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'image_${widget.item.id}',
                child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain, placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getActionLabel(FeedContentType type) {
    switch (type) {
      case FeedContentType.advertisement: return "Claim Offer";
      case FeedContentType.recipe: return "View Recipe";
      default: return "Read More";
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isRecipe = widget.item.type == FeedContentType.recipe;
    final displayImageUrl = widget.item.mediaUrl;
    final hasMedia = displayImageUrl != null && displayImageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMedia)
            GestureDetector(
              onTap: () => _openFullScreenImage(context, displayImageUrl),
              child: SizedBox(
                height: 170, // 🔥 INCREASED FROM 120px to 170px (50% of card)
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'image_${widget.item.id}',
                      child: CachedNetworkImage(
                        imageUrl: displayImageUrl,
                        // 🔥 FORCE COVER & TOP ALIGNMENT (No black space, no chopped heads)
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        memCacheWidth: 600,
                        maxWidthDiskCache: 800,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => Container(color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (_, __, ___) => Container(color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade200, child: Center(child: Icon(Icons.broken_image_rounded, color: theme.hintColor))),
                      ),
                    ),

                    if (isRecipe)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: theme.cardColor.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.restaurant_menu_rounded, size: 10, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text("RECIPE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.description,
                    maxLines: hasMedia ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: theme.hintColor, height: 1.3),
                  ),

                  const Spacer(),

                  if (widget.item.actionUrl != null && widget.item.actionUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchUrl(widget.item.actionUrl!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 12),
                        label: Text(_getActionLabel(widget.item.type), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRecipe ? colorScheme.secondary : colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(Icons.visibility_rounded, size: 12, color: theme.hintColor),
                      Text("${widget.item.views}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor)),
                      Icon(Icons.share_rounded, size: 12, color: theme.hintColor),
                      Text("${widget.item.shares}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor)),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🎯 GRID-OPTIMIZED YOUTUBE CARD
// ============================================================================
// ============================================================================
// 🎯 GRID-OPTIMIZED & PREMIUM YOUTUBE CARD
// ============================================================================
// ============================================================================
// 🎯 GRID-OPTIMIZED & PREMIUM YOUTUBE CARD (Black Bars Removed)
// ============================================================================
// ============================================================================
// 🎯 GRID-OPTIMIZED YOUTUBE CARD (Edge-to-Edge Zoomed Thumbnail)
// ============================================================================
class _YoutubeFeedCard extends StatefulWidget {
  final FeedItemModel item;
  final String videoId;
  final String videoUrl;

  const _YoutubeFeedCard({
    super.key,
    required this.item,
    required this.videoId,
    required this.videoUrl,
  });

  @override
  State<_YoutubeFeedCard> createState() => _YoutubeFeedCardState();
}

class _YoutubeFeedCardState extends State<_YoutubeFeedCard> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  Future<void> _openInApp() async {
    final url = 'https://www.youtube.com/watch?v=${widget.videoId}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final String thumbnailUrl = 'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg';

    return Container(
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _openInApp,
            child: SizedBox(
              height: 170, // 🔥 INCREASED FROM 120px to 170px
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.scale(
                    scale: 1.35, // Ensures the baked-in black bars are pushed off screen
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      maxWidthDiskCache: 800,
                      placeholder: (_, __) => Container(color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100),
                      errorWidget: (_, __, ___) => Container(color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade200, child: const Icon(Icons.video_library_rounded)),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                        )
                    ),
                  ),

                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FontAwesomeIcons.youtube, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Text("VIDEO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(widget.item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: theme.hintColor, height: 1.3)),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: _openInApp,
                      icon: const Icon(FontAwesomeIcons.youtube, size: 12),
                      label: const Text("Watch Video", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.redAccent : Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(Icons.visibility_rounded, size: 12, color: theme.hintColor),
                      Text("${widget.item.views}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor)),
                      Icon(Icons.share_rounded, size: 12, color: theme.hintColor),
                      Text("${widget.item.shares}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor)),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}