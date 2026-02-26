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

  String? _getYouTubeThumbnail(String? videoUrl) {
    if (videoUrl == null) return null;
    try {
      final uri = Uri.parse(videoUrl);
      String? videoId;

      if (uri.host.contains('youtu.be')) {
        videoId = uri.pathSegments.first;
      } else if (uri.host.contains('youtube.com')) {
        videoId = uri.queryParameters['v'];
      }

      if (videoId != null) {
        return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch $url");
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
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

                  // 4. Feed Items
                  if (feedState.isLoading)
                    SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: colorScheme.primary)))
                  else if (feedState.items.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState(theme, colorScheme))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                      sliver: SliverList(
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
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: _YoutubeFeedCard(
                                    key: ValueKey(item.id),
                                    item: item,
                                    videoId: videoId,
                                    videoUrl: link ?? '',
                                  ),
                                );
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _buildPremiumCard(context, item, theme, colorScheme, isDark),
                            );
                          },
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
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
                boxShadow: isSelected
                    ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, FeedItemModel item, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final isVideo = item.type == FeedContentType.video;
    final isRecipe = item.type == FeedContentType.recipe;

    String? displayImageUrl = item.mediaUrl;
    if (isVideo && (displayImageUrl == null || displayImageUrl.isEmpty) && item.actionUrl != null) {
      displayImageUrl = _getYouTubeThumbnail(item.actionUrl);
    }
    String? clickUrl = item.actionUrl;
    if (isVideo && (clickUrl == null || clickUrl.isEmpty)) clickUrl = item.mediaUrl;

    // 🎯 DYNAMIC MEDIA CHECK
    final bool hasMedia = displayImageUrl != null || isVideo;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.04), blurRadius: 15, offset: const Offset(0, 6))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Header
          if (hasMedia)
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: displayImageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: displayImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade200,
                      child: Center(child: Icon(Icons.broken_image_rounded, color: theme.hintColor)),
                    ),
                  )
                      : Container(color: isDark ? Colors.black : Colors.grey.shade900),
                ),

                if (isVideo)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 50),
                    ),
                  ),

                if (isRecipe)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu_rounded, size: 12, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text("RECIPE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(14), // 🎯 Tighter padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface, height: 1.2),
                ),
                const SizedBox(height: 4), // 🎯 Tighter spacing
                Text(
                  item.description,
                  // 🎯 ONLY 1 LINE IF IT HAS AN IMAGE, 3 LINES IF IT IS TEXT-ONLY
                  maxLines: hasMedia ? 1 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: theme.hintColor, height: 1.4),
                ),

                // Recipe Metadata
                if (isRecipe && item.recipeData != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildRecipeTag(Icons.local_fire_department_rounded, "${item.recipeData!['calories']} Kcal", theme, colorScheme, isDark),
                      const SizedBox(width: 10),
                      _buildRecipeTag(Icons.timer_rounded, "${item.recipeData!['time']} Mins", theme, colorScheme, isDark),
                    ],
                  ),
                ],

                // Action Button
                if (clickUrl != null && clickUrl.isNotEmpty) ...[
                  const SizedBox(height: 12), // 🎯 Tighter spacing
                  SizedBox(
                    width: double.infinity,
                    height: 40, // 🎯 Thinner button
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl(clickUrl!),
                      icon: Icon(isVideo ? Icons.play_arrow_rounded : Icons.open_in_new_rounded, size: 16),
                      label: Text(_getActionLabel(item.type), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVideo
                            ? (isDark ? Colors.redAccent : Colors.red.shade700)
                            : (isRecipe ? colorScheme.secondary : colorScheme.primary),
                        foregroundColor: isVideo ? Colors.white : colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), // 🎯 Tighter bottom padding
            child: Row(
              children: [
                _buildStatBadge(Icons.visibility_rounded, "${item.views}", theme),
                const SizedBox(width: 12),
                _buildStatBadge(Icons.share_rounded, "${item.shares}", theme),
                const Spacer(),
                Text(
                  DateFormat('dd MMM').format(item.postedAt),
                  style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecipeTag(IconData icon, String label, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: theme.iconTheme.color?.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.hintColor),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
      ],
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

  String _getActionLabel(FeedContentType type) {
    switch (type) {
      case FeedContentType.video: return "Watch Video";
      case FeedContentType.advertisement: return "Claim Offer";
      case FeedContentType.recipe: return "View Recipe";
      default: return "Read More";
    }
  }
}

// 🎯 YOUTUBE CARD
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
  late YoutubePlayerController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        isLive: false,
        forceHD: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openInApp() async {
    final url = 'https://www.youtube.com/watch?v=${widget.videoId}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _shareVideo() {
    Share.share('Check out this video on NutriCare: ${widget.videoUrl}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.04), blurRadius: 15, offset: const Offset(0, 6))]
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.red,
            progressColors: const ProgressBarColors(playedColor: Colors.red, handleColor: Colors.redAccent),
            topActions: [
              const Spacer(),
              IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20), onPressed: _shareVideo),
              IconButton(icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20), onPressed: _openInApp),
            ],
            bottomActions: [
              CurrentPosition(),
              ProgressBar(isExpanded: true),
              RemainingDuration(),
              const FullScreenButton(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface, height: 1.2)),
                const SizedBox(height: 4),
                Text(
                    widget.item.description,
                    maxLines: 1, // 🎯 ONLY 1 LINE FOR YOUTUBE CARDS
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: theme.hintColor, height: 1.4)
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Icon(Icons.visibility_rounded, size: 14, color: theme.hintColor),
                const SizedBox(width: 4),
                Text("${widget.item.views}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
                const SizedBox(width: 12),
                Icon(Icons.share_rounded, size: 14, color: theme.hintColor),
                const SizedBox(width: 4),
                Text("${widget.item.shares}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
                const Spacer(),
                Text(
                  DateFormat('dd MMM').format(widget.item.postedAt),
                  style: TextStyle(fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}