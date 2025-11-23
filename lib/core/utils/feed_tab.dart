import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';
import 'package:nutricare_connect/core/utils/feed_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final ScrollController _scrollController = ScrollController();
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
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Trigger load more when near bottom
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final feedNotifier = ref.read(feedProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Daily Feed", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 1. Category Filter
          Container(
            height: 60,
            color: Colors.white,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() => _selectedFilter = filter);
                    feedNotifier.setFilter(filter);
                  },
                  selectedColor: Colors.teal.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.teal.shade900 : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.transparent)),
                );
              },
            ),
          ),

          // 2. Feed List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => await feedNotifier.refresh(),
              child: feedState.isLoading && feedState.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : feedState.items.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: feedState.items.length + (feedNotifier.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  // Show Loading Indicator at bottom
                  if (index == feedState.items.length) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  return _buildSmartFeedCard(context, feedState.items[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Copy _buildSmartFeedCard, _buildEmptyState, and helpers from previous FeedTab code) ...
  // ... (They are purely UI and don't change logic) ...

  Widget _buildSmartFeedCard(BuildContext context, FeedItemModel item) {
    // 🎯 Reuse your existing card widget logic here
    // It is identical to the one I provided in the previous response.
    // Let me know if you need me to paste it again.
    final bool isFeatured = item.isPinned;

    return Container(
      decoration: BoxDecoration(
        color: isFeatured ? const Color(0xFFFFF8E1) : Colors.white, // Gold tint if featured
        borderRadius: BorderRadius.circular(16),
        border: isFeatured ? Border.all(color: Colors.amber.shade300, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null)
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey.shade200),
                  ),
                ),
                if (item.type == FeedType.youtube)
                  const Positioned.fill(child: Center(child: Icon(Icons.play_circle_fill, color: Colors.red, size: 50))),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                        child: const Text("FEATURED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                    Icon(_getIconForType(item.type), size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat.yMMMd().format(item.postedAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                const SizedBox(height: 6),
                Text(item.subtitle, style: TextStyle(color: Colors.grey.shade700, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),

                const SizedBox(height: 16),

                if (item.actionUrl != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchSmartUrl(item.actionUrl!),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(_getActionLabel(item.type)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFeatured ? Colors.amber.shade700 : Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("No posts found."));
  }

  Future<void> _launchSmartUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url");
    }
  }

  IconData _getIconForType(FeedType type) {
    switch (type) {
      case FeedType.youtube: return FontAwesomeIcons.youtube;
      case FeedType.facebookPost: return FontAwesomeIcons.facebook;
      case FeedType.promotion: return Icons.local_offer;
      default: return Icons.article;
    }
  }

  String _getActionLabel(FeedType type) {
    switch (type) {
      case FeedType.youtube: return "Watch Video";
      case FeedType.promotion: return "Claim Offer";
      default: return "Read More";
    }
  }
}