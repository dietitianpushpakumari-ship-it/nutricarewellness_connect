import 'package:cloud_firestore/cloud_firestore.dart';

enum FeedContentType {
  video,
  imagePost,
  articleLink,
  recipe,
  advertisement,
  socialPost,
}

class FeedItemModel {
  final String id;
  final String title;
  final String description;
  final FeedContentType type;

  final String? mediaUrl;      // Video Link or Image URL
  final String? actionUrl;     // External Link
  final String? callToAction;

  final Map<String, dynamic>? recipeData;
  final List<String> targetTags;

  final DateTime postedAt;
  final int views;
  final int shares;

  FeedItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.mediaUrl,
    this.actionUrl,
    this.callToAction,
    this.recipeData,
    this.targetTags = const [],
    required this.postedAt,
    this.views = 0,
    this.shares = 0,
  });

  factory FeedItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 🎯 FIX: Handle Legacy "youtubeVideo" string
    String typeStr = data['type'] ?? 'imagePost';
    FeedContentType parsedType;

    if (typeStr == 'youtubeVideo') {
      parsedType = FeedContentType.video;
    } else {
      parsedType = FeedContentType.values.firstWhere(
              (e) => e.name == typeStr,
          orElse: () => FeedContentType.imagePost
      );
    }

    return FeedItemModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: parsedType, // Uses the corrected type
      mediaUrl: data['mediaUrl'],
      actionUrl: data['actionUrl'],
      callToAction: data['callToAction'],
      recipeData: data['recipeData'],
      targetTags: List<String>.from(data['targetTags'] ?? []),
      postedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      views: data['views'] ?? 0,
      shares: data['shares'] ?? 0,
    );
  }
}