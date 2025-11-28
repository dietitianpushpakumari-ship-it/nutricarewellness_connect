import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';
import 'package:nutricare_connect/core/utils/feed_provider.dart';
import 'package:nutricare_connect/core/utils/fullscreen_image_viewer.dart';
import 'package:nutricare_connect/core/utils/youtube_thumnail_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  // Helper: Extract Video ID
  String? _getYouTubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      return YoutubePlayer.convertUrlToId(url);
    } catch (e) {
      return null;
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 80, spreadRadius: 30)]))),

          Column(
            children: [
              // 2. Glass Header
              _buildHeader(),

              // 3. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTextField(_searchController, "Search posts...", Icons.search, onChanged: (val) {
                  // Add search logic here
                }),
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
                        return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                      }

                      final item = feedState.items[index];

                      // Check for Video
                      if (item.type == FeedContentType.video) {
                        final link = (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) ? item.mediaUrl : item.actionUrl;
                        final videoId = _getYouTubeId(link);

                        if (videoId != null) {
                          // Use Thumbnail Card for better performance
                          return YouTubeThumbnailCard(item: item, videoId: videoId);
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
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1)))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Community Feed", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Icon(Icons.rss_feed, color: Colors.orange.shade800, size: 20)),
          ]),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false, ValueChanged<String>? onChanged}) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: onChanged,
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400), prefixIcon: Icon(icon, color: Colors.indigo.withOpacity(0.6), size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      ),
    );
  }

  Widget _buildFilterBar(FeedNotifier notifier) {
    return Container(
      height: 50, margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: _filters.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () { setState(() => _selectedFilter = filter); notifier.setFilter(filter); },
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? Colors.black87 : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Center(child: Text(filter, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)))),
          );
        },
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, FeedItemModel item) {
    final isRecipe = item.type == FeedContentType.recipe;
    String? displayImageUrl = item.mediaUrl;
    String? clickUrl = item.actionUrl ?? item.mediaUrl;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))]),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayImageUrl != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: displayImageUrl!))),
              child: Stack(
                children: [
                  SizedBox(
                    height: 200, width: double.infinity,
                    child: CachedNetworkImage(imageUrl: displayImageUrl, fit: BoxFit.cover, placeholder: (_, __) => Container(color: Colors.grey.shade100), errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300)),
                  ),
                  if (isRecipe) Positioned(top: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.restaurant_menu, size: 14, color: Colors.orange), SizedBox(width: 4), Text("RECIPE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]))),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142), height: 1.2)),
              const SizedBox(height: 8),
              Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),

              if (item.actionUrl != null) ...[
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _launchUrl(item.actionUrl!), icon: const Icon(Icons.open_in_new, size: 18), label: Text(item.callToAction ?? "Read More"), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0)))
              ]
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => const Center(child: Text("No posts found."));
}

// 🎯 4. FIXED YOUTUBE CARD (REMOVED SPEED BUTTON)
class _YoutubeFeedCard extends StatefulWidget {
  final FeedItemModel item;
  final String videoId;

  const _YoutubeFeedCard({super.key, required this.item, required this.videoId});

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
              // const PlaybackSpeedButton(), // ❌ REMOVED TO FIX ERROR
              FullScreenButton(),
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