import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';
import 'package:nutricare_connect/core/utils/feed_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart'; // 🎯 ADD THIS IMPORT

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

  // Helper to extract thumbnail from YouTube URL
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
    final feedState = ref.watch(feedProvider);
    final feedNotifier = ref.read(feedProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          // 1. Ambient Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 80,
                    spreadRadius: 30,
                  )
                ],
              ),
            ),
          ),

          Column(
            children: [
              // 2. Glass Header
              _buildHeader(),

              // 3. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTextField(
                    _searchController,
                    "Search posts...",
                    Icons.search,
                    onChanged: (val) {
                      // Implement local search filtering if needed
                    }
                ),
              ),

              // 4. Filter Bar
              _buildFilterBar(feedNotifier),

              // 5. Feed List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => await feedNotifier.refresh(),
                  child: feedState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : feedState.items.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                    itemCount: feedState.items.length + (feedNotifier.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      if (index == feedState.items.length) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      final item = feedState.items[index];

                      // Check for Video
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
                            videoUrl: link ?? '', // Pass the full URL
                          );
                        }
                      }

                      return _buildPremiumCard(context, item);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Community Feed",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rss_feed, color: Colors.orange.shade800, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isNumber = false, ValueChanged<String>? onChanged}) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.indigo.withOpacity(0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterBar(FeedNotifier notifier) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 10),
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
                color: isSelected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
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

  Widget _buildPremiumCard(BuildContext context, FeedItemModel item) {
    final isVideo = item.type == FeedContentType.video;
    final isRecipe = item.type == FeedContentType.recipe;

    String? displayImageUrl = item.mediaUrl;
    if (isVideo && (displayImageUrl == null || displayImageUrl.isEmpty) && item.actionUrl != null) {
      displayImageUrl = _getYouTubeThumbnail(item.actionUrl);
    }
    String? clickUrl = item.actionUrl;
    if (isVideo && (clickUrl == null || clickUrl.isEmpty)) clickUrl = item.mediaUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Header
          if (displayImageUrl != null || isVideo)
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: displayImageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: displayImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey.shade100),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.black,
                      child: const Center(child: Icon(Icons.error, color: Colors.white)),
                    ),
                  )
                      : Container(color: Colors.black87),
                ),

                if (isVideo)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),

                if (isRecipe)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.restaurant_menu, size: 14, color: Colors.orange),
                          SizedBox(width: 4),
                          Text("RECIPE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                ),

                // Recipe Metadata
                if (isRecipe && item.recipeData != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildRecipeTag(Icons.local_fire_department, "${item.recipeData!['calories']} Kcal"),
                      const SizedBox(width: 12),
                      _buildRecipeTag(Icons.timer, "${item.recipeData!['time']} Mins"),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Action Button
                if (clickUrl != null && clickUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      // 🎯 FIXED: Correctly calls _launchUrl
                      onPressed: () => _launchUrl(clickUrl!),
                      icon: Icon(isVideo ? Icons.play_arrow : Icons.open_in_new, size: 18),
                      label: Text(_getActionLabel(item.type)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVideo
                            ? Colors.red
                            : (isRecipe ? Colors.orange : Colors.indigo),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                _buildStatBadge(Icons.visibility, "${item.views}"),
                const SizedBox(width: 12),
                _buildStatBadge(Icons.share, "${item.shares}"),
                const Spacer(),
                Text(
                  DateFormat('dd MMM').format(item.postedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecipeTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Feed is quiet today.",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(FeedContentType type) {
    switch (type) {
      case FeedContentType.video: return FontAwesomeIcons.youtube;
      case FeedContentType.socialPost: return FontAwesomeIcons.facebook;
      case FeedContentType.advertisement: return Icons.local_offer;
      case FeedContentType.recipe: return Icons.restaurant_menu;
      default: return Icons.article;
    }
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

// 🎯 4. FIXED YOUTUBE CARD WITH SHARE
class _YoutubeFeedCard extends StatefulWidget {
  final FeedItemModel item;
  final String videoId;
  final String videoUrl; // 🎯 Add this

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

  // 🎯 Share Function
  void _shareVideo() {
    Share.share('Check out this video on NutriCare: ${widget.videoUrl}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))]),
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
              // 🎯 SHARE BUTTON ADDED HERE
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                onPressed: _shareVideo,
                tooltip: "Share Video",
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.white, size: 20),
                onPressed: _openInApp,
                tooltip: "Open in YouTube App",
              ),
            ],
            bottomActions: [
              CurrentPosition(),
              ProgressBar(isExpanded: true),
              RemainingDuration(),
              const FullScreenButton(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142), height: 1.2)),
                const SizedBox(height: 8),
                Text(widget.item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}