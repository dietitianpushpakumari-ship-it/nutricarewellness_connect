import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_shift/core/utils/feed_item_model.dart';
import 'package:pure_shift/elite_nudge_hub.dart';
import 'package:pure_shift/features/content/feed_provider.dart';
import 'package:pure_shift/new/feed/feed_tab.dart';
import 'package:url_launcher/url_launcher.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class DashboardFeedPreview extends ConsumerWidget {
  const DashboardFeedPreview({super.key});

  String _parseTitle(dynamic title, String lang) {
    if (title is Map) {
      return title[lang] ?? title['en'] ?? "";
    }
    return title?.toString() ?? "";
  }

  String? _getYouTubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final RegExp regExp = RegExp(
        r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|shorts\/|watch\?v=|\&v=)([^#\&\?]*).*',
        caseSensitive: false,
        multiLine: false);
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 2 && match.group(2)?.length == 11) {
      return match.group(2);
    }
    return null;
  }

  // --- ROUTING HANDLERS ---
  void _openInsightDeck(BuildContext context) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InsightCarouselDeck(),
    );
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

  void _openFullScreenImage(BuildContext context, String imageUrl) {
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

  void _handleItemTap(BuildContext context, FeedItemModel item) {
    HapticFeedback.lightImpact();

    if (item.type == FeedContentType.socialPost) {
      _openInsightDeck(context);
      return;
    }

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
      _openFullScreenImage(context, item.mediaUrl!);
      return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final feedState = ref.watch(feedProvider);
    final String currentLang = 'en';

    if (feedState.items.isEmpty) return const SizedBox.shrink();

    final recentItems = feedState.items.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚀 1. LUXURY SECTION HEADER
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedTab()));
              },
              child: Container(
                color: Colors.transparent,
                child: Row(
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
                    Row(
                      children: [
                        Text(
                          "View All",
                          style: TextStyle(
                            fontFamily: kDisplayFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: colorScheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🚀 2. BENTO-STYLE FEED CARDS (Replacing the flat list)
          Column(
            children: recentItems.map((item) {
              final bool isInsight = item.type == FeedContentType.socialPost;
              final Color neonGreen = const Color(0xFF00E676);
              final String displayTitle = _parseTitle(item.title, currentLang);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _handleItemTap(context, item),
                  child: Container(
                    decoration: BoxDecoration(
                      // 🚀 LUXURY MOVE: Subtle gradient matching dashboard
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [colorScheme.surface, colorScheme.surface.withOpacity(0.8)]
                            : [Colors.white, const Color(0xFFF8FAFC)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      // 🚀 HAIRLINE BORDER: Extremely thin, slightly reflective
                      border: Border.all(
                        color: isInsight
                            ? neonGreen.withOpacity(0.3)
                            : (isDark ? Colors.white.withOpacity(0.08) : colorScheme.primary.withOpacity(0.05)),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.2) : colorScheme.primary.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Optional: Add a subtle glow for Insight cards
                          if (isInsight)
                            Positioned(
                              top: -20,
                              left: -20,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: neonGreen.withOpacity(isDark ? 0.08 : 0.04),
                                ),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                            ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🚀 3. ENHANCED THUMBNAIL
                                _buildPremiumThumbnail(item, isInsight, neonGreen, theme),
                                const SizedBox(width: 16),

                                // 📝 TEXT CONTENT
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildPremiumBadge(item.type, theme),
                                      const SizedBox(height: 8),
                                      Text(
                                        displayTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: kDisplayFont, // Use Space Grotesk for titles
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3,
                                          color: theme.colorScheme.onSurface,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
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
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- PREMIUM UI COMPONENTS ---

  Widget _buildPremiumThumbnail(FeedItemModel item, bool isInsight, Color neon, ThemeData theme) {
    String? imgUrl = item.mediaUrl;
    final ytId = _getYouTubeId(item.actionUrl) ?? _getYouTubeId(item.mediaUrl);
    if (ytId != null) imgUrl = 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
    final bool hasImage = imgUrl != null && imgUrl.isNotEmpty;

    return Container(
      width: 64, // Larger, more luxurious thumbnail
      height: 64,
      decoration: BoxDecoration(
        color: isInsight ? neon.withOpacity(0.1) : theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16), // Softer corners
        image: (!isInsight && hasImage)
            ? DecorationImage(image: CachedNetworkImageProvider(imgUrl), fit: BoxFit.cover)
            : null,
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: isInsight
          ? Icon(Icons.memory_rounded, color: neon, size: 24)
          : (!hasImage
          ? Icon(_getFallbackIcon(item.type), color: theme.colorScheme.primary.withOpacity(0.5), size: 24)
          : (ytId != null
          ? Center(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5)
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
        ),
      )
          : null)
      ),
    );
  }

  IconData _getFallbackIcon(FeedContentType type) {
    switch (type) {
      case FeedContentType.video: return Icons.play_circle_outline;
      case FeedContentType.recipe: return Icons.restaurant_menu_rounded;
      case FeedContentType.article:
      case FeedContentType.articleLink: return Icons.menu_book_rounded;
      case FeedContentType.advertisement: return Icons.star_outline_rounded;
      default: return Icons.article_outlined;
    }
  }

  Widget _buildPremiumBadge(FeedContentType type, ThemeData theme) {
    String label;
    Color color;

    switch (type) {
      case FeedContentType.socialPost:
        label = "CLINICAL PEARL"; color = const Color(0xFF00E676); break;
      case FeedContentType.video:
        label = "VIDEO SESSION"; color = Colors.redAccent; break;
      case FeedContentType.article:
      case FeedContentType.articleLink:
        label = "RESEARCH SUMMARY"; color = Colors.blueAccent; break;
      case FeedContentType.recipe:
        label = "DIETETIC RECIPE"; color = Colors.orangeAccent; break;
      case FeedContentType.advertisement:
        label = "RECOMMENDED"; color = theme.colorScheme.primary; break;
      case FeedContentType.imagePost:
        label = "VISUAL GUIDE"; color = Colors.teal; break;
      default:
        label = "CLINICAL PROTOCOL"; color = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6)
      ),
      child: Text(
        label,
        style: TextStyle(
            fontFamily: kDisplayFont,
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0
        ),
      ),
    );
  }
}